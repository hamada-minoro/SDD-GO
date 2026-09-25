# Manual de Spec Driven Development com IA — edição Go (SDD-GO)

> **Leitura humana.** Este manual explica o que é Spec Driven Development com IA e por que o framework é organizado assim. A IA **não** lê este arquivo no dia a dia (só na Fase 0): o contrato dela é o `AGENTS.md` + o `ai-instructions.md`, que é a fonte única do fluxo, da ordem de leitura, da numeração e das regras. Ver seção 5.
>
> Para orientações de comportamento da IA, veja `ai-instructions.md`.
> Para o passo a passo de como operar o fluxo no dia a dia, veja `INSTRUCTIONS.md`.
> Para os prompts prontos de cada etapa, veja `prompts.md`.
> Para os guias da linguagem (concorrência, idioma, testes, API HTTP, Lambda, desempenho), veja `go/README.md`.
>
> Objetivo: impedir o desenvolvimento por tentativa, improviso ou *vibe coding*, obrigando a IA a entender o contexto, ler os documentos certos, planejar, quebrar tarefas e só então implementar.
>
> Objetivo específico do SDD-GO: fazer com que cada spec seja **pensada em Go desde o início**, para APIs e AWS Lambdas em ARM64. Concorrência com goroutines, prazos com `context`, limites de recursos, custo e desempenho viram requisitos escritos na spec, desenho no plano, código rastreável e testes que provam. Não ficam como improviso na hora de codar.

---

## 1. Visão geral

Spec Driven Development com IA é um fluxo onde a implementação nasce de documentos estruturados, não de prompts soltos.

A IA não deve começar codando. Ela deve primeiro entender:

1. o contexto do projeto;
2. a arquitetura existente;
3. as regras de desenvolvimento;
4. a especificação da funcionalidade;
5. o plano técnico;
6. a lista de tarefas;
7. os critérios de aceite.

Somente depois disso a IA pode iniciar a implementação.

O fluxo base deste projeto usa oito arquivos principais. Os dois primeiros são globais do projeto (ficam na raiz de `.ai/`); os outros seis são **por feature** e ficam na pasta da spec (`.ai/specs/NNN-nome-da-feature/`):

```txt
ai-instructions.md
architecture.md
spec.md
plan.md
tasks.md
build-logs.md
tests.md
review.md
```

Cada um possui uma função específica dentro do processo.

Os cinco primeiros (`ai-instructions.md` a `tasks.md`) guiam o que será construído e como. O `build-logs.md` registra o que de fato aconteceu durante a construção: cada decisão técnica relevante, cada desvio do plano e o motivo por trás deles. O `tests.md` documenta os testes unitários (e de integração) escritos para a feature, cruzando cada teste com a regra de negócio ou critério de aceite que ele cobre. O `review.md` registra o resultado de cada validação da implementação contra a `spec.md`. Juntos, `build-logs.md`, `tests.md` e `review.md` dão ao desenvolvedor rastreabilidade total sobre o trabalho da IA, mesmo sem ter acompanhado a implementação em tempo real.

---

## 2. Objetivo do fluxo

Este fluxo existe para que a IA trabalhe como uma engenheira auxiliar, e não como uma geradora aleatória de código.

A finalidade é garantir que toda feature tenha:

- contexto claro;
- regras de negócio documentadas;
- arquitetura respeitada;
- plano técnico antes da implementação;
- tarefas pequenas e rastreáveis;
- critérios de aceite objetivos;
- validação antes de considerar a entrega finalizada.

O desenvolvimento deve ser guiado por documentos, não por tentativa e erro.

---

## 3. Estrutura recomendada de arquivos

A estrutura é organizada na pasta do projeto dentro de `.ai/`. Basta copiar esta pasta para qualquer projeto novo para já começar com o framework pronto.

```txt
projeto/
├── AGENTS.md                          # porta de entrada da IA (enxuto: carregado em toda sessão)
├── CLAUDE.md                          # só importa o AGENTS.md (@AGENTS.md), para o Claude Code
├── .ai/
│   ├── README.md                      # humanos: este manual
│   ├── INSTRUCTIONS.md                # humanos: operação fase a fase
│   ├── prompts.md                     # humanos: prompts prontos para colar
│   ├── ai-instructions.md             # IA: fonte única do fluxo, leitura, numeração e regras
│   ├── architecture.md                # visão geral; em raiz multiprojeto, o mapa do ecossistema
│   ├── architecture-<projeto>.md      # obrigatório em raiz multiprojeto: um por pasta de projeto
│   ├── infraestrutura-testes.md       # referência verificada do ambiente local de testes
│   ├── go/                            # guias da linguagem (seção 4.9)
│   │   ├── README.md                  # humanos: índice + benefícios de Go → diretrizes
│   │   ├── idiomatico.md              # IA: sempre
│   │   ├── concorrencia.md            # IA: sempre (perguntas, decisão, padrões P1–P10, regras CONC)
│   │   ├── testes.md                  # IA: sempre (fonte única dos portões)
│   │   ├── concorrencia-padroes.md    # IA: na implementação, só as seções dos padrões escolhidos
│   │   ├── api-http.md                # IA: se a spec marcar
│   │   ├── lambda-aws.md              # IA: se a spec marcar
│   │   ├── dados-dynamodb.md          # IA: se a spec marcar
│   │   ├── dados-postgres.md          # IA: se a spec marcar
│   │   ├── performance-e-custo.md     # IA: se a spec tiver DPxx
│   │   └── referencias/
│   │       └── estudo-node-vs-go.md   # humanos: benchmark de origem e pesquisa
│   └── specs/
│       ├── template/                  # modelos dos arquivos de feature — copie para criar uma feature
│       │   ├── spec.md
│       │   ├── plan.md
│       │   ├── tasks.md
│       │   ├── build-logs.md
│       │   ├── tests.md
│       │   └── review.md
│       ├── concluidos/                # specs finalizadas e aprovadas são movidas para cá (mantêm o número)
│       │   └── 001-nome-da-feature/
│       └── 002-nome-da-feature/       # uma pasta numerada por feature pendente/em andamento
│           ├── spec.md
│           ├── plan.md
│           ├── tasks.md
│           ├── build-logs.md
│           ├── tests.md
│           └── review.md
├── .claude/                           # opcional — automação para Claude Code (ver .claude/README.md)
│   ├── agents/executor-spec-sdd.md
│   └── skills/executar-specs-pendentes/
├── cmd/                               # um main por binário (API, cada Lambda)
├── internal/                          # domínios + platform
├── go.mod
└── go.sum
```

Sobre as peças além do fluxo base:

- **`architecture-<projeto>.md`**: obrigatório quando a raiz agrupa vários projetos (seção 3.2). Existe um arquivo por projeto, com o nome da pasta do projeto (ex.: `architecture-api-pedidos.md`). A IA lê o `architecture.md` geral e depois só os arquivos dos projetos que a feature toca.
- **`infraestrutura-testes.md`** — memória verificada do ambiente local de testes (toolchain Go, portas reais, containers, como subir a stack, limitações conhecidas). Evita que cada sessão de IA redescubra — ou pior, assuma errado — como rodar testes de integração/E2E.
- **`go/`** — os guias da linguagem. Três são lidos sempre (`idiomatico.md`, `concorrencia.md`, `testes.md`); os outros só quando a spec os marca em "Guias Go aplicáveis" (seção 4.9).
- **`AGENTS.md` / `CLAUDE.md`** (na raiz do projeto) — o `AGENTS.md` é lido automaticamente pelos agentes de IA e os manda para o `ai-instructions.md`: criar spec/plan/tasks quando a tarefa ainda não tem spec e ler os arquivos obrigatórios quando já tem. Ele é carregado em **toda** sessão do Claude Code, por isso é mínimo. O `CLAUDE.md` só contém `@AGENTS.md`.
- **`specs/template/`** — os modelos dos seis arquivos de feature (`spec.md`, `plan.md`, `tasks.md`, `build-logs.md`, `tests.md`, `review.md`). Para criar uma feature, copie a pasta e renomeie seguindo a numeração (seção 3.1). A automação também usa esses modelos quando precisa gerar `plan.md`/`tasks.md`.
- **`specs/concluidos/`** — ciclo de vida das specs: pendente (em `specs/`) → aprovada na validação → movida para `concluidos/`. A fila de pendências é simplesmente o que ainda está em `specs/`, na ordem numérica.

### 3.1 Numeração das specs

> Regra oficial para a IA: `ai-instructions.md`, seção 3. Esta seção explica a mesma regra para humanos.

Toda pasta de feature começa com um número sequencial de 3 dígitos: `NNN-nome-da-feature` (ex.: `001-login`, `002-recuperar-senha`). **O número define a ordem de execução**: a fila de pendências é sempre processada do menor número para o maior, seja manualmente, seja pela automação da `.claude/`.

Ao criar uma feature nova:

1. Procure o maior número já usado **nas duas** pastas, `.ai/specs/` e `.ai/specs/concluidos/`:

   ```bash
   ls -1 .ai/specs .ai/specs/concluidos 2>/dev/null | grep -E '^[0-9]+-' | sed -E 's/^([0-9]+)-.*/\1/' | sort -n | tail -1
   ```

2. Use o número seguinte, com 3 dígitos (`007` → `008`). Sem nenhuma spec, comece em `001`.
3. Nunca reutilize um número (nem de spec concluída) e nunca renumere specs existentes. Se uma feature precisar rodar antes de outra já criada, ajuste a dependência na spec em vez de trocar números.

Pastas sem prefixo numérico não entram na fila automática. Renomeie-as seguindo a sequência.

### 3.2 Raiz com vários projetos (microsserviços, APIs e frontends separados)

É comum instalar `.ai/` e `.claude/` numa **pasta raiz que agrupa vários projetos** do mesmo ecossistema: APIs, frontends, workers, lambdas, microsserviços ou projetos complementares, muitas vezes cada um com seu próprio repositório git. Nesse cenário a arquitetura é documentada em dois níveis, e **os dois são obrigatórios**:

```txt
raiz-do-ecossistema/
├── AGENTS.md
├── CLAUDE.md
├── .ai/
│   ├── architecture.md                    # mapa do ecossistema
│   ├── architecture-api-pedidos.md        # um por projeto da raiz
│   ├── architecture-api-pagamentos.md
│   ├── architecture-web-admin.md
│   └── ...
├── .claude/
├── api-pedidos/                           # projeto (repositório próprio ou não)
├── api-pagamentos/
└── web-admin/
```

- **`architecture.md` é o mapa do ecossistema.** Traz a tabela de projetos (pasta, tipo, stack, repositório, arquivo de arquitetura), como eles se comunicam (APIs, eventos, filas, banco compartilhado), os contratos entre eles e os conceitos comuns, como autenticação e padrões transversais. Os detalhes internos de cada projeto não ficam aqui.
- **`architecture-<projeto>.md` descreve um projeto.** Existe **um arquivo para cada projeto da raiz**, e `<projeto>` é **exatamente o nome da pasta** do projeto (`api-pedidos/` → `architecture-api-pedidos.md`). Ele traz stack, estrutura de pastas, padrões, banco, testes e restrições daquele projeto, usando as mesmas seções do modelo `architecture.md`.
- **Projeto sem arquivo de arquitetura não recebe feature.** Se uma spec toca um projeto que ainda não tem `architecture-<projeto>.md`, gere esse arquivo primeiro (prompt "0. Setup" de `prompts.md`, focado no projeto novo) e inclua o projeto na tabela do `architecture.md`.
- **Projeto novo na raiz = arquivo novo.** Ao adicionar um projeto à raiz, crie o `architecture-<projeto>.md` dele e atualize o mapa do ecossistema antes da primeira spec que o toque.
- **A spec diz quais projetos e arquiteturas entram.** A tabela "Projetos e arquiteturas envolvidos" da `spec.md` lista cada projeto que a feature altera e o arquivo de arquitetura dele. O `plan.md` repete essa tabela com a ordem entre os projetos, e a "Preparação" do `tasks.md` lista os arquivos a ler, um por item. Essa tabela também define em quais repositórios a automação cria branches.
- **Contexto mínimo: a IA lê só o que vai mexer.** Para executar uma feature, a IA lê o `architecture.md` (o mapa) e **apenas** os `architecture-<projeto>.md` da tabela da spec. Nunca lê as arquiteturas de todos os projetos "por garantia": isso polui o contexto e piora a execução. Se durante a execução aparecer a necessidade de mexer num projeto fora da tabela, a IA para, atualiza spec/plan/tasks, registra a decisão no `build-logs.md` da feature e só então lê a arquitetura desse projeto.

Em um projeto único (um só repositório na raiz), basta o `architecture.md`, sem arquivos por projeto.
- **`.claude/`** — camada opcional de execução autônoma para o Claude Code (ver seção 10 e `.claude/README.md`).

---

## 4. Função de cada arquivo

### 4.1 `ai-instructions.md`

Este é o arquivo de comportamento da IA.

Ele define como a IA deve agir dentro do projeto.

Deve conter:

- papel da IA no projeto;
- regras de desenvolvimento;
- padrões de resposta;
- o que a IA pode ou não pode fazer;
- ordem obrigatória de leitura dos arquivos;
- regras para alteração de código;
- regras para atualização de documentação;
- instruções para testes e validação.

Este arquivo é o mais parecido com um `CLAUDE.md`.

A IA deve ler este arquivo antes de qualquer tarefa relevante.

---

### 4.2 `architecture.md` (e `architecture-<projeto>.md`)

Este arquivo descreve a arquitetura do projeto. Em raiz com vários projetos, ele vira o mapa do ecossistema e cada projeto tem o seu `architecture-<projeto>.md` com o conteúdo abaixo (seção 3.2).

Ele responde à pergunta:

> Como o sistema está organizado tecnicamente?

Deve conter:

- stack utilizada (versão do Go, dependências principais);
- tipo de cada entrega (API HTTP, Lambda e gatilho, worker) e onde roda (Lambda arm64, ECS Fargate, EKS);
- estrutura de pastas (`cmd/`, `internal/`);
- camadas (handler → service → repository);
- modelo de concorrência do projeto (o "padrão da casa");
- configuração de runtime (`GOMAXPROCS`, `GOMEMLIMIT`, pools, limites);
- build, artefato e deploy (arm64, IaC);
- padrão de autenticação e autorização;
- banco de dados, transações e idempotência;
- integrações externas e AWS;
- capacidade dos recursos compartilhados (insumo dos limites de concorrência);
- linha de base de desempenho medida;
- decisões arquiteturais importantes;
- restrições técnicas.

A IA deve usar este arquivo para evitar criar soluções fora do padrão do projeto.

---

### 4.3 `spec.md`

Este arquivo descreve o que deve ser construído.

Ele responde à pergunta:

> Qual problema estamos resolvendo e qual comportamento a feature precisa ter?

Deve conter:

- contexto da funcionalidade;
- problema que será resolvido;
- objetivo da feature;
- usuários envolvidos;
- fluxo funcional esperado;
- contrato de entrada e saída (endpoint ou evento);
- regras de negócio (`RNxx`);
- **concorrência e paralelismo (`CCxx`)**: o que é independente, o que tem ordem, o que é compartilhado, limites downstream, falha parcial, prazo, idempotência, volume;
- **desempenho, escala e custo (`DPxx`)**: requisitos mensuráveis;
- guias Go aplicáveis;
- permissões (incluindo IAM);
- dados necessários e validações;
- casos de erro e mensagens;
- critérios de aceite (`CAxx`);
- casos de borda;
- fora de escopo.

A `spec.md` não deve focar inicialmente em código. Ela deve focar no comportamento esperado da funcionalidade. Mesmo as seções de concorrência e desempenho são escritas em linguagem de **negócio e operação** ("as três consultas são independentes", "no máximo 20 chamadas simultâneas ao parceiro"). A tradução para goroutines, `errgroup` e canais é trabalho do `plan.md`.

---

### 4.4 `plan.md`

Este arquivo transforma a especificação em plano técnico.

Ele responde à pergunta:

> Como vamos implementar isso respeitando a arquitetura existente?

Deve conter:

- resumo técnico da solução;
- pacotes e arquivos afetados;
- tipos, interfaces, contratos e mapeamento de erros;
- endpoints ou eventos;
- impacto no banco de dados (migrations, chaves, transações, ordem de lock, idempotência);
- integrações AWS e externas (com IAM);
- **desenho de concorrência**: cada `CCxx` → padrão do catálogo, limite e origem do limite, dono, término, cancelamento, tratamento de falha e teste que prova;
- contexto, prazos e timeouts por etapa;
- configuração de runtime e deploy (arm64, memória, pools, limites);
- observabilidade;
- estratégia de testes (incluindo race, goleak, synctest, fuzz, benchmarks);
- plano de medição dos `DPxx`;
- riscos técnicos;
- ordem sugerida de implementação.

A diferença central é:

```txt
spec.md = o que precisa existir
plan.md = como isso será construído
```

---

### 4.5 `tasks.md`

Este arquivo quebra o plano em tarefas pequenas e executáveis.

Ele responde à pergunta:

> Quais passos objetivos precisam ser feitos para concluir a feature?

Deve conter uma checklist clara, organizada por área (tipos e regras puras, persistência, service, concorrência com uma tarefa por `CCxx`, borda HTTP/Lambda, wiring e deploy, desempenho, portões de validação, documentação).

A IA deve implementar seguindo essa ordem, marcando o progresso conforme avança.

---

### 4.6 `tests.md`

Este arquivo documenta os testes unitários (e de integração, quando aplicável) escritos para a feature.

Ele responde à pergunta:

> O que foi testado, como, e isso cobre as regras de negócio da spec?

Deve conter:

- referência de qual regra de negócio (`RN`), critério de aceite (`CA`), requisito de concorrência (`CC`) ou de desempenho (`DP`) cada teste cobre;
- cenário testado e resultado esperado;
- status do teste (passou, falhou, pendente);
- resultado dos portões de qualidade Go (vet, lint, race, govulncheck, build arm64);
- testes de concorrência (race, goleak, synctest, estresse), fuzz e benchmarks (com `benchstat`);
- casos de borda cobertos e não cobertos (com o motivo, quando não cobertos).

A IA deve atualizar este arquivo durante o bloco "Testes" da implementação (item 5 da ordem sugerida em `tasks.md`/`plan.md`), e ele serve de insumo para a revisão registrada em `review.md`.

---

### 4.7 `review.md`

Este arquivo registra o histórico de validações da implementação contra a `spec.md`.

Ele responde à pergunta:

> O que foi entregue realmente cumpre o que a spec pedia?

Diferente de `spec.md`, `plan.md` e `tasks.md` (escritos antes de codar), `review.md` é escrito *depois* — uma entrada nova a cada execução da validação (Fase 7), sem sobrescrever entradas anteriores. Cada entrada deve registrar:

- data da revisão;
- critérios de aceite cumpridos e não cumpridos;
- regras de negócio cobertas e não cobertas;
- casos de erro e permissões verificados;
- se os testes em `tests.md` cobrem o que foi revisado;
- pendências encontradas;
- conclusão: aprovada, aprovada com pendências, ou reprovada.

Sem o `review.md`, cada validação fica só na conversa com a IA e se perde — o desenvolvedor não tem como comparar revisões ao longo do tempo nem provar que a entrega foi de fato conferida contra a spec.

---

### 4.8 `build-logs.md`

Este é o diário de decisões da implementação. Cada feature tem o **seu próprio** `build-logs.md`, dentro da pasta da spec (`.ai/specs/NNN-nome-da-feature/build-logs.md`), criado a partir de `specs/template/build-logs.md`. Não existe build-logs global: as decisões de uma feature ficam junto da spec, do plano e dos testes dela e acompanham a pasta quando ela vai para `concluidos/`.

Ele responde à pergunta:

> O que realmente aconteceu durante o desenvolvimento, e por quê?

Diferente dos demais arquivos, que são escritos *antes* de codar, o `build-logs.md` é escrito *durante* e *depois*, à medida que decisões são tomadas.

Cada entrada deve registrar:

- data e hora (ou referência da tarefa/bloco em andamento);
- a decisão tomada;
- o motivo da decisão (por que essa opção e não outra);
- alternativas consideradas e descartadas, quando relevante;
- impacto da decisão (arquivos, módulos, comportamento, escopo);
- se a decisão é uma divergência em relação à `spec.md` ou ao `plan.md`, e se essa divergência foi validada com o desenvolvedor.

A IA deve adicionar uma entrada sempre que:

- escolher entre duas ou mais abordagens técnicas possíveis;
- desviar do que estava descrito no `plan.md` ou no `tasks.md`;
- descobrir uma lacuna na `spec.md` e precisar tomar uma decisão para seguir;
- introduzir uma dependência, biblioteca ou padrão novo;
- tomar qualquer decisão que não seria óbvia só de olhar o código depois.

A IA **não** deve usar o `build-logs.md` para narrar o que o código já deixa claro (ex: "criei o arquivo X com a função Y"). O objetivo é registrar o raciocínio, não o diff.

Sem o `build-logs.md`, a IA pode codar livremente e o desenvolvedor perde o porquê de cada escolha — o que é exatamente o tipo de *vibe coding* que este manual existe para evitar.

---

### 4.9 Guias Go (`.ai/go/`)

Os guias respondem à pergunta:

> Como transformar esta spec em Go que aproveita o que a linguagem tem de melhor?

| Guia | Leitura pela IA | Assunto |
|---|---|---|
| `go/README.md` | Não (humanos) | Índice e benefícios de Go mapeados para diretrizes |
| `go/idiomatico.md` | Sempre | Versão/toolchain, layout, erros, `context`, interfaces, dependências, lint |
| `go/concorrencia.md` | Sempre | Perguntas `CCxx`, decisão, padrões `P1`–`P10`, regras CONC-01 a CONC-11 |
| `go/testes.md` | Sempre | Portões de qualidade (fonte única), race, goleak, synctest, fuzz, benchmarks |
| `go/concorrencia-padroes.md` | Na implementação, só as seções escolhidas | Código de referência de cada padrão |
| `go/api-http.md` | Se marcado na spec | `net/http`, servidor, runtime no container, container ARM64 |
| `go/lambda-aws.md` | Se marcado na spec | `provided.al2023` arm64, INIT/INVOKE, SQS/Kinesis/API Gateway, cold start |
| `go/dados-dynamodb.md` | Se marcado na spec | Padrões de acesso, idempotência, batch, capacidade |
| `go/dados-postgres.md` | Se marcado na spec | `pgxpool`, transações, locks, `ON CONFLICT`, RDS Proxy |
| `go/performance-e-custo.md` | Se marcado na spec | Métricas, metodologia de benchmark, pprof, PGO, custo ARM vs x86 |
| `go/referencias/estudo-node-vs-go.md` | Não (humanos) | Benchmark de origem, lições e pesquisa Go + ARM + AWS |

Os guias são a **fonte de verdade de idioma Go** do framework. O `architecture-<projeto>.md` pode ser mais específico e, nesse caso, prevalece.

#### Goroutines do papel ao código

Concorrência é o maior diferencial de Go e o lugar onde mais se erra. O SDD-GO a trata como requisito rastreável em todas as etapas:

```txt
spec.md     CCxx em linguagem de negócio/operação
              "as 3 consultas são independentes; falha de uma cancela o pedido; prazo 800 ms"
                ↓
plan.md     Desenho de concorrência: CCxx → padrão P1–P10 (errgroup, worker pool,
              pipeline, particionamento por chave, semáforo, singleflight...), limite e sua
              origem, dono, término, cancelamento, falha parcial, teste que prova
                ↓
tasks.md    uma tarefa de implementação + uma de teste por CCxx
                ↓
código      // 007-CC01 no ponto em que a goroutine/limite/canal nasce
                ↓
tests.md    race, goleak, synctest, limite respeitado, falha parcial, ordem por chave
                ↓
review.md   CCxx cumprido + checagem das regras CONC-01 a CONC-11
```

O mesmo vale para desempenho (`DPxx`): número na spec → plano de medição no plan → benchmark/carga → resultado no `tests.md` → verificação no `review.md`.

---

## 5. O que a IA lê, e quanto isso custa

### 5.1 Princípio: o "porquê" é para humanos, o "o que fazer" é para a IA

Todo arquivo que a IA lê custa tokens e divide a atenção dela. Por isso o framework separa dois públicos:

- **Para a IA:** regras curtas e imperativas, cada uma com no máximo uma linha de justificativa. Estão no `AGENTS.md`, no `ai-instructions.md`, nos guias de `.ai/go/` e nos templates.
- **Para humanos:** conceito, motivação, operação, prompts, benchmark e pesquisa. Estão neste manual, no `INSTRUCTIONS.md`, no `prompts.md`, no `go/README.md` e em `go/referencias/`. A IA não os lê, salvo na Fase 0.

Três regras mantêm o contexto enxuto:

1. **Fonte única.** Cada regra mora num lugar só (fluxo, leitura e numeração no `ai-instructions.md`; portões no `go/testes.md`; regras de concorrência no `go/concorrencia.md`), e os outros arquivos apontam para ela. Isso economiza tokens e evita cópias que divergem.
2. **Leitura condicional.** A spec marca quais arquiteturas e guias se aplicam; o resto não é lido.
3. **Leitura sob demanda.** O código dos padrões de concorrência só é lido na implementação, e só a seção do padrão escolhido no plan.

A **ordem oficial de leitura** está no `ai-instructions.md`, seção 2. Em resumo: os globais (`ai-instructions`, `architecture`, `infraestrutura-testes` e os guias `idiomatico`, `concorrencia`, `testes`) → `spec.md` → as arquiteturas e os guias marcados na spec → `plan.md`, `tasks.md`, `build-logs.md`, `tests.md` e `review.md`.

### 5.2 Estudo de custo de contexto

Medição feita na reorganização do framework (2026-09-25), com o prompt de exemplo:

> "Seguindo os padrões de SDD, idealize spec, plan e tasks para implementarmos uma rota que vai receber o payload X, fazer uma busca na tabela Y do DynamoDB, processar os dados e retornar ao frontend."

A IA lê os obrigatórios globais, os templates que copia e preenche, e os guias que a spec marca (aqui, API HTTP + DynamoDB).

| Arquivo | Lido pela IA? | Antes (~tokens) | Depois (~tokens) |
|---|---|---:|---:|
| `AGENTS.md` (carregado em **toda** sessão) | sim | 2.657 | **597** |
| `.ai/README.md` (este manual) | antes sim; agora não | 10.379 | — |
| `.ai/prompts.md` | antes sim (o `AGENTS.md` mandava seguir o prompt 1); agora não | 6.843 | — |
| `ai-instructions.md` | sim | 5.031 | 3.019 |
| `architecture.md` + `infraestrutura-testes.md` (templates) | sim | 4.104 | 3.830 |
| `go/idiomatico.md` | sim | 3.311 | 1.657 |
| `go/concorrencia.md` | sim | 6.171 | 2.152 |
| `go/testes.md` | sim | 2.965 | 1.915 |
| `go/api-http.md` | marcado na spec | 3.752 | 1.953 |
| `go/dados-dynamodb.md` | marcado na spec | não existia | 1.233 |
| Templates da spec (os 6 arquivos) | sim | 6.981 | 6.385 |
| **Total para gerar spec, plan e tasks** | | **~52.200** | **~22.700 (−56%)** |

Outros cenários, com a mesma medição:

| Cenário | Antes | Depois | Economia |
|---|---:|---:|---:|
| API HTTP + DynamoDB | ~52.200 | ~22.700 | 56% |
| API HTTP + DynamoDB + requisitos `DPxx` | ~54.500 | ~24.100 | 56% |
| Lambda (SQS) + DynamoDB + requisitos `DPxx` | ~54.900 | ~24.400 | 56% |
| Executar a spec (API HTTP + DynamoDB, 1 padrão de concorrência) | ~45.400 | ~23.000 | 49% |
| Executar no modo autônomo (idem + instruções do subagente) | ~52.600 | ~25.800 | 51% |
| Na implementação: código de referência dos padrões de concorrência | junto no `concorrencia.md` | +~220 a 300 por padrão escolhido | só o necessário |
| Modo autônomo: instruções do subagente `executor-spec-sdd`, por spec | ~7.200 | ~2.700 | 62% |

O que mudou para chegar a esses números:

- **Manual, prompts e estudo saíram do caminho da IA:** este `README.md`, o `prompts.md`, o `go/README.md` e o benchmark (agora em `go/referencias/`) são leitura humana.
- **Fonte única:** ordem de leitura, numeração e regras só no `ai-instructions.md`; portões só no `go/testes.md`; regras de concorrência só no `go/concorrencia.md`. Antes, a ordem de leitura aparecia em 6 arquivos e os portões em 5.
- **Concorrência dividida:** o núcleo (perguntas, decisão, padrões `P1`–`P10`, regras) é sempre lido; o código de cada padrão fica em `go/concorrencia-padroes.md` e é lido por seção, só na implementação.
- **Guias de dados condicionais:** `dados-dynamodb.md` e `dados-postgres.md`. Antes, uma rota com DynamoDB lia a seção de `pgx` do `api-http.md` e **não** recebia orientação de DynamoDB, que estava dentro do `lambda-aws.md`. Agora o contexto é menor e mais preciso.
- **`AGENTS.md` mínimo:** −2.060 tokens em toda sessão do Claude Code, inclusive nas que não têm nada a ver com specs.

Como foi medido: tokens estimados como **caracteres ÷ 3** (aproximação para Markdown em português com código), sobre os arquivos do framework como distribuídos, sem preenchimento. Na prática, `architecture.md`, `infraestrutura-testes.md` e a própria spec crescem na Fase 0 e ao serem preenchidos, igualmente antes e depois. Os valores absolutos são estimativa; a comparação relativa é o que importa.

---

## 6. Fluxo completo de trabalho

O fluxo ideal é:

```txt
Setup do projeto (analisar arquitetura real e gerar architecture.md)
        ↓
Ideia ou necessidade
        ↓
Criar a pasta .ai/specs/NNN-nome-da-feature/ (próximo número da sequência)
        ↓
Criar ou atualizar spec.md (incluindo CCxx e DPxx)
        ↓
Revisar a spec com a IA (perguntas de concorrência respondidas? DPxx mensuráveis?)
        ↓
Criar plan.md (com o desenho de concorrência e o plano de medição)
        ↓
Revisar o plano técnico
        ↓
Criar tasks.md
        ↓
IA lê ai-instructions.md, architecture.md, infraestrutura-testes.md e os guias Go obrigatórios
        ↓
IA lê spec.md, as arquiteturas e os guias condicionais marcados
        ↓
IA lê plan.md
        ↓
IA lê tasks.md
        ↓
IA implementa tarefa por tarefa (go test -race a cada bloco com concorrência)
        ↓
IA registra decisões relevantes no build-logs.md da feature
        ↓
IA escreve testes e documenta em tests.md
        ↓
IA roda os portões Go (vet, lint, race, integração, govulncheck, build arm64)
        ↓
IA valida a entrega contra a spec e registra em review.md
        ↓
IA atualiza documentação se necessário
        ↓
Entrega revisada
```

O passo a passo detalhado de cada uma dessas etapas, com os prompts recomendados, está em `INSTRUCTIONS.md` e `prompts.md`.

---

## 7. Diferença entre os arquivos

Resumo rápido:

| Arquivo | Pergunta que responde | Finalidade |
|---|---|---|
| `ai-instructions.md` | Como a IA deve agir? | Define comportamento, limites e regras da IA |
| `architecture.md` | Como o sistema está organizado? | Define padrões técnicos e arquitetura |
| `spec.md` | O que precisa existir? | Define problema, regras, fluxos e aceite |
| `plan.md` | Como vamos construir? | Define estratégia técnica de implementação |
| `tasks.md` | Quais passos executar? | Define checklist objetiva de desenvolvimento |
| `build-logs.md` | O que aconteceu e por quê? | Registra decisões reais tomadas durante a implementação |
| `tests.md` | O que foi testado? | Documenta testes unitários/integração e sua cobertura sobre a spec |
| `review.md` | A entrega cumpre a spec? | Registra o histórico de validações da implementação contra a spec.md |
| `go/*.md` | Como fazer isso em Go do jeito certo? | Idioma, concorrência, testes, API, Lambda, desempenho |

Siglas de rastreabilidade da `spec.md`, citadas no código como `// NNN-<sigla><id>`:

| Sigla | Significado | Onde aparece no código |
|---|---|---|
| `RN` | Regra de negócio | Validação, condição, cálculo, bloqueio |
| `CA` | Critério de aceite | Ponto que atende o critério |
| `CC` | Requisito de concorrência | Onde a goroutine, o limite, o canal ou o lock é criado |
| `DP` | Requisito de desempenho/custo | Onde a otimização ou configuração de desempenho é aplicada |

---

## 8. Como evitar vibe coding

Vibe coding acontece quando a IA começa a gerar código com base em uma ideia vaga, sem contrato, sem plano e sem validação.

Para evitar isso:

- nunca peça "faz essa feature" sem uma spec;
- nunca aceite código sem entender o plano;
- nunca deixe a IA inventar regra de negócio;
- nunca permita grandes refatorações sem motivo;
- sempre que a IA improvisar, volte para a documentação;
- mantenha `spec.md`, `plan.md` e `tasks.md` como fonte de verdade;
- exija que toda decisão tomada durante a implementação esteja registrada no `build-logs.md` — se a IA decidiu algo e não registrou, é sinal de que codou sem freio;
- nunca aceite `go func()` que não venha de um `CCxx` ou de uma entrada no `build-logs.md` — goroutine improvisada é o *vibe coding* mais caro de Go (vaza, corre, derruba o banco);
- nunca aceite "é mais rápido" sem número: desempenho é `DPxx` medido.

A regra principal é:

> Se não está na spec, não deve ser implementado silenciosamente. E se foi decidido durante a implementação, precisa estar no build-logs.md.

---

## 9. Modelo mental do fluxo

Pense nos arquivos assim:

```txt
ai-instructions.md  → contrato de comportamento da IA
architecture.md     → mapa técnico do sistema
spec.md             → contrato funcional da feature
plan.md             → estratégia técnica da entrega
tasks.md            → execução controlada passo a passo
build-logs.md       → memória das decisões tomadas durante a entrega
tests.md            → evidência de que o comportamento foi testado
review.md           → memória das validações da entrega contra a spec
go/*.md             → o jeito Go de transformar tudo isso em código
```

A IA só deve codar depois que esses níveis estiverem claros, e deve manter o `build-logs.md`, o `tests.md` e o `review.md` atualizados enquanto codifica e valida — é o que permite ao desenvolvedor entender, depois, tudo o que aconteceu, o que foi testado e o que foi conferido contra a spec.

---

## 10. Execução autônoma de specs pendentes (opcional)

Quando o projeto acumula várias specs prontas em `.ai/specs/`, é possível executá-las em lote com a camada de automação da pasta `.claude/` (Claude Code):

- a skill **`/executar-specs-pendentes`** orquestra a fila: calcula a ordem pela numeração das pastas (`001`, `002`, … — seção 3.1), dispara um subagente por spec e, ao final de cada uma, confere o `review.md` — só move para `concluidos/` o que foi **"Aprovada"** sem ressalvas;
- o subagente **`executor-spec-sdd`** executa o ciclo SDD completo de uma única spec, em contexto zerado (sem memória das specs anteriores): leitura obrigatória na ordem da seção 5, decisões no `build-logs.md` da própria spec, `plan.md`/`tasks.md` a partir de `specs/template/` quando faltam, implementação tarefa por tarefa, testes, portões Go (vet, lint, race, govulncheck, build arm64), `review.md` e commit em branch própria (`feat/<slug>` ou `fix/<slug>`);
- guarda-corpos fixos: nunca `git push`, nunca PR, nunca commit na branch padrão, nunca editar os arquivos do framework, e as proibições do `ai-instructions.md` prevalecem sobre a autonomia.

O modo autônomo não substitui o fluxo das seções anteriores — ele o executa. A qualidade do resultado continua dependendo de specs bem escritas e de `architecture.md`/`ai-instructions.md` fiéis ao projeto (Fase 0). Detalhes de uso e revisão pós-rodada em `.claude/README.md`.

---

## 11. Conclusão

Spec Driven Development com IA não é burocracia. É uma forma de dar contexto, direção e limites para a IA.

O objetivo não é escrever documentação por escrever.

O objetivo é garantir que a IA desenvolva como um profissional trabalharia:

1. entendendo o problema;
2. respeitando a arquitetura;
3. planejando a solução;
4. quebrando em tarefas;
5. implementando com controle;
6. validando contra critérios objetivos;
7. registrando decisões importantes.

A IA deve ser usada como aceleradora de engenharia, não como piloto automático.
