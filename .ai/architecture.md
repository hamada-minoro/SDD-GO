# Architecture

> **Projeto único:** preencha todas as seções abaixo, exceto "Ecossistema".
>
> **Raiz com vários projetos** (APIs, Lambdas, workers, frontends, projetos complementares): este arquivo é o **mapa do ecossistema**. Preencha "Visão geral", "Ecossistema", "Padrões Go do ecossistema", "Autenticação e autorização" (a parte compartilhada), "Integrações externas e AWS", "Capacidade dos recursos compartilhados", "Decisões arquiteturais" e "Restrições" com o que vale para todos. Os detalhes de cada projeto vão em `.ai/architecture-<pasta-do-projeto>.md`, um arquivo por projeto, usando as seções "Stack" a "Restrições" deste modelo. Veja `README.md`, seção 3.2.
>
> Os trechos marcados como **padrão SDD-GO** são o ponto de partida recomendado (fundamentado em `.ai/go/`). Na Fase 0, confirme cada um contra o código real ou substitua pelo que o projeto de fato usa.

## Visão geral

Descreva aqui o propósito do sistema, o domínio e as principais funcionalidades.

## Ecossistema

> Só em raiz com vários projetos. Todo projeto da raiz aparece nesta tabela e tem o seu arquivo de arquitetura.

| Pasta do projeto | Tipo de entrega | Onde roda | Arquitetura de CPU | Gatilho / exposição | Repositório git próprio? | Arquitetura detalhada |
|---|---|---|---|---|---|---|
| `api-exemplo/` | API HTTP (Go) | ECS Fargate | arm64 | ALB `/v1/*` | sim/não | `architecture-api-exemplo.md` |
| `fn-exemplo/` | Lambda (Go) | Lambda `provided.al2023` | arm64 | SQS `fila-exemplo` | sim/não | `architecture-fn-exemplo.md` |

### Comunicação entre projetos

Descreva quem chama quem e por qual meio (REST, eventos EventBridge, SQS/SNS, streams, banco compartilhado), os contratos compartilhados (OpenAPI, schemas de evento, versões), as garantias de entrega de cada canal (at-least-once, ordem por chave) e a ordem de deploy, se houver dependência.

```txt
Cliente → API Gateway / ALB → api-exemplo ──(evento)──→ SQS → fn-exemplo → DynamoDB
                                   └──→ RDS Proxy → Postgres
```

## Padrões Go do ecossistema

> **Padrão SDD-GO:** os guias de `.ai/go/` valem para todo projeto Go da raiz. Registre aqui só o que é do ecossistema ou o que diverge deles.

- Versão do Go (diretiva `go` dos `go.mod`) e versão instalada verificada:
- Um `go.mod` por projeto; `go.work` versionado? (padrão: não)
- Onde roda e arquitetura de CPU padrão (padrão: arm64):
- Divergências dos guias `.ai/go/` (com motivo):

## Stack

- Linguagem: Go `x.y` (diretiva `go` do `go.mod`)
- Tipo de entrega: API HTTP / Lambda (gatilhos) / worker / CLI
- HTTP: `net/http` + `ServeMux` (padrão SDD-GO) ou framework justificado
- Banco de dados e driver: (ex.: Postgres 16 + `pgx/v5` via RDS Proxy; DynamoDB + `aws-sdk-go-v2`)
- Mensageria: (SQS, SNS, EventBridge, Kinesis)
- Autenticação:
- Infraestrutura e IaC: (SAM / CDK / Terraform; Lambda, ECS Fargate, EKS)
- Testes: `testing`, `httptest`, `synctest`, `goleak`, integração com build tag `integration`
- Lint: golangci-lint v2 / staticcheck

## Estrutura de pastas

```txt
<projeto>/
├── cmd/
│   └── <binario>/main.go
├── internal/
│   ├── <dominio>/
│   └── platform/
│       ├── config/
│       ├── database/
│       ├── httpx/
│       ├── awsx/
│       └── observability/
├── testdata/
├── go.mod
└── go.sum
```

## Camadas e padrões de código

> **Padrão SDD-GO:** `handler` (borda HTTP/Lambda: decode, validação de formato, status/resposta) → `service` (regra de negócio, orquestração, concorrência de I/O) → `repository` (SQL/DynamoDB parametrizado). Handlers não acessam banco. Erros de domínio mapeados na borda. Dependências por construtor, montadas no `main`.

Descreva aqui as particularidades do projeto: adaptador de handler, formato de erro do contrato, validação, paginação, versionamento de API.

## Modelo de concorrência do projeto

> O "padrão da casa" que toda spec herda. As specs só descrevem o que é específico delas (`CCxx`).

- Concorrência entre requisições/invocações: (ex.: goroutine por requisição do `net/http`; 1 invocação por ambiente na Lambda)
- Concorrência dentro de uma operação: padrões do catálogo usados no projeto e limites padrão (config):
- Estado compartilhado persistente e como a consistência é garantida: (ex.: `SELECT ... FOR UPDATE` em ordem crescente de id; `ConditionExpression`; idempotência por chave)
- Goroutines de longa duração (só em container): quais existem e como encerram no shutdown:
- Backpressure: o que acontece quando o limite estoura (503/429 com `Retry-After`, fila):

## Configuração de runtime

| Variável | Padrão | Descrição |
|---|---|---|
| `PORT` | 8080 | Porta HTTP (API) |
| `LOG_LEVEL` | info | Nível do slog |
| `DB_POOL_MAX` | | Conexões máximas por processo/ambiente |
| `DB_ACQUIRE_TIMEOUT_MS` | | Timeout só da aquisição de conexão |
| `MAX_CONCURRENCY` | | Limite de fan-out interno |
| `GOMEMLIMIT` | ~90% do limite | API em container |
| `GOMAXPROCS` | automático (Go ≥ 1.25) | Definir manualmente em Go ≤ 1.24 |

Lambda (por função): memória, timeout, concorrência reservada, batch size, `MaximumConcurrency`, DLQ, visibility timeout.

## Build, artefato e deploy

- Comando de build de produção:
- Artefato: (binário `bootstrap` zipado / imagem `distroless/static` `linux/arm64`)
- IaC: (onde fica e comando de deploy)
- Ambientes (dev/hml/prd) e como são separados:

## Banco de dados

Descreva padrões de tabelas/itens, chaves, índices, migrations, relacionamentos, nomenclaturas, transações, ordem de lock e idempotência.

## Autenticação e autorização

Descreva como usuários e serviços são autenticados (JWT, Cognito, IAM/SigV4, API key) e como permissões são verificadas. Inclua o padrão de roles IAM (uma por função, privilégio mínimo).

## Integrações externas e AWS

Liste APIs, serviços AWS, filas, storage, mensageria e dependências externas, com garantias de entrega e limites conhecidos.

## Capacidade dos recursos compartilhados

> Insumo obrigatório do "Desenho de concorrência" das specs (`.ai/go/concorrencia.md`, seção 6). Go eficiente empurra a carga para baixo: estes números definem os limites.

| Recurso | Capacidade | Quem consome | Observação |
|---|---|---|---|
| Postgres / RDS Proxy | (conexões máximas) | | |
| DynamoDB tabela X | (on-demand / RCU-WCU) | | |
| API de terceiro Y | (req/s, simultâneas) | | |
| Concorrência Lambda da conta/região | | | |

## Observabilidade

Logs, métricas, traces, dashboards e alarmes padrão. Onde ficam o pprof (porta administrativa) e os perfis de PGO.

## Linha de base de desempenho

> Resultados medidos (não estimados) que servem de referência para os `DPxx` das specs. Atualize a cada medição relevante, com data e condição.

| Entrega | Métrica | Valor | Condição | Data |
|---|---|---|---|---|
| | | | | |

## Decisões arquiteturais

Registre decisões importantes e seus motivos (ex.: arm64 como padrão; `net/http` sem framework; eventos nativos vs adapter HTTP na Lambda; RDS Proxy; lock pessimista em ordem determinística).

## Restrições

Liste o que a IA não deve fazer ou alterar sem autorização (contratos públicos, schema, IaC de produção, políticas IAM, versão do Go).
