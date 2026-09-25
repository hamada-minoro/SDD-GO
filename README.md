# SDD-GO — Spec Driven Development com IA para Go

Framework pronto para guiar o desenvolvimento de **APIs e AWS Lambdas em Go** com IA, a partir de documentos estruturados em vez de prompts soltos. O alvo é **ARM64 (Graviton)**. Basta copiar as pastas [`.ai/`](.ai/README.md) e [`.claude/`](.claude/README.md) (mais `AGENTS.md` e `CLAUDE.md`) para qualquer projeto e começar a usar.

É a edição Go do framework SDD: o fluxo é o mesmo (spec → plan → tasks → código → testes → review), mas cada etapa é obrigada a decidir o que faz Go render o máximo: **concorrência com goroutines, prazos com `context`, limites de recursos, binário nativo ARM64, memória e custo.**

## O que existe aqui

- **[`.ai/`](.ai/README.md)** — o framework em si: arquivos de contexto (`README.md`, `INSTRUCTIONS.md`, `prompts.md`, `ai-instructions.md`, `architecture.md`, `infraestrutura-testes.md`) e o ciclo de specs por feature (`spec.md`, `plan.md`, `tasks.md`, `build-logs.md`, `tests.md`, `review.md`), em pastas numeradas (`001-...`, `002-...`) que definem a ordem de execução, com templates prontos em `specs/template/` e ciclo de vida pendente → `specs/concluidos/`.
- **[`.ai/go/`](.ai/go/README.md)** — os guias da linguagem: [concorrência da spec ao código](.ai/go/concorrencia.md) (com os [padrões em código](.ai/go/concorrencia-padroes.md)), [Go idiomático](.ai/go/idiomatico.md), [testes e portões de qualidade](.ai/go/testes.md), [APIs HTTP](.ai/go/api-http.md), [Lambda em ARM64](.ai/go/lambda-aws.md), [DynamoDB](.ai/go/dados-dynamodb.md), [Postgres](.ai/go/dados-postgres.md) e [desempenho e custo](.ai/go/performance-e-custo.md). O benchmark e a pesquisa de origem ficam em [`referencias/`](.ai/go/referencias/estudo-node-vs-go.md), fora do caminho da IA.
- **[`AGENTS.md`](AGENTS.md)** — porta de entrada mínima para qualquer agente de IA (é carregado em toda sessão): manda para o [`.ai/ai-instructions.md`](.ai/ai-instructions.md), a fonte única do fluxo, da ordem de leitura, da numeração e das regras. O [`CLAUDE.md`](CLAUDE.md) só importa o `AGENTS.md`, para o Claude Code.
- **[`.claude/`](.claude/README.md)** — camada opcional de automação para o Claude Code: a skill `/executar-specs-pendentes` (orquestradora da fila) e o subagente `executor-spec-sdd`, que executa o ciclo SDD-GO completo de uma spec por vez, em contexto zerado, rodando os portões Go e commitando em branch própria, sem nunca dar push nem abrir PR.

## Benefícios para projetos Go

O fluxo continua o do SDD base (spec → plan → tasks → código → testes → review). A diferença é que cada etapa passa a ser obrigada a decidir o que faz o Go render o máximo:

| Benefício do Go | Como o SDD-GO faz aproveitar |
|---|---|
| **Goroutines baratas** | Concorrência vira requisito escrito (`CCxx`). Ela nasce na spec, ganha um desenho no plan, fica marcada no código e é provada por teste. |
| **`context` nativo** | O prazo total vem da spec e o plan divide esse tempo entre as etapas. Cancelar a requisição cancela também o banco e as chamadas à AWS. |
| **Binário nativo e ARM64** | ARM64/Graviton é o alvo padrão. O build `GOARCH=arm64` sem CGO é obrigatório; usar x86 exige justificativa. |
| **Pouca memória** | A memória vira requisito de desempenho (`DPxx`), com `GOMEMLIMIT` alinhado ao container. Na Lambda, a memória certa sai de medição. |
| **Stdlib forte** | `net/http`, `encoding/json` e `slog` primeiro. Cada dependência nova é registrada e checada com `govulncheck`. |
| **Tooling oficial** | Viraram verificações obrigatórias: race detector, fuzz, benchmarks com `benchstat`, synctest e goleak. |
| **Lições de um benchmark real** | O banco vira gargalo quando o Go fica eficiente, então todo limite de concorrência sai da capacidade de quem recebe a carga. Também entraram: um pool de conexões único, timeout de aquisição separado do timeout da operação, e as armadilhas de `PathValue` e de `go get` trocando o toolchain. |

## O que a IA sempre faz com o SDD-GO

### Ao gerar a spec

- **Tipo de entrega:** diz se é API HTTP, Lambda (e qual gatilho) ou worker.
- **Guias:** marca quais guias condicionais se aplicam (API, Lambda, DynamoDB, Postgres, desempenho). Só esses são lidos.
- **Concorrência (`CCxx`):** responde às 8 perguntas em linguagem de negócio: o que é independente, o que precisa de ordem (global ou por chave), o que é compartilhado, qual a capacidade de quem está abaixo, o que acontece em falha parcial, prazo, idempotência e volume.
- **Desempenho (`DPxx`):** escreve requisitos com número e forma de medir. Nunca "deve ser rápido".
- **Consistência:** se há estado compartilhado sob concorrência, exige um critério de aceite de consistência.
- **Revisão crítica:** procura trabalho independente sem `CCxx` (goroutine desperdiçada) e `CCxx` sem limite (risco de derrubar o banco).

### Ao gerar o plan

- **Desenho de concorrência:** cada `CCxx` vira um padrão `P1`–`P10` (`errgroup`, worker pool, pipeline, divisão por chave, semáforo, `singleflight`...). Cada um traz o limite e de onde ele vem, quem é o dono, como termina, como é cancelado, o que acontece na falha e qual teste prova.
- **Orçamento de prazos:** divide o tempo total entre as etapas.
- **Erros:** mapeia cada erro de domínio para a resposta HTTP ou para o tratamento na Lambda.
- **Runtime:** define arm64, memória, pools, `GOMEMLIMIT`, e batch/DLQ quando é Lambda.
- **Medição:** um plano de medição para cada `DPxx`.

### Ao gerar as tasks

- **Ordem de dentro para fora:** tipos → persistência → service → concorrência → borda HTTP/Lambda → wiring e deploy → desempenho.
- **Por `CCxx`:** uma tarefa de implementação e uma de teste.
- **Validação final:** as 8 verificações (`gofmt`, `vet`, lint, `-race`, integração, `govulncheck`, build arm64, `go mod tidy`).

### Ao implementar

- **Go idiomático:** `ctx` como primeiro parâmetro, erros com `%w` traduzidos na borda, interfaces pequenas no pacote que as usa, structs tipadas.
- **Padrões sob demanda:** lê o código de referência só dos padrões escolhidos no plan.
- **Goroutines só do desenho:** cada uma leva `// NNN-CCxx` no ponto em que nasce e segue as [regras CONC-01 a CONC-11](.ai/go/concorrencia.md) (limite, dono, cancelamento, nenhuma após o retorno da Lambda). Uma goroutine fora do desenho precisa ser registrada no `build-logs.md` antes de ser escrita.
- **Race a cada bloco:** roda `go test -race` ao fechar cada bloco com concorrência.
- **Sempre registra no `build-logs.md`:** dependência nova, mudança no `go.mod`, CGO ou x86, limites e pools diferentes do plan, e qualquer otimização (com a medição de antes e depois).
- **Critério de aprovação:** só marca "Aprovada" com todas as verificações passando. Race detectado ou goroutine sem limite reprova a spec.

## Onde isso aparece nos arquivos

| Onde | O que muda em relação ao SDD base |
|---|---|
| `spec.md` | Seções obrigatórias **"Concorrência e paralelismo"** (`CCxx`) e **"Desempenho, escala e custo"** (`DPxx`), tipo de entrega (API/Lambda/worker), contrato de entrada e saída e "Guias Go aplicáveis" |
| `plan.md` | **"Desenho de concorrência"**: cada `CCxx` vira uma primitiva concreta (errgroup, worker pool, pipeline, particionamento por chave, semáforo, singleflight) com limite, dono, término, cancelamento e teste; orçamento de prazos; configuração de runtime arm64; plano de medição |
| `tasks.md` | Blocos de dentro para fora (tipos → persistência → service → concorrência → borda → wiring → desempenho), uma tarefa por `CCxx` e os portões Go na validação |
| `tests.md` / `review.md` | Portões Go (`gofmt`, `vet`, lint, `-race`, integração, `govulncheck`, build `linux/arm64`, `go mod tidy`), testes de concorrência (goleak, synctest, estresse), fuzz, `benchstat`; checagem das regras CONC-01 a CONC-11 |
| Código | Rastreabilidade também da concorrência: `// 007-CC02` no ponto em que a goroutine/limite nasce |
| `architecture.md` | Modelo de concorrência do projeto, configuração de runtime, build ARM64, **capacidade dos recursos compartilhados** e linha de base de desempenho |
| `prompts.md` | Prompts adaptados + auditoria de concorrência, investigação de desempenho e portabilidade de serviço para Go |
| Contexto da IA | Fonte única para cada regra, guias lidos só quando a spec os marca, código dos padrões lido sob demanda e o "porquê" separado em arquivos para humanos: cerca de **23 mil tokens** para gerar spec, plan e tasks (ver "Quantos tokens a IA gasta por rodada") |

## Quantos tokens a IA gasta por rodada

Estimativa do contexto que a IA carrega **lendo o framework** em cada tipo de rodada. Os números são aproximados: cada ~1.000 tokens equivale a ~3.000 caracteres de Markdown.

| Rodada | API HTTP + DynamoDB | API HTTP + DynamoDB + `DPxx` | Lambda (SQS) + DynamoDB + `DPxx` |
|---|---:|---:|---:|
| **Criar spec, plan e tasks** | ~22.700 | ~24.100 | ~24.400 |
| **Executar a spec** (implementação acompanhada) | ~23.000 | ~24.400 | ~24.700 |
| **Executar a spec no modo autônomo** (`/executar-specs-pendentes`, por spec) | ~25.800 | ~27.100 | ~27.500 |

O que entra em cada rodada:

- **Criar:**
  - `AGENTS.md`;
  - `ai-instructions.md`, `architecture.md` e `infraestrutura-testes.md`;
  - os guias sempre lidos (`idiomatico`, `concorrencia`, `testes`);
  - os guias marcados na spec;
  - os 6 templates que a IA copia e preenche.
- **Executar:** os mesmos arquivos (com os 6 da spec já preenchidos) + a seção de `concorrencia-padroes.md` de cada padrão escolhido no plan (~300 tokens por padrão).
- **Modo autônomo:** o mesmo que executar + as instruções do subagente `executor-spec-sdd` (~2.700).

O que **não** entra na conta:

- o código do projeto que a IA lê e escreve;
- a saída gerada;
- o crescimento dos arquivos depois de preenchidos. `architecture.md`, `infraestrutura-testes.md` e os arquivos da spec crescem na Fase 0 e ao longo do uso; a medição usa os arquivos como distribuídos.

Metodologia e tabela arquivo por arquivo: [`.ai/README.md`, seção 5.2](.ai/README.md#52-estudo-de-custo-de-contexto).

## Por que existe

Para fugir do *vibe coding*: a IA gerando código a partir de uma ideia vaga, sem contrato, sem plano e sem validação. Em Go, o *vibe coding* mais caro é a **goroutine improvisada**: sem limite, sem dono, sem cancelamento. Ela vaza, corre e derruba o banco. Também desperdiça a linguagem quem escreve Go sequencial onde havia I/O independente para sobrepor.

Este framework nasceu de um benchmark real Node.js vs Go (mesmo contrato, mesmo banco, 4 CPUs/1 GiB): Go entregou **~1,6x mais vazão, ~1,7x menos CPU por requisição e ~5x menos memória**, e com isso empurrou o gargalo para o banco. As lições desse estudo viraram regras aqui. Detalhes e ressalvas em [`.ai/go/README.md`](.ai/go/README.md).

## Como usar

1. Copie `.ai/`, `.claude/`, `AGENTS.md` e `CLAUDE.md` para a raiz do seu projeto. Se o projeto já tiver um `CLAUDE.md`, não o substitua: acrescente a linha `@AGENTS.md` no topo dele.
2. Rode a **Fase 0 (setup)** com o prompt "0. Setup" de [`.ai/prompts.md`](.ai/prompts.md): a IA analisa o projeto real (módulos Go, binários, modelo de concorrência, capacidade dos recursos, toolchain) e preenche `architecture.md`, `infraestrutura-testes.md` e a seção "Informações específicas do projeto" do `ai-instructions.md`. Se a raiz agrupar vários projetos, ela também cria um `.ai/architecture-<pasta-do-projeto>.md` para cada um ([`.ai/README.md`](.ai/README.md), seção 3.2).
3. Para cada feature, copie `.ai/specs/template/` para `.ai/specs/NNN-<nome-da-feature>/`, onde `NNN` é o maior número já usado em `.ai/specs/` e `.ai/specs/concluidos/` + 1 (ex.: `008-exportar-relatorio`), e siga as fases de [`.ai/INSTRUCTIONS.md`](.ai/INSTRUCTIONS.md) com os prompts prontos de [`.ai/prompts.md`](.ai/prompts.md).
4. (Opcional) Com várias specs prontas acumuladas, execute tudo em lote com `/executar-specs-pendentes` no Claude Code — veja [`.claude/README.md`](.claude/README.md).

Conceito e fundamentos em [`.ai/README.md`](.ai/README.md). Guias da linguagem em [`.ai/go/README.md`](.ai/go/README.md).
