# AWS Lambda em Go (ARM64)

> **Leitura condicional:** quando a spec toca uma Lambda ou gatilho AWS (SQS, SNS, EventBridge, Kinesis, DynamoDB Streams, S3, API Gateway). Banco de dados fica em `dados-postgres.md` / `dados-dynamodb.md`.

## 1. Runtime e build

- Runtime `provided.al2023`, `Architectures: [arm64]`, binário **`bootstrap`**, `aws-lambda-go` + `aws-sdk-go-v2`. O runtime `go1.x` foi descontinuado.
- x86_64 só com motivo registrado (dependência nativa, Layer/Extension sem arm64).

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
  go build -tags lambda.norpc -trimpath -ldflags="-s -w" \
  -o build/processar-pedidos/bootstrap ./cmd/processar-pedidos
```

- `-tags lambda.norpc` remove o modo RPC legado e deixa o binário menor.
- A ferramenta de IaC está no `architecture.md`.

## 2. Uma função = um binário

- Um `cmd/<funcao>/main.go` por função, com uma role IAM de privilégio mínimo para cada uma.
- Handler é borda fina: decodifica o evento, chama o service (o mesmo da API) e monta a resposta.

## 3. Ciclo de vida

- **INIT** (código do `main` antes de `lambda.Start`): roda uma vez por ambiente. É onde se criam config, clientes do SDK e pools.
- **INVOKE:** uma invocação por vez no ambiente. Depois do `return`, o ambiente é **congelado**.
- **Reuso:** a próxima invocação encontra clientes e pools prontos.

```go
func main() {
	ctx := context.Background()
	appCfg, err := config.Load()
	if err != nil {
		slog.Error("configuração inválida", "err", err)
		os.Exit(1)
	}
	awsCfg, err := awsconfig.LoadDefaultConfig(ctx)
	if err != nil {
		slog.Error("configuração AWS", "err", err)
		os.Exit(1)
	}
	h := &Handler{
		svc:            pedido.NewService(pedido.NewRepository(dynamodb.NewFromConfig(awsCfg), appCfg.TableName)),
		maxConcurrency: appCfg.MaxConcurrency,
		safetyMargin:   appCfg.SafetyMargin,
	}
	lambda.Start(h.Handle)
}
```

- Clientes e pools no INIT, nunca por invocação. Cliente pouco usado: `sync.OnceValue`.
- **Nenhuma goroutine após o `return`** (CONC-07). Logs e métricas saem antes do retorno.
- Estado em memória entre invocações é só cache oportunista.

## 4. CPU e memória

- A CPU é proporcional à memória: 1.769 MB equivalem a 1 vCPU, e o máximo é 6 vCPUs com 10.240 MB.
- **I/O em paralelo vale com qualquer memória. CPU em paralelo só com ≥ 2 vCPUs e medição.**
- `runtime.NumCPU()`/`GOMAXPROCS` podem reportar mais CPU do que a fatia real: decida por medição (`performance-e-custo.md`).
- A memória é definida pelo `DPxx`, não por palpite.

## 5. Prazo

```go
func withSafetyMargin(ctx context.Context, margin time.Duration) (context.Context, context.CancelFunc) {
	deadline, ok := ctx.Deadline()
	if !ok {
		return context.WithCancel(ctx)
	}
	return context.WithDeadline(ctx, deadline.Add(-margin))
}
```

Itens não iniciados quando o prazo acaba voltam como falha (reprocessados), nunca perdidos. O timeout da função vem da spec.

## 6. SQS: falha parcial obrigatória

Habilite `ReportBatchItemFailures` e devolva só o que falhou. Retornar `error` reprocessa o lote inteiro.

```go
func (h *Handler) Handle(ctx context.Context, evt events.SQSEvent) (events.SQSEventResponse, error) {
	ctx, cancel := withSafetyMargin(ctx, h.safetyMargin)
	defer cancel()

	failed := make([]bool, len(evt.Records))

	// 014-CC01
	var g errgroup.Group
	g.SetLimit(h.maxConcurrency)
	for i, msg := range evt.Records {
		g.Go(func() error {
			if err := h.process(ctx, msg); err != nil {
				slog.ErrorContext(ctx, "falha ao processar mensagem", "message_id", msg.MessageId, "err", err)
				failed[i] = true
			}
			return nil
		})
	}
	_ = g.Wait()

	var resp events.SQSEventResponse
	for i, msg := range evt.Records {
		if failed[i] {
			resp.BatchItemFailures = append(resp.BatchItemFailures,
				events.SQSBatchItemFailure{ItemIdentifier: msg.MessageId})
		}
	}
	return resp, nil
}
```

- Entrega *at-least-once*: todo processamento é idempotente, com a chave definida pela spec.
- Visibility timeout da fila ≥ 6× o timeout da função. DLQ (redrive com `maxReceiveCount`) sempre configurada.
- `BatchSize` e `MaximumBatchingWindowInSeconds` são decisões de `DPxx`. `ScalingConfig.MaximumConcurrency` protege o downstream.
- **FIFO:** a doc da AWS recomenda parar no primeiro erro e devolver o que falhou e tudo o que não foi processado. Processar grupos em paralelo (`P5`) é aceitável se, em cada grupo com falha, a mensagem que falhou **e todas as seguintes do grupo** voltarem em `BatchItemFailures`. Essa escolha é registrada no `build-logs.md` e coberta por teste.

## 7. Kinesis e DynamoDB Streams

- A ordem é por shard/partition key: processe em sequência por chave e em paralelo entre chaves (`P5`).
- Falha parcial: `BatchItemFailures` com o **sequence number** do primeiro registro que falhou.
- Configure `BisectBatchOnFunctionError`, `MaximumRetryAttempts` e o destino de falha conforme a spec.

## 8. API Gateway / Function URL

- **Eventos nativos** (`events.APIGatewayV2HTTPRequest`/`Response`, payload 2.0) para poucas rotas.
- **`net/http` + adapter** (Lambda Web Adapter ou `aws-lambda-go-api-proxy`) para muitas rotas, ou quando o serviço também roda em container (ver `api-http.md`).
- A escolha fica no `architecture-<projeto>.md`. Validação, erros e regra de negócio são os mesmos da API.

## 9. Escala × downstream

- Carga no downstream = ambientes simultâneos × concorrência interna. Limite na origem (concorrência reservada, `MaximumConcurrency`) e mantenha o pool por ambiente mínimo.
- Clientes do SDK: um por serviço, criado no INIT e compartilhado pelas goroutines. Com fan-out alto contra o mesmo serviço, ajuste as conexões ociosas por host do transport do SDK e registre a decisão.

## 10. Cold start

- Binário enxuto (`-s -w`, `-trimpath`, `lambda.norpc`, poucas dependências); INIT só com o essencial.
- A fase INIT tem limite de tempo e entra na duração cobrada (confira a página de preços).
- Provisioned concurrency só se um `DPxx` de latência exigir e a medição mostrar necessidade. SnapStart não se aplica a Go.
- Meça pelo `Init Duration` dos logs `REPORT`.

## 11. Observabilidade

- `slog` JSON; formato de log JSON e nível configurados na função.
- Request ID: `lambdacontext.FromContext(ctx)` → `AwsRequestID`.
- Métricas via EMF (linha JSON com a chave `_aws`); tracing com X-Ray ou ADOT.
- Alarmes: `Errors`, `Throttles`, `Duration` p99, idade da mensagem mais antiga e mensagens na DLQ.

## 12. Checklist do plan

- [ ] Gatilho e evento de exemplo em `testdata/`
- [ ] Memória, timeout, `arm64`, concorrência reservada (`DPxx`)
- [ ] Idempotência (chave e mecanismo) e falha parcial com teste
- [ ] Ordem (global, por chave ou nenhuma)
- [ ] Fan-out interno limitado, e o limite justificado
- [ ] Margem de prazo; itens não processados voltam para a fila
- [ ] DLQ e visibility timeout ≥ 6× timeout
- [ ] Clientes no INIT; nenhuma goroutine após o `return`
- [ ] IAM de privilégio mínimo por função
