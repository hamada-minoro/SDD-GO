# Testes e portões de qualidade em Go

> **Leitura obrigatória.** Esta é a **fonte única** dos portões de qualidade: os outros arquivos apontam para cá. Nenhuma entrega é "Aprovada" com portão falhando.

## 1. Portões

Rodados em cada módulo Go tocado, com `GOTOOLCHAIN=local`. Se o projeto usar comandos diferentes, eles estão no `ai-instructions.md`, seção "Informações específicas do projeto".

| # | Portão | Comando padrão | Reprova quando |
|---|---|---|---|
| 1 | Formatação | `test -z "$(gofmt -l .)"` | algum arquivo listado |
| 2 | Vet | `go vet ./...` | qualquer aviso |
| 3 | Lint | `golangci-lint run` (ou `staticcheck ./...`) | achado sem justificativa |
| 4 | Testes + race | `go test -race -count=1 ./...` | falha ou race |
| 5 | Integração | `go test -race -count=1 -tags integration ./...` | falha (ou pendência justificada pelo `infraestrutura-testes.md`) |
| 6 | Vulnerabilidades | `govulncheck ./...` | vulnerabilidade alcançável sem justificativa |
| 7 | Build ARM64 | `CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags="-s -w" ./...` | não compila |
| 8 | Módulo limpo | `go mod tidy && git diff --exit-code go.mod go.sum` | diff |

Condicionais:

| Quando | Comando |
|---|---|
| Spec com `CCxx` | `go test -race -count=50 -cpu=1,2,4 -run '<testes de concorrência>' ./internal/<pkg>/...` |
| Pacote com goroutines novas | `goleak.VerifyTestMain(m)` no `TestMain` |
| `DPxx` ou otimização | `go test -run '^$' -bench . -benchmem -count=10` + `benchstat antes.txt depois.txt` |
| Parser de entrada externa | `go test -run '^$' -fuzz FuzzX -fuzztime 30s ./internal/<pkg>` |

`-race` pode exigir `CGO_ENABLED=1` e compilador C **só no teste**. Registre no `infraestrutura-testes.md` como ele roda no ambiente. O binário de produção continua sem CGO.

## 2. O que testar em cada nível

| Nível | Como | Tag |
|---|---|---|
| Parse, validação, cálculo | Funções puras, table-driven | — |
| Service | Fakes à mão das interfaces | — |
| Borda HTTP | `httptest` sobre o `http.Handler` real | — |
| Borda Lambda | Handler chamado com eventos de `testdata/` | — |
| Banco, transação, lock, idempotência, invariante | Serviços reais do `infraestrutura-testes.md` | `integration` |
| `DPxx` de sistema | Carga (`performance-e-custo.md`) | fora do `go test` |

Extraia parse e validação para funções puras. O teste de integração fica para o que só o banco prova.

## 3. Convenções

```go
// 007-RN02
func TestParseAmount(t *testing.T) {
	tests := []struct {
		name    string
		in      string
		want    int64
		wantErr error
	}{
		{name: "centavos válidos", in: "1050", want: 1050},
		{name: "zero", in: "0", wantErr: ErrInvalidAmount},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got, err := ParseAmount(tt.in)
			if !errors.Is(err, tt.wantErr) || got != tt.want {
				t.Fatalf("ParseAmount(%q) = %d, %v; want %d, %v", tt.in, got, err, tt.want, tt.wantErr)
			}
		})
	}
}
```

- Nome no formato `Test<Unidade>_<Cenário>`. O ID coberto vai no comentário e na tabela do `tests.md`.
- `t.Parallel()` em testes independentes; `t.Context()` em vez de `context.Background()`; `t.Helper()` e `t.Cleanup()`.
- Fixtures em `testdata/`. Integração com `//go:build integration` na primeira linha.
- Sem biblioteca de asserção por padrão.

## 4. Testes de concorrência

```go
func TestMain(m *testing.M) { goleak.VerifyTestMain(m) } // vazamento de goroutines

// 007-CC02: fake que mede a concorrência máxima
type countingClient struct{ current, max atomic.Int64 }

func (c *countingClient) Call(ctx context.Context, id string) error {
	n := c.current.Add(1)
	defer c.current.Add(-1)
	for {
		old := c.max.Load()
		if n <= old || c.max.CompareAndSwap(old, n) {
			break
		}
	}
	time.Sleep(time.Millisecond) // simula latência, não sincroniza
	return nil
}

// 007-CC01: prazo com relógio virtual (Go ≥ 1.25), roda em microssegundos
func TestEnrich_EstouroDePrazo(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		svc := NewService(slowCustomers{delay: 2 * time.Second}, fastInventory{}, fastPricing{})
		ctx, cancel := context.WithTimeout(t.Context(), 800*time.Millisecond)
		defer cancel()
		if _, err := svc.Enrich(ctx, Order{ID: "p1"}); !errors.Is(err, context.DeadlineExceeded) {
			t.Fatalf("erro = %v, want DeadlineExceeded", err)
		}
	})
}
```

Também prove, quando a spec pedir:
- **falha parcial:** fake que falha em itens específicos, com asserção por item;
- **ordem por chave:** fake que registra a sequência de cada chave;
- **invariante sob concorrência real:** integração com N operações simultâneas e a conferência do invariante no fim.

## 5. Benchmarks e fuzz

```go
func BenchmarkParseTransaction(b *testing.B) {
	body := loadFixture(b, "testdata/transaction.json")
	b.ReportAllocs()
	for b.Loop() { // Go ≥ 1.24
		if _, err := ParseTransaction(body); err != nil {
			b.Fatal(err)
		}
	}
}

func FuzzParseTransaction(f *testing.F) {
	f.Add([]byte(`{"type":"deposit","amount":100}`))
	f.Fuzz(func(t *testing.T, data []byte) {
		_, _ = ParseTransaction(data) // não pode panicar
	})
}
```

- Benchmark sempre comparado com `benchstat` (`-count=10`). O resultado vai para o `tests.md` e a decisão para o `build-logs.md`.
- O corpus do fuzz que achar falha fica em `testdata/fuzz/`.

## 6. Lambda

Teste obrigatoriamente, chamando o handler com eventos de `testdata/`:
- falha parcial (`BatchItemFailures`);
- evento malformado;
- prazo curto (via synctest);
- mesma mensagem duas vezes (idempotência).

Executar o runtime local (SAM, LocalStack) é opcional e fica descrito no `infraestrutura-testes.md`.

## 7. Cobertura

A meta não é percentual. É **todo `RN`, `CA` e `CC` da spec com teste** na tabela do `tests.md`; o que faltar vira pendência no `review.md`.
