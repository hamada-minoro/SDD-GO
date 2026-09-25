# Plan: Nome da Feature

## Resumo técnico

Explique como a feature será implementada tecnicamente, em poucos parágrafos.

## Projetos e arquiteturas envolvidos

> Os mesmos da tabela "Projetos e arquiteturas envolvidos" da `spec.md`, nem mais nem menos. Se o plano descobrir que outro projeto precisa mudar, atualize a spec primeiro. Informe a ordem entre os projetos (ex.: a Lambda que publica o evento antes da que consome) e detalhe as seções abaixo por projeto quando mais de um for afetado.

| Ordem | Projeto (pasta) | Tipo de entrega | Arquitetura seguida | Impacto resumido |
|---|---|---|---|---|
| 1 | `pasta-do-projeto/` | | `.ai/architecture-pasta-do-projeto.md` | |

## Guias Go seguidos

Os obrigatórios mais os marcados em "Guias Go aplicáveis" da `spec.md`:

- `.ai/go/<guia condicional>.md`

## Pacotes e arquivos

| Pacote / arquivo | Novo ou alterado | Responsabilidade |
|---|---|---|
| `cmd/<binario>/main.go` | | Wiring |
| `internal/<dominio>/model.go` | | Tipos e erros de domínio |
| `internal/<dominio>/service.go` | | Regra de negócio e orquestração |
| `internal/<dominio>/repository.go` | | Persistência |
| `internal/<dominio>/handler.go` | | Borda HTTP ou Lambda |

## Tipos, interfaces e contratos

- Structs de entrada e saída (com tags JSON):
- Interfaces consumidas pelo service (definidas no pacote consumidor):
- Erros de domínio (sentinelas/tipos) e para onde cada um é mapeado na borda:

| Erro de domínio | HTTP (status / código) ou Lambda (falha parcial, DLQ) | Regra |
|---|---|---|
| `ErrExemplo` | 422 `exemplo` | RN01 |

## Endpoints ou eventos

### `POST /exemplo` (ou: evento `SQS fila-x`)

Descrição:

Request / evento:

```json
{}
```

Response / efeito:

```json
{}
```

## Banco de dados e persistência

- Tabelas/itens novos ou alterados:
- Índices / chaves (partition key, sort key, GSI):
- Migrations:
- Transações, locks e ordem de lock:
- Idempotência (chave e mecanismo: `ON CONFLICT`, `ConditionExpression`):

## Integrações AWS e externas

- Serviços e operações do SDK usados:
- Permissões IAM (privilégio mínimo):
- Clientes criados no wiring (um por serviço, compartilhado):

## Desenho de concorrência

> **Obrigatório.** Cada `CCxx` vira uma linha com um padrão `P1`–`P10` de `.ai/go/concorrencia.md` (seção 4); fora da tabela, justifique e registre no `build-logs.md`. Sem `CCxx`: "Execução sequencial: motivo", dizendo quem garante a concorrência entre requisições (ex.: goroutine por requisição do `net/http` + condição no banco).

| CC | Padrão | Onde (função) | Limite e origem do limite | Dono / como termina | Cancelamento | Erro / falha parcial | Como será provado (teste) |
|---|---|---|---|---|---|---|---|
| CC01 | P1 errgroup.WithContext | `Service.Enrich` | N fixo = 3 | `Service.Enrich` / `g.Wait()` | `ctx` com deadline de 800 ms | 1º erro cancela as irmãs | `TestEnrich_*` com synctest + `-race` |

Diagrama das goroutines (quem cria, por onde os dados passam, quem fecha cada canal):

```txt
Handle(ctx)
 └─ errgroup (limite = MAX_CONCURRENCY)
     ├─ goroutine item 1 ─┐
     ├─ goroutine item 2 ─┼─→ slot failed[i]  (sem compartilhamento)
     └─ goroutine item N ─┘
 └─ g.Wait() → monta BatchItemFailures → return
```

Capacidade downstream considerada (Lei de Little, `.ai/go/concorrencia.md` seção 6):

- Recurso:
- Capacidade:
- Concorrência máxima que esta feature pode gerar (instâncias × limite interno):

## Contexto, prazos e timeouts

| Etapa | Timeout / orçamento de tempo | Origem |
|---|---|---|
| Operação total | | DPxx / timeout da Lambda / SLO |
| Aquisição de conexão | | config |
| Chamada ao serviço X | | |
| Margem de segurança (Lambda) | | |

## Configuração de runtime e deploy

- Variáveis de ambiente novas (nome, padrão, validação):
- `GOMAXPROCS` / `GOMEMLIMIT` (API em container):
- Lambda: memória, timeout, arquitetura `arm64`, concorrência reservada, batch size, `MaximumConcurrency`, DLQ, visibility timeout:
- Tamanho de pool / limites de concorrência (valores e justificativa):
- Artefato: binário, flags de build, arquitetura:

## Observabilidade

- Logs (eventos e chaves):
- Métricas (EMF / OTel):
- Alarmes:

## Testes

> Detalhe conforme `.ai/go/testes.md`. Cada RN, CA e CC tem pelo menos um teste planejado.

- Unitários (funções puras, table-driven):
- Service com fakes:
- Borda (httptest / evento de `testdata/`):
- Concorrência (race, goleak, synctest, limite respeitado, falha parcial, ordem):
- Integração (`-tags integration`):
- Fuzz (entradas externas):
- Benchmarks (`DPxx` / otimizações):
- Carga (se houver `DPxx` de sistema):

## Plano de medição de desempenho

> Só se houver `DPxx`. Como cada DP será medido, com qual ferramenta, em qual ambiente, e qual resultado aprova.

| DP | Ferramenta | Cenário | Critério de aprovação |
|---|---|---|---|
| DP01 | | | |

## Riscos técnicos

- Risco 1:
- Risco 2:

## Ordem de implementação

1. Tipos, erros de domínio e funções puras de parse/validação (+ testes unitários)
2. Persistência / repositórios (+ integração)
3. Service com regra de negócio (+ testes com fakes)
4. Concorrência conforme o desenho acima (+ race, goleak, synctest)
5. Borda HTTP ou Lambda (+ httptest / eventos de `testdata/`)
6. Wiring no `cmd/` e configuração
7. Build ARM64, IaC e observabilidade
8. Medição de desempenho (se houver `DPxx`)
9. Documentação
