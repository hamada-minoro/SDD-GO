# Estudo de origem: Node.js vs Go e a pesquisa Go + ARM + AWS

> **Leitura humana. Nenhum agente é obrigado a ler este arquivo.** Ele guarda a evidência e a pesquisa que deram origem às regras do SDD-GO. As regras em si estão nos guias de `.ai/go/`, já sem os números.

## 1. O benchmark

Duas APIs bancárias idênticas com o mesmo contrato, o mesmo Postgres e o mesmo algoritmo (lock pessimista em ordem de id + idempotência com `ON CONFLICT`):

- **Node.js 24 + Express 5**, com `node:cluster` (4 workers, 4 pools de 10 conexões);
- **Go 1.22 + `net/http` + `pgx`**, com 1 processo e 1 pool de 40 conexões.

Cada API rodou com **4 CPUs e 1 GiB**, medida com Locust. Foram 4 cenários fixos (misto, escrita, contenção, leitura) com 1.000 usuários por 5 minutos, mais uma rampa até 5.000 usuários. Somando tudo, ~23,4 milhões de requisições, **0 falhas** e consistência financeira perfeita nas duas.

| Métrica | Go | Node.js | Resultado |
|---|---:|---:|---|
| Vazão (misto) | 9.302,7 req/s | 5.679,4 req/s | Go 1,64x (1,57x–1,64x nos 4 cenários) |
| p50 (misto) | 110 ms | 180 ms | Go −39% (−37% a −40%) |
| CPU por requisição (misto) | 0,417 ms | 0,726 ms | Go 1,74x menos (as duas com CPU saturada) |
| Memória média (misto) | 75,1 MiB | 355,8 MiB | Go 4,7x menos (4,7x–5,4x) |
| Usuários com p99 ≤ 500 ms (rampa) | 2.250 | 1.750 | Go +29% |
| CPU do Postgres (escrita) | 758% de 800% | 542% de 800% | O banco virou gargalo com Go |

Ressalvas: uma execução por combinação, numa única máquina, com Go 1.22. O Node foi à frente só em pontos isolados da cauda extrema (p99.9 e máximo) nos cenários de escrita, porque o banco estava saturado pela vazão maior do Go.

Relatório completo no projeto de origem: `relatorio/` e `reports/` do repositório *Estudo-Go*.

## 2. Lições que viraram regra

| Lição do estudo | Regra no framework | Onde |
|---|---|---|
| Com Go, o gargalo desceu para o banco | Todo limite de concorrência nasce da capacidade downstream | `concorrencia.md` §6 |
| Um pool compartilhado por goroutines rendeu mais que 4 pools fatiados | Um pool por processo/ambiente | `dados-postgres.md` §1 |
| Go 1.22 não lia o limite de CPU do container | `GOMAXPROCS` alinhado (automático no Go ≥ 1.25), `GOMEMLIMIT` ~90% | `api-http.md` §3 |
| Timeout de aquisição aplicado à transação gerou 503 falsos | Timeout de aquisição separado do tempo da operação | `dados-postgres.md` §1 |
| `ServeMux.Handler` não preenchia `PathValue` e quebrou as rotas com `{id}` | Atender sempre com `mux.ServeHTTP` + teste de wildcard | `api-http.md` §5 |
| `go get` trouxe um `pgx` que exigia Go mais novo | `GOTOOLCHAIN=local` + diff do `go.mod` | `idiomatico.md` §2 |
| `pgx.Batch` ficou de fora por falta de medição | Otimização só com `DPxx` e medição antes/depois | `performance-e-custo.md` §5 |
| Velocidade conferida junto com consistência | Critério de aceite de invariante sob concorrência | template `spec.md` |
| Paridade exigia comportamento real, não a tabela da spec | Em migração, o comportamento observável é o contrato | `api-http.md` §5 |
| Funções puras de parse permitiram centenas de testes sem banco | Parse/validação como funções puras | `testes.md` §2 |

## 3. Pesquisa: Go, ARM e AWS

Resumo da pesquisa `benefícios-go/go-aws-arm-cloud-backend.md` (repositório *Estudo-Go*):

- **Por que Go cresce em backend:** combina linguagem simples, compilação nativa, binário único, baixo overhead, concorrência barata, stdlib forte, cross-compilation trivial, tooling oficial e suporte de primeira classe a ARM64. Não é "a mais rápida", e sim o equilíbrio entre desempenho, simplicidade, manutenção e operação em cloud.
- **ARM na AWS (Graviton):** o argumento principal é **preço/desempenho**, não velocidade bruta. A AWS reportou até ~34% de melhor preço/desempenho em Lambda com Graviton2, dependendo do workload, e ganhos de até 20% em workloads Go com Go 1.18 em Graviton.
- **Go + Lambda + arm64:** `GOOS=linux GOARCH=arm64 go build -o bootstrap` em qualquer máquina. Binário nativo sem VM favorece cold start e memória.
- **Cuidado principal na migração para ARM:** dependências nativas (CGO, bibliotecas C, Layers, Extensions, binários externos, imagens).
- **Go e Node não competem em tudo:** Node é excelente em I/O, CRUD, BFF e ecossistema web. Go se destaca quando se somam I/O, CPU, concorrência, múltiplos cores e volume.
- **Recomendação da AWS:** testar o workload real em arm64 e x86 (duração, p95/p99, cold start, memória, custo) antes de decidir.

Fontes:
- [Lambda com Go](https://docs.aws.amazon.com/lambda/latest/dg/lambda-golang.html)
- [Arquiteturas do Lambda](https://docs.aws.amazon.com/lambda/latest/dg/foundation-arch.html)
- [Go 1.18 e Graviton](https://aws.amazon.com/blogs/compute/making-your-go-workloads-up-to-20-faster-with-go-1-18-and-aws-graviton/)
- [Migração de Lambda para Graviton2](https://aws.amazon.com/blogs/compute/migrating-aws-lambda-functions-to-arm-based-aws-graviton2-processors/)
- [Serverless Lens: custo e desempenho](https://docs.aws.amazon.com/wellarchitected/latest/serverless-applications-lens/cost-and-performance-optimization.html)
- [Go Developer Survey 2025](https://go.dev/blog/survey2025)
- [Stack Overflow Developer Survey 2025](https://survey.stackoverflow.co/2025/)
