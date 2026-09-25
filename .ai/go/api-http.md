# APIs HTTP em Go

> **Leitura condicional:** quando a spec toca uma API HTTP (container ECS/EKS/EC2, ou Lambda via adapter). Banco de dados fica em `dados-postgres.md` / `dados-dynamodb.md`.

## 1. Stack

- **`net/http` + `ServeMux` (Go ≥ 1.22), sem framework web.** `mux.HandleFunc("GET /accounts/{id}", h.get)` e `r.PathValue("id")`. Framework só com benchmark que o justifique, registrado no `build-logs.md`.
- `encoding/json` com structs tipadas; `log/slog` JSON.

## 2. Servidor

```go
func run() error {
	cfg, err := config.Load() // valida tudo na subida
	if err != nil {
		return err
	}
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel})))

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	deps, err := app.NewDeps(ctx, cfg) // pools e clientes: um por processo
	if err != nil {
		return err
	}
	defer deps.Close()

	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           app.NewRouter(deps, cfg),
		ReadHeaderTimeout: 5 * time.Second, // obrigatório
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       65 * time.Second, // > idle timeout do load balancer
	}
	slog.Info("subindo servidor", "port", cfg.Port,
		"gomaxprocs", runtime.GOMAXPROCS(0), "gomemlimit", debug.SetMemoryLimit(-1))

	serverErr := make(chan error, 1)
	go func() { serverErr <- server.ListenAndServe() }()

	select {
	case <-ctx.Done():
	case err := <-serverErr:
		if !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("servidor HTTP: %w", err)
		}
		return nil
	}
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return server.Shutdown(shutdownCtx)
}
```

- `app.NewRouter` separado do `main`, para testar rotas com `httptest`.
- Corpo limitado com `http.MaxBytesReader`. O prazo da requisição vem do `DPxx`, aplicado com `context.WithTimeout` no service ou `http.TimeoutHandler`.

## 3. Runtime no container

- **`GOMAXPROCS`:** automático pelo cgroup no Go ≥ 1.25. No Go ≤ 1.24, defina pela env var igual ao limite de CPU (ou use `automaxprocs`); sem isso, o Go enxerga os cores do host.
- **`GOMEMLIMIT`:** sempre ~90% do limite de memória, para o GC trabalhar dentro do limite em vez de levar OOM.
- **`GOGC`:** padrão; só mude com medição.

## 4. Handlers

```go
type HandlerFunc func(w http.ResponseWriter, r *http.Request) error

func Adapt(h HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if err := h(w, r); err != nil {
			WriteError(w, r, err) // erro de domínio → status/código do contrato; resto → 500 sem vazar detalhe
		}
	}
}
```

- Handler: decodifica, valida o formato, chama o service com `r.Context()` e escreve a resposta. Sem acesso a banco, sem regra de negócio.
- `DisallowUnknownFields` e a semântica de corpo vazio são decisões de contrato da spec.

## 5. Armadilhas conhecidas

- `ServeMux.Handler(r)` **não** preenche `r.PathValue`. Use-o só para decidir 404/405 customizado e atenda sempre com `mux.ServeHTTP(w, r)`. Mantenha um teste de rota com wildcard.
- Em migração de outra stack, o **comportamento observável atual** é o contrato. Divergência com a documentação vira decisão registrada e teste de paridade.

## 6. Middlewares

Ordem, de fora para dentro: recover → request ID → log de acesso → limite de corpo → auth → rota.

- O `recover` do middleware não protege goroutines filhas (CONC-06).
- O request ID vem do header de entrada (`X-Request-Id`/`X-Amzn-Trace-Id`) ou é gerado, e vai para o `ctx` e para todo log.
- Para API chamada por browser com cookie, use `http.CrossOriginProtection` (Go ≥ 1.25) ou a política da spec.

## 7. HTTP de saída

- Um `http.Client` por destino, criado no wiring, com `Timeout`. **Nunca** `http.DefaultClient`.
- `Transport.MaxIdleConnsPerHost` ≥ concorrência máxima contra o host. O padrão é 2 e força reconexões em fan-out.
- `http.NewRequestWithContext` e `defer resp.Body.Close()`.
- Retry só em operação idempotente, com backoff e jitter, dentro do prazo do `ctx`.

## 8. Concorrência na API

- Uma goroutine por requisição já existe. Goroutine no service só para chamadas downstream independentes (`P1`/`P2`), com limite.
- Recurso de capacidade fixa compartilhado entre requisições → `P6`. Quando satura, 503/429 rápido.
- Trabalho que não precisa terminar antes da resposta → publique em fila (SQS/EventBridge), nunca `go func()` solto.

## 9. Container ARM64

```dockerfile
# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.25 AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY cmd ./cmd
COPY internal ./internal
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /app/api
EXPOSE 8080
ENTRYPOINT ["/app/api"]
```

- Build: `docker buildx build --platform linux/arm64 .` (ou `linux/arm64,linux/amd64`). O Go compila de forma cruzada, sem emulação.
- ECS Fargate: `cpuArchitecture: ARM64`. EKS: nós Graviton / `kubernetes.io/arch: arm64`.
- A imagem distroless não tem shell nem `curl`: o health check é feito pelo load balancer em `GET /health`. Separe liveness de readiness se a spec pedir.

## 10. Observabilidade

- Log de acesso: método, **pattern** da rota (não o path com id), status, `duration_ms`, `request_id`.
- `net/http/pprof` só em porta administrativa interna.
- Métricas e traces: OpenTelemetry ou o padrão do `architecture.md`.

## 11. Mesma API em Lambda

O mesmo `http.Handler` roda em Lambda via **AWS Lambda Web Adapter** (extension) ou adapter em código (`aws-lambda-go-api-proxy`). As regras de ciclo de vida estão em `lambda-aws.md`. Registre a escolha no `architecture-<projeto>.md`.
