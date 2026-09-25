# Go idiomático

> **Leitura obrigatória.** O "jeito Go" ao transformar o plan em código. O `architecture-<projeto>.md` prevalece onde for mais específico, e divergências vão para o `build-logs.md`.

## 1. Princípios

Simples e explícito vence esperto. Stdlib primeiro. Pacotes pequenos por domínio, sem camadas que só repassam chamadas. `gofmt`, `go vet`, linter e race detector fazem parte do trabalho.

## 2. Versão e toolchain

- Mínimo recomendado: **Go 1.25**. A versão real está no `architecture.md`. Não use recurso mais novo que a diretiva `go` do `go.mod`.

| Versão | Recursos usados pelo framework |
|---|---|
| 1.21 | `log/slog`, `slices`, `maps`, `min`/`max`/`clear`, PGO, `context.WithoutCancel`, `sync.OnceValue` |
| 1.22 | Variável de `for` por iteração, `for range n`, `ServeMux` com método e wildcard, `math/rand/v2` |
| 1.23 | Iteradores (`range` sobre função, `iter`) |
| 1.24 | `testing.B.Loop`, `T.Context()`, diretiva `tool` no `go.mod`, tag JSON `omitzero`, `os.Root` |
| 1.25 | `GOMAXPROCS` pelo cgroup, `sync.WaitGroup.Go`, `testing/synctest`, `trace.FlightRecorder` |

- Rode as ferramentas com **`GOTOOLCHAIN=local`**. `go get` sem versão pode puxar dependência que exige Go mais novo e reescrever `go`/`toolchain` no `go.mod`. Confira o diff do `go.mod` após todo `go get`. Mudar essas diretivas é decisão registrada, nunca efeito colateral.

## 3. Layout

```txt
cmd/<binario>/main.go        # só wiring; em Lambda, um por função
internal/<dominio>/          # model.go, service.go, repository.go, handler.go, parse.go + *_test.go
internal/platform/           # config, database, httpx, awsx, observability
testdata/                    # fixtures (eventos, JSON)
```

- `internal/` por padrão. Sem `pkg/` (salvo biblioteca) e sem `utils/`, `common/`, `helpers/`.
- A borda (HTTP/Lambda) é fina; **a mesma camada `service` atende API e Lambda.**

## 4. Nomes

Pacote curto, minúsculo, singular (`pedido.Service`, não `pedido.PedidoService`). Arquivos `snake_case.go`. Acrônimos uniformes (`userID`, `ParseURL`). Exporte só o que outro pacote usa.

## 5. Erros

- Sempre tratados. `_ = f()` só com comentário do motivo.
- Contexto ao propagar: `fmt.Errorf("buscar conta %d: %w", id, err)`, em minúsculas e sem ponto final.
- Erro de domínio: sentinela (`var ErrSaldoInsuficiente = errors.New(...)`) ou tipo, verificado com `errors.Is`/`errors.As`; `errors.Join` para vários.
- **O service devolve erro de domínio e a borda o traduz** para status HTTP ou falha da Lambda. O service não conhece HTTP.
- Não logue e retorne o mesmo erro. `panic` só na inicialização, para erro de programação.
- Mensagens para o cliente vêm da spec e ficam em constantes.

## 6. `context`

Primeiro parâmetro (`ctx`) de toda função com I/O ou que bloqueia. Nunca em struct, nunca `nil`, nunca `context.Background()` no caminho da requisição (só em `main`, testes e shutdown). Prazo por etapa com `context.WithTimeout` + `defer cancel()`. Valores no contexto só para dados transversais (request ID, trace).

## 7. Interfaces e dependências internas

- Interfaces pequenas, no pacote que consome. "Aceite interfaces, retorne structs." Não crie interface para um único tipo sem necessidade de teste.
- Injeção por construtor, montagem no `main`, sem estado global mutável e sem `init()` com efeito colateral. Clientes e pools criados no `main` da Lambda são wiring, não estado global.
- Fakes à mão nos testes; framework de mock só com decisão registrada.

## 8. Tipos e dados

- Contratos como structs tipadas com tags JSON. `map[string]any` só com motivo registrado.
- Dinheiro em centavos `int64`. Tempo em `time.Time` UTC, com formato de fio do contrato (RFC 3339).
- Pré-aloque (`make([]T, 0, n)`). Generics só para eliminar duplicação real.

## 9. Logs

`log/slog` JSON para stdout, chaves estáveis em `snake_case` (`request_id`, `duration_ms`). Nunca segredos, tokens ou dados pessoais. Nível por env var.

## 10. Comentários

| Tipo | Regra |
|---|---|
| Doc comment de identificador exportado | Descreve tecnicamente o que o código faz, começando pelo nome. Não cita spec nem IDs. |
| Rastreabilidade | Só o ID, no ponto de aplicação: `// 007-RN03`, `// 007-CC01`, `// 007-RN03, 007-CA02`. |

## 11. Dependências externas

Ordem de preferência: stdlib → `golang.org/x/...` → bibliotecas consolidadas.

**Pré-aprovadas:**
- `golang.org/x/sync`
- `golang.org/x/time/rate`
- `aws-sdk-go-v2`
- `aws-lambda-go`
- `pgx/v5`
- `google/uuid`
- `go.uber.org/goleak` (só em testes)

Qualquer outra entra no `build-logs.md` com:
- motivo e alternativa na stdlib descartada;
- confirmação de Go puro (sem CGO) e build `linux/arm64`;
- `govulncheck` limpo;
- impacto no tamanho do binário, se for Lambda.

Framework web não é padrão.

## 12. Formatação e lint

`gofmt -l .` vazio, `go vet ./...` limpo e lint conforme o `ai-instructions.md` (padrão: golangci-lint v2 com `default: standard` + `bodyclose`, `errorlint`, `gosec`, `noctx`; mínimo aceitável: `staticcheck`).
