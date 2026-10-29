# Instruções de Operação — Spec Driven Development

> Este arquivo é direcionado ao **desenvolvedor humano**: como operar o fluxo de Spec Driven Development descrito em `README.md`, fase por fase, no dia a dia.
>
> Para o "porquê" e os conceitos por trás do fluxo, veja `README.md`.
> Para os prompts prontos de cada fase abaixo, veja `prompts.md`.

---

## 0. Fase 0 — Setup do projeto

Antes de criar qualquer feature, a IA precisa entender o projeto real onde o framework `.ai/` foi instalado — não basta copiar a pasta e deixar `architecture.md` genérico.

Use o prompt **"0. Setup — Analisar o projeto e gerar architecture.md"** em `prompts.md`.

Nesta fase a IA deve:

- mapear o projeto por completo: propósito, stack, estrutura de pastas, padrões de código, backend, frontend, banco de dados, autenticação, integrações, scripts de build/deploy/testes;
- se a raiz contiver vários projetos (APIs, frontends, microsserviços, lambdas, projetos complementares), transformar o `architecture.md` no mapa do ecossistema e criar **um `architecture-<pasta-do-projeto>.md` para cada projeto da raiz**, sem exceção (ver `README.md`, seção 3.2);
- perguntar ao desenvolvedor se a próxima feature deve ser especificada dentro de um fluxo específico do ecossistema (ex.: só backend, só um serviço) ou tratada como feature geral, em aberto;
- gerar o conteúdo completo e robusto de `architecture.md` com base no que encontrou;
- sugerir, e perguntar ao desenvolvedor antes de gravar, informações específicas do projeto para enriquecer o `ai-instructions.md` (convenções, ferramentas obrigatórias, restrições de segurança, limites entre projetos do ecossistema, etc.).

Específico de Go, a Fase 0 também:

- verifica o toolchain real (`go version`, diretiva `go` de cada `go.mod`, golangci-lint/staticcheck, govulncheck) e registra no `infraestrutura-testes.md`;
- mapeia cada binário (`cmd/*`) e o tipo de entrega (API HTTP, Lambda e gatilho, worker), onde roda e em qual arquitetura de CPU;
- identifica o modelo de concorrência já existente no código (goroutines, pools, limites, locks) e o registra em "Modelo de concorrência do projeto" do `architecture-<projeto>.md`;
- levanta a **capacidade dos recursos compartilhados** (conexões do banco, rate limits, concorrência reservada), que vira insumo dos limites de todas as specs;
- roda os portões de `.ai/go/testes.md` uma vez para saber o estado atual (lint e race com problemas preexistentes viram limitação conhecida, não surpresa na primeira spec);
- aponta dependências nativas (CGO, layers, imagens) que impediriam o build `linux/arm64`.

Esta fase só precisa ser executada uma vez por projeto, ou sempre que a arquitetura mudar de forma relevante. Em raiz com vários projetos, rode-a de novo, focada no projeto novo, sempre que um projeto for adicionado à raiz. É o que garante que as fases seguintes — spec, plano, tarefas e implementação — estejam ancoradas na realidade do projeto, e não em um template vazio.

---

## 1. Fase 1 — Criação da especificação

A primeira etapa é transformar uma ideia em uma `spec.md`.

Nesta fase, a IA deve ajudar a organizar a funcionalidade, mas não deve implementar código.

Antes de escrever a spec, crie a pasta da feature com o **próximo número da sequência**: veja o maior número usado em `.ai/specs/` e em `.ai/specs/concluidos/` e use o seguinte, com 3 dígitos (ex.: último `007-...` → nova pasta `008-nome-da-feature`). Copie `.ai/specs/template/` para essa pasta; ela já traz todos os arquivos da feature, inclusive o `build-logs.md`. O número define a ordem de execução da fila (detalhes em `README.md`, seção 3.1).

A **primeira** seção a preencher na `spec.md` é "Projetos e arquiteturas envolvidos": com base no mapa do `architecture.md`, liste cada projeto que a feature altera e o caminho do `architecture-<projeto>.md` dele. Essa tabela é repetida no `plan.md` (com a ordem entre projetos) e vira itens de leitura na "Preparação" do `tasks.md`. É ela que limita o que a IA lê antes de executar: o mapa mais esses arquivos, nada além (`README.md`, seção 3.2).

Logo depois, marque em "Guias Go aplicáveis" quais guias condicionais entram (`api-http.md`, `lambda-aws.md`, `dados-dynamodb.md`, `dados-postgres.md`, `performance-e-custo.md`, `validacao-ambiente.md`). Marque `validacao-ambiente.md` quando a entrega depender do que só a stack publicada em teste prova (IAM, gatilho real, configuração, empacotamento); o roteiro fica no `plano-validacao-ambiente.md` da spec.

Use o prompt **"1. Iniciar uma feature do zero"** em `prompts.md`.

A IA deve devolver uma especificação organizada e também apontar dúvidas, lacunas e riscos. Se alguma dúvida mudar uma regra de negócio (inclusive falha parcial, idempotência e ordem), ela para depois da spec e pergunta antes de fazer o plano, porque o desenho de concorrência e os prazos dependem da resposta. Dúvidas que não mudam regra viram premissas na spec.

Duas seções são o coração do SDD-GO e **nunca ficam vazias**:

- **"Concorrência e paralelismo"**: a IA faz as oito perguntas da seção 2 de `.ai/go/concorrencia.md` (trabalho independente, ordem, estado compartilhado, capacidade downstream, falha parcial, prazo, idempotência, volume) e transforma as respostas em `CCxx`. É aqui que se decide, ainda em linguagem de negócio, onde as goroutines vão gerar valor.
- **"Desempenho, escala e custo"**: requisitos `DPxx` com número e forma de medir. Sem número conhecido, a spec pede uma medição de linha de base.

---

## 2. Fase 2 — Revisão da especificação

Depois de criar a `spec.md`, a IA deve revisá-la criticamente antes de gerar o plano.

Essa revisão já faz parte do mesmo prompt **"1. Iniciar uma feature do zero"** em `prompts.md`: ele instrui a IA a primeiro ajudar a criar a spec e só depois revisá-la criticamente, antes de avançar para o plano.

A IA deve atuar como revisora técnica e funcional. Se a spec estiver incompleta, ela deve propor melhorias antes de avançar.

Na revisão, a IA confere especialmente:

- se algum trabalho independente ficou sem `CCxx` (oportunidade de goroutine desperdiçada);
- se algum `CCxx` ignora a capacidade downstream (goroutines sem limite derrubam o banco);
- se estado compartilhado sob concorrência tem critério de aceite de **consistência** (invariante verificável);
- se a falha parcial e a idempotência estão definidas (obrigatório para SQS/streams);
- se os `DPxx` são mensuráveis.

---

## 3. Fase 3 — Criação do plano técnico

Com a spec validada, a IA deve criar o `plan.md`.

Esta etapa também é coberta pelo prompt **"1. Iniciar uma feature do zero"** em `prompts.md`, na sequência da revisão da spec.

O plano deve respeitar a arquitetura existente. A IA não deve propor uma abordagem incompatível com o projeto sem explicar claramente o motivo.

O item mais importante do plano em Go é o **"Desenho de concorrência"**: cada `CCxx` vira uma linha com o padrão do catálogo de `.ai/go/concorrencia.md` (errgroup, worker pool, pipeline, particionamento por chave, semáforo, singleflight), o limite e de onde ele vem (Lei de Little, capacidade downstream), quem é o dono da goroutine, como ela termina, como é cancelada, o que acontece na falha e qual teste prova. O plano também distribui o prazo total entre as etapas ("Contexto, prazos e timeouts") e, se houver `DPxx`, define como cada um será medido.

---

## 4. Fase 4 — Criação das tarefas

Depois do `plan.md`, a IA deve quebrar a implementação em tarefas.

Esta etapa fecha o fluxo do prompt **"1. Iniciar uma feature do zero"** em `prompts.md`: spec → revisão → plano → tarefas, tudo na mesma conversa, sem gerar código antes do fim.

O objetivo do `tasks.md` é evitar que a IA tente implementar tudo de uma vez.

---

## 5. Fase 5 — Preparação para implementação

Antes de desenvolver, a IA deve confirmar que leu os documentos na ordem correta e devolver um resumo do entendimento, antes de escrever qualquer código.

Use o prompt **"2. Prompt para iniciar desenvolvimento"** em `prompts.md`.

Essa etapa é importante para garantir que a IA entendeu o escopo antes de codar.

---

## 6. Fase 6 — Implementação controlada

A implementação deve seguir o `tasks.md`, tarefa por tarefa.

As regras de implementação já estão incluídas no mesmo prompt **"2. Prompt para iniciar desenvolvimento"** em `prompts.md`: depois que a IA confirma o entendimento, ela segue para a implementação em blocos pequenos, sem precisar de um prompt separado.

Se a implementação já tiver começado e você só quiser retomar de onde parou, use o prompt **"3. Continuar feature já em andamento"** em vez de repetir a confirmação completa.

A IA deve evitar grandes alterações de uma vez. Sempre que tomar uma decisão que não estava explícita no `plan.md` ou no `tasks.md` — escolher entre abordagens, desviar do plano, preencher uma lacuna da spec — a IA deve parar e adicionar uma entrada no `build-logs.md` da feature (`.ai/specs/NNN-nome-da-feature/build-logs.md`) antes de continuar. Isso vale mesmo para decisões pequenas, se elas não forem óbvias só de olhar o código depois.

O ideal é implementar em blocos, na ordem de dentro para fora:

1. tipos, erros de domínio e funções puras de parse/validação (+ testes table-driven);
2. persistência / repositórios (+ integração);
3. service com a regra de negócio (+ testes com fakes);
4. concorrência conforme o desenho do plan (+ race, goleak, synctest);
5. borda HTTP ou Lambda (+ httptest / eventos de `testdata/`);
6. wiring no `cmd/`, configuração, IaC arm64 e observabilidade;
7. medição de desempenho, se houver `DPxx`;
8. documentação.

Nem toda feature exige todos esses blocos. Testes acompanham cada bloco, não ficam para o fim: `go test -race` do pacote roda ao fechar cada bloco que tenha concorrência.

Cada teste escrito deve ser documentado em `tests.md`, dentro da pasta da feature, indicando o que cobre (`RN`, `CA`, `CC` ou `DP`), o cenário testado e o status (passou/falhou/pendente). Esse arquivo é o que a fase de validação (Fase 7) usa para confirmar que a cobertura de testes é real, em vez de assumida.

---

## 7. Fase 7 — Validação contra a spec

Após implementar, a IA deve revisar o resultado contra os critérios de aceite.

Use o prompt **"4. Validar contra a spec"** em `prompts.md`.

A entrega só deve ser considerada finalizada quando os critérios de aceite forem atendidos.

A IA deve cruzar essa validação com o `tests.md`: se um critério de aceite, regra de negócio ou requisito de concorrência não tiver teste correspondente, isso deve aparecer como pendência na revisão, não ser ignorado.

Antes da revisão, rodam os portões de `.ai/go/testes.md` (formatação, vet, lint, race, integração, govulncheck, build arm64, `go mod tidy`). Portão falhando impede a conclusão "Aprovada". A revisão também percorre as regras CONC-01 a CONC-11 de `.ai/go/concorrencia.md` sobre todo código concorrente novo.

O resultado desta validação deve ser registrado em `review.md`, dentro da pasta da feature (`.ai/specs/NNN-nome-da-feature/review.md`), com uma nova entrada a cada execução da revisão — sem sobrescrever as anteriores. É o que dá ao desenvolvedor um histórico de revisões cruzando implementação e spec, sem precisar repetir a análise do zero a cada rodada.

---

## 8. Fase 8 — Atualização da documentação

Se durante a implementação houver mudança de decisão, regra ou comportamento, a documentação precisa ser atualizada.

Arquivos que podem precisar de atualização:

```txt
spec.md
plan.md
tasks.md
architecture.md
build-logs.md (da feature)
README.md
CHANGELOG.md
API.md
```

A IA deve atualizar a documentação quando:

- uma regra de negócio mudar;
- um endpoint for criado ou alterado;
- uma tabela nova for adicionada;
- uma decisão técnica relevante for tomada;
- houver mudança no fluxo da funcionalidade;
- alguma limitação importante for descoberta.

Use o prompt **"5. Atualizar documentação"** em `prompts.md`.

---

## 9. Regras obrigatórias para a IA

Estas regras devem ser seguidas sempre que a IA for usada para desenvolver.

### 9.1 Nunca começar pelo código

A IA não deve gerar código antes de entender a spec, o plano e as tarefas.

### 9.2 Sempre respeitar a arquitetura

A IA deve seguir o `architecture.md` como fonte de verdade técnica.

Se for necessário fugir da arquitetura, ela deve justificar e pedir validação humana.

### 9.3 Não inventar regra de negócio

Se uma regra não estiver na `spec.md`, a IA não deve inventar silenciosamente.

Ela deve registrar a dúvida e propor uma decisão.

### 9.4 Não ampliar escopo sem autorização

A IA não deve transformar uma tarefa simples em uma reestruturação grande.

Se identificar oportunidade de melhoria, deve sugerir separadamente.

### 9.5 Implementar em blocos pequenos

A IA deve evitar alterações grandes e difíceis de revisar.

Cada bloco deve ter objetivo claro.

### 9.6 Validar antes de finalizar

Toda entrega deve ser conferida contra os critérios de aceite.

### 9.7 Atualizar documentação quando necessário

Se o código final divergir do plano, a documentação precisa ser atualizada.

### 9.8 Registrar toda decisão relevante no build-logs.md

A IA não deve codar sem freio. Toda decisão técnica que não estava 100% explícita no `plan.md` ou no `tasks.md` — escolha entre abordagens, desvio de plano, preenchimento de lacuna da spec, introdução de dependência nova — deve ser registrada no `build-logs.md` da própria feature com o motivo, no momento em que é tomada.

Sem esse registro, o desenvolvedor não tem como saber o que foi decidido e por quê depois que a implementação termina.

### 9.9 Goroutine só com desenho

Toda goroutine, canal, limite ou lock de uma feature vem de um `CCxx` da spec e de uma linha do "Desenho de concorrência" do plan, com `// NNN-CCxx` no código. Se a implementação revelar necessidade de concorrência não prevista, a IA para, registra no `build-logs.md` e atualiza o plan antes de seguir.

### 9.10 Portões Go antes de concluir

Nenhuma entrega é "Aprovada" com `gofmt`, `go vet`, lint, `go test -race`, integração, `govulncheck`, build `linux/arm64` ou `go mod tidy` falhando (`.ai/go/testes.md`).

### 9.11 Desempenho com número

Requisito de desempenho sem número não é requisito, e otimização sem medição antes/depois não entra.

---

## 10. Checklist de qualidade antes de codar

Antes da implementação, confirme:

```md
- [ ] A pasta da feature segue a numeração sequencial (NNN-nome-da-feature)
- [ ] A feature tem uma spec.md clara
- [ ] As regras de negócio estão documentadas
- [ ] Existem critérios de aceite objetivos
- [ ] O fora de escopo está definido
- [ ] O plan.md respeita a arquitetura
- [ ] O tasks.md está quebrado em tarefas pequenas
- [ ] A IA leu ai-instructions.md
- [ ] A IA leu architecture.md
- [ ] A spec, o plan e o tasks deixam explícitos os projetos e arquiteturas envolvidos (tabela "Projetos e arquiteturas envolvidos")
- [ ] A IA leu o architecture-<projeto>.md de cada projeto da tabela, e não leu os de projetos fora dela
- [ ] A IA leu infraestrutura-testes.md
- [ ] A IA leu os guias Go obrigatórios (idiomatico, concorrencia, testes) e só os condicionais marcados na spec
- [ ] A seção "Concorrência e paralelismo" responde às oito perguntas e tem CCxx (ou "não se aplica" com motivo)
- [ ] Cada CCxx tem linha no "Desenho de concorrência" do plan, com limite, dono, término, cancelamento e teste
- [ ] Os limites de concorrência respeitam a capacidade downstream documentada no architecture.md
- [ ] Os DPxx têm número e plano de medição (ou "não se aplica" com motivo)
- [ ] Estado compartilhado sob concorrência tem critério de aceite de consistência
- [ ] Lambda: falha parcial, idempotência, margem de prazo e arm64 definidos
- [ ] A IA entendeu a ordem de implementação
```

Se qualquer item estiver fraco, melhore os documentos antes de codar.

---

## 11. Checklist de qualidade depois de codar

Depois da implementação, confirme:

```md
- [ ] Todas as tarefas do tasks.md foram concluídas
- [ ] Todos os critérios de aceite da spec.md foram cumpridos
- [ ] As regras de negócio foram respeitadas
- [ ] As permissões foram implementadas corretamente
- [ ] Os casos de erro foram tratados e mapeados na borda (HTTP/Lambda)
- [ ] A entrada externa é validada (e tem fuzz, quando for parser)
- [ ] Cada CCxx foi implementado como no desenho, com `// NNN-CCxx` e teste que prova
- [ ] Toda goroutine nova tem dono, término, cancelamento e limite; nenhuma sobrevive ao retorno da Lambda
- [ ] Os DPxx foram medidos e o resultado está em tests.md
- [ ] Portões Go passaram: gofmt, go vet, lint, go test -race, integração, govulncheck, build linux/arm64, go mod tidy
- [ ] Nenhuma mudança não registrada nas diretivas `go`/`toolchain` do go.mod; dependências novas registradas no build-logs
- [ ] Os testes estão documentados em tests.md, cobrindo as regras de negócio, critérios de aceite e requisitos de concorrência relevantes
- [ ] A documentação foi atualizada quando necessário
- [ ] Não houve alteração fora do escopo sem justificativa
- [ ] O build-logs.md da feature contém as decisões relevantes tomadas durante a implementação
- [ ] O review.md contém uma entrada com o resultado da validação contra a spec.md
- [ ] Se a feature mudou a infraestrutura de testes, o infraestrutura-testes.md foi atualizado
- [ ] NENHUM commit tem `Co-Authored-By:` listando IA, e nenhum commit, PR, código ou comentário traz a IA como autora ("Generated with ...", "🤖", nome de modelo)
- [ ] Comentários de rastreabilidade têm só o ID, sem descrição (`// 007-RN30`, `// 007-CC02`, `// 007-RN42, 007-CA10`), e nomes, logs, commits e branches não citam o SDD (ver "Comentários no código" em ai-instructions.md)
```

---

## 12. Vibe coding e modelo mental — lembrete

Dois pontos do `README.md` valem ser revisados sempre que o fluxo parecer estar sendo abandonado:

- **Como evitar vibe coding** (`README.md`, seção 8): a regra central é que nada deve ser implementado silenciosamente fora da spec, e toda decisão tomada durante a implementação precisa estar no `build-logs.md`.
- **Modelo mental do fluxo** (`README.md`, seção 9): cada arquivo representa uma camada de contrato — comportamento da IA, arquitetura, spec, plano, execução e memória de decisões — e a IA só deve codar depois que essas camadas estiverem claras.

Se você, como desenvolvedor, perceber que a IA está pulando etapas, gerando código sem plano ou inventando regras, volte para esses dois pontos antes de continuar.

---

## 13. Execução autônoma de specs pendentes (opcional)

Todas as fases acima podem ser executadas em lote, sem acompanhamento em tempo real, quando houver várias specs prontas acumuladas em `.ai/specs/`.

1. Garanta que a Fase 0 foi executada (`architecture.md` e `ai-instructions.md` fiéis ao projeto) e que cada spec pendente tem ao menos um `spec.md` completo (o agente cria `plan.md`/`tasks.md` a partir de `.ai/specs/template/` quando faltam).
2. Abra o Claude Code na raiz do projeto e invoque `/executar-specs-pendentes`.
3. O loop processa uma spec por vez, na ordem numérica das pastas (`001`, `002`, …), em subagente com contexto zerado, cumprindo o ciclo completo (leitura obrigatória, incluindo os guias Go → plan/tasks → implementação → testes → portões Go → review → commit em branch própria) e move as aprovadas para `.ai/specs/concluidos/`.
4. Revise depois: relatório final da rodada, `review.md`/`tests.md` de cada spec, entradas do `build-logs.md` de cada spec (especialmente `⚠️ ÁREA SENSÍVEL:`) e as branches criadas. Push e PR são sempre seus, manuais.

Detalhes completos em `.claude/README.md`.
