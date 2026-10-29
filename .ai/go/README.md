# Guias Go do SDD-GO

> **Leitura humana.** Índice dos guias e o motivo de cada diretriz. A IA não precisa ler este arquivo: a ordem de leitura dela está em `.ai/ai-instructions.md`.

## 1. Os guias e quando a IA lê cada um

| Guia | Leitura pela IA | Assunto |
|---|---|---|
| [`idiomatico.md`](idiomatico.md) | Sempre | Versão/toolchain, layout, erros, `context`, interfaces, dependências, lint |
| [`concorrencia.md`](concorrencia.md) | Sempre | Perguntas `CCxx`, decisão, tabela de padrões `P1`–`P10`, regras CONC-01 a CONC-11 |
| [`testes.md`](testes.md) | Sempre | Portões de qualidade (fonte única), race, goleak, synctest, fuzz, benchmark |
| [`concorrencia-padroes.md`](concorrencia-padroes.md) | Na implementação, só as seções dos padrões escolhidos no plan | Código de referência de cada padrão |
| [`api-http.md`](api-http.md) | Se a spec marcar | `net/http`, servidor, runtime no container, container ARM64 |
| [`lambda-aws.md`](lambda-aws.md) | Se a spec marcar | `provided.al2023` arm64, INIT/INVOKE, SQS/Kinesis/API Gateway, cold start |
| [`dados-dynamodb.md`](dados-dynamodb.md) | Se a spec marcar | Modelagem por padrão de acesso, idempotência, batch, capacidade |
| [`dados-postgres.md`](dados-postgres.md) | Se a spec marcar | `pgxpool`, transações, locks, `ON CONFLICT`, RDS Proxy |
| [`performance-e-custo.md`](performance-e-custo.md) | Se a spec tiver `DPxx` | Métricas, metodologia, pprof, PGO, custo ARM vs x86 |
| [`validacao-ambiente.md`](validacao-ambiente.md) | Se a spec marcar | Validação na stack publicada em teste: IAM, evento real, configuração, empacotamento arm64, segurança das escritas, evidências e limpeza |
| [`referencias/estudo-node-vs-go.md`](referencias/estudo-node-vs-go.md) | Nunca (humanos) | Benchmark de origem, lições e pesquisa Go + ARM + AWS |

## 2. Benefício de Go → diretriz do framework

| Benefício | Risco de desperdiçar | Diretriz | Onde |
|---|---|---|---|
| Goroutines baratas | Código sequencial com I/O independente, ou goroutines sem limite | `CCxx` na spec; padrão com limite, dono e cancelamento no plan | `concorrencia.md` |
| `context` nativo | Timeouts soltos, requisição cancelada consumindo banco | Prazo na spec, orçamento por etapa no plan | template `plan.md` |
| Binário nativo estático | Imagens pesadas, cold start alto | `CGO_ENABLED=0`, `bootstrap`, `distroless/static` | `lambda-aws.md`, `api-http.md` |
| Cross-compilation / ARM64 | Rodar em x86 por inércia | `arm64` padrão; build arm64 é portão | `testes.md` |
| Pouca memória | Memória superdimensionada | `DPxx` de memória, `GOMEMLIMIT`, Power Tuning | `performance-e-custo.md` |
| Stdlib forte | Dependências e CVEs desnecessários | Stdlib primeiro, dependência nova registrada | `idiomatico.md` |
| Tipagem e structs | `map[string]any` no caminho quente | Contratos tipados, parse em funções puras | `idiomatico.md` |
| Tooling oficial | Race em produção, otimização sem prova | Portões obrigatórios, `benchstat` | `testes.md` |
| Erros como valores | Erros engolidos | Erro de domínio traduzido na borda | `idiomatico.md` |

A evidência empírica e a pesquisa por trás dessas escolhas estão em [`referencias/estudo-node-vs-go.md`](referencias/estudo-node-vs-go.md).
