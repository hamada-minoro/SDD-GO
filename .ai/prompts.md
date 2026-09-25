# Prompts — Spec Driven Development (SDD-GO)

> Biblioteca de prompts prontos para cada fase do fluxo descrito em `README.md` e `INSTRUCTIONS.md`, especializados para projetos Go (APIs e AWS Lambda em ARM64).
>
> Use os prompts na ordem das fases. Substitua qualquer trecho entre `[colchetes]` pelo conteúdo real da sua feature ou pelos caminhos reais dos arquivos no projeto.

---

## 0. Setup — Analisar o projeto e gerar `architecture.md`

Use uma única vez ao instalar o framework `.ai/` em um projeto novo ou já existente, antes de criar qualquer spec. Sem esse passo, `architecture.md` fica genérico e a IA não tem como respeitar os padrões reais do projeto durante o desenvolvimento.

```txt
Antes de criarmos qualquer feature, quero que você analise este projeto por
completo para gerar uma architecture.md robusta.

Leia primeiro .ai/README.md e os guias .ai/go/README.md, .ai/go/idiomatico.md
e .ai/go/concorrencia.md: eles definem o padrão SDD-GO que você vai comparar
com a realidade do código.

O arquivo a ser escrito é `.ai/architecture.md` (dentro da pasta `.ai/` do
projeto, não na raiz). Edite o arquivo que já existe nesse caminho — não
crie um architecture.md novo em outro lugar. Os trechos marcados como
"padrão SDD-GO" devem ser confirmados contra o código ou substituídos pelo
que o projeto de fato usa.

Faça uma varredura geral do repositório e identifique:

- o que o projeto faz (propósito, domínio, principais funcionalidades);
- cada módulo Go (go.mod), a diretiva `go`, o toolchain e as dependências
  principais; confira `go version` instalado;
- cada binário em cmd/ e o tipo de entrega (API HTTP, Lambda + gatilho,
  worker, CLI), onde roda e em qual arquitetura de CPU (arm64/x86_64);
- a estrutura de pastas e as camadas (handler/service/repository);
- o modelo de concorrência existente: onde há goroutines, canais, errgroup,
  pools, limites, locks, e se seguem as regras CONC-01 a CONC-11 de
  .ai/go/concorrencia.md (liste violações encontradas, sem corrigir);
- configuração de runtime (GOMAXPROCS, GOMEMLIMIT, timeouts do servidor,
  tamanho de pool, memória/timeout/concorrência das Lambdas);
- banco de dados (tabelas/itens, migrations, transações, locks,
  idempotência);
- autenticação e autorização (inclusive IAM);
- integrações AWS e externas, com garantias de entrega e limites;
- capacidade dos recursos compartilhados (conexões do banco/RDS Proxy,
  rate limits, concorrência reservada);
- build, artefato, IaC e deploy; dependências nativas (CGO, layers,
  imagens) que impediriam o build linux/arm64;
- ferramentas de qualidade disponíveis (gofmt, go vet, golangci-lint ou
  staticcheck, govulncheck) e o resultado de rodar os portões de
  .ai/go/testes.md uma vez (sem corrigir nada);
- scripts de testes, testes de integração e de carga.

Se esta pasta raiz contiver vários projetos (ex.: APIs, Lambdas, workers,
frontends, projetos complementares, cada um com ou sem repositório git
próprio), a documentação tem dois níveis obrigatórios:

- `.ai/architecture.md` vira o MAPA DO ECOSSISTEMA: tabela com todos os
  projetos da raiz (pasta, tipo de entrega, onde roda, arquitetura de CPU,
  gatilho, se tem repositório próprio, arquivo de arquitetura), como eles se
  comunicam (API, eventos, fila, banco compartilhado), contratos
  compartilhados, padrões Go do ecossistema e capacidade dos recursos
  compartilhados;
- para CADA projeto da raiz, sem exceção, crie
  `.ai/architecture-<nome-exato-da-pasta>.md` (ex.: `api-pedidos/` →
  `.ai/architecture-api-pedidos.md`) com stack, estrutura de pastas,
  camadas, modelo de concorrência, configuração de runtime, build, banco,
  testes e restrições daquele projeto, usando as seções do modelo
  `.ai/architecture.md`.

Documente a visão de ecossistema antes de detalhar cada projeto.

(Se eu pedir o setup de um único projeto novo adicionado à raiz, gere só o
`architecture-<pasta>.md` dele e atualize a tabela do mapa do ecossistema.)

Preencha também o `.ai/infraestrutura-testes.md` com o toolchain verificado,
os comandos de teste que funcionaram e as limitações encontradas (ex.: race
detector sem compilador C, portas ocupadas).

Depois da análise, me pergunte:

> Você quer que a próxima feature seja especificada dentro de um fluxo
> específico do ecossistema (ex.: só uma API, só uma Lambda, só o serviço X),
> ou prefere deixar em aberto para eu tratar como uma feature geral que pode
> tocar múltiplos projetos?

Não crie spec.md, plan.md ou tasks.md ainda — esta etapa é só de
mapeamento do projeto.

Ao final, gere o conteúdo completo de `.ai/architecture.md` (e de cada
`.ai/architecture-<projeto>.md`, se a raiz tiver vários projetos), organizado e
detalhado o suficiente para que qualquer IA consiga, no futuro, planejar e
implementar uma feature respeitando a arquitetura real do projeto.

Além disso, com base no que você encontrou, sugira melhorias para a seção
"Informações específicas do projeto" do `.ai/ai-instructions.md`: versão do
Go, comandos reais dos portões, ferramenta de IaC, onde roda cada entrega,
padrões de commit, regras de revisão, restrições de segurança, serviços que
nunca devem ser alterados sem validação humana, capacidade dos recursos
compartilhados, limites entre os projetos do ecossistema etc. Pergunte-me
quais dessas informações eu quero adicionar antes de gravá-las nessa seção
do mesmo arquivo, `.ai/ai-instructions.md` — não crie um arquivo novo,
edite o que já existe nesse caminho.
```

---

## 1. Iniciar uma feature do zero

Use quando ainda não existe nada — nem spec, nem plano, nem tarefas.

```txt
Vamos desenvolver uma nova funcionalidade seguindo Spec Driven Development
para Go (SDD-GO).

Quero que você atue como arquiteta de software Go e engenheira auxiliar,
especializada em APIs e AWS Lambda em ARM64.

Antes de qualquer código, vamos criar e revisar os arquivos:

1. spec.md
2. plan.md
3. tasks.md

Siga o fluxo da seção 1.1 de .ai/ai-instructions.md e leia os arquivos na
ordem da seção 2 desse mesmo arquivo.

Fluxo obrigatório:

0. crie a pasta da feature com o próximo número da sequência: veja o
   maior número usado em .ai/specs/ e em .ai/specs/concluidos/ e use o
   seguinte, com 3 dígitos (ex.: último 007-... → 008-nome-da-feature).
   Copie .ai/specs/template/ para .ai/specs/NNN-nome-da-feature/ — todos
   os arquivos desta feature (inclusive o build-logs.md) ficam ali;
0.1. usando o mapa do .ai/architecture.md, defina quais projetos a feature
   altera e preencha PRIMEIRO a tabela "Projetos e arquiteturas
   envolvidos" da spec.md (pasta do projeto + tipo de entrega + caminho do
   .ai/architecture-<projeto>.md + o que muda) e a lista "Guias Go
   aplicáveis" (api-http.md, lambda-aws.md, dados-dynamodb.md,
   dados-postgres.md, performance-e-custo.md). Leia
   somente essas arquiteturas e esses guias — não os de outros projetos.
   A mesma tabela deve aparecer no plan.md (com a ordem entre os projetos)
   e virar um item "Ler ..." por arquivo na seção "Preparação" do tasks.md;
1. primeiro me ajude a criar a spec.md. Na seção "Concorrência e
   paralelismo", faça-me as oito perguntas da seção 2 de
   .ai/go/concorrencia.md que o contexto não responder, e transforme as
   respostas em CCxx escritos em linguagem de negócio. Na seção
   "Desempenho, escala e custo", proponha DPxx mensuráveis e pergunte os
   números que faltarem;
2. depois revise criticamente a spec: trabalho independente sem CCxx?
   CCxx que ignora a capacidade downstream? estado compartilhado sem
   critério de consistência? falha parcial e idempotência definidas? DPxx
   mensuráveis?;
3. depois crie o plan.md, com o "Desenho de concorrência" (cada CCxx →
   padrão P1–P10, limite e origem, dono, término, cancelamento,
   falha, teste), o orçamento de prazos e o plano de medição dos DPxx;
4. depois crie o tasks.md, com uma tarefa de implementação e uma de teste
   por CCxx e os portões de .ai/go/testes.md na validação;
5. somente depois disso poderemos começar a implementação.

Não gere código até eu pedir explicitamente.

Contexto da feature:
[descreva aqui]
```

---

## 2. Prompt para iniciar desenvolvimento

Use na Fase 5, sempre que `spec.md`, `plan.md` e `tasks.md` já estiverem prontos (ou parcialmente prontos) e você quiser que a IA leia tudo, confirme entendimento e só então comece a implementar.

Substitua os caminhos entre `[colchetes]` pelos caminhos reais dos arquivos da feature no seu projeto.

```txt
Você vai atuar como engenheira de software Go auxiliar, seguindo
rigorosamente o Spec Driven Development deste projeto
(.ai/ai-instructions.md).

Antes de qualquer linha de código, leia os arquivos na ordem obrigatória da
seção 2 de .ai/ai-instructions.md, para a feature
.ai/specs/[NNN-nome-da-feature]/ — incluindo SOMENTE as arquiteturas e os
guias Go condicionais marcados na spec.md — e siga o fluxo da seção 1.2
desse arquivo.

Esses arquivos são a fonte de verdade do projeto. Você não deve implementar
nada que não esteja amparado por eles.

## Regras obrigatórias

1. Não comece a codar antes de ler todos os arquivos listados acima.
2. Não implemente nada que não esteja descrito na spec.md.
3. Não ignore ou contrarie o architecture.md sem justificar explicitamente
   e pedir validação antes de prosseguir.
4. Siga o plan.md como guia técnico. Se identificar que o plano está
   desatualizado ou incompleto, pare e proponha um ajuste antes de seguir.
5. Implemente seguindo a ordem do tasks.md, tarefa por tarefa, em blocos
   pequenos e revisáveis (tipos e regras puras → persistência → service →
   concorrência → borda HTTP/Lambda → wiring/deploy → desempenho →
   documentação). Testes acompanham cada bloco; documente cada teste em
   tests.md (RN/CA/CC/DP cobertos, cenário e status).
6. Toda goroutine, canal, limite ou lock vem do "Desenho de concorrência"
   do plan.md, com `// NNN-CCxx` no ponto de criação, e segue as regras
   CONC-01 a CONC-11. Rode `go test -race` do pacote ao fechar cada bloco
   com concorrência.
7. Não amplie o escopo da tarefa. Se identificar uma melhoria fora do
   escopo atual, registre a sugestão separadamente em vez de implementá-la.
8. Não invente regra de negócio. Se a spec.md tiver uma lacuna, pare e
   proponha uma decisão em vez de assumir algo silenciosamente.
9. Toda decisão técnica relevante tomada durante a implementação — escolha
   entre abordagens, desvio do plano, preenchimento de lacuna da spec,
   dependência nova, mudança no go.mod, concorrência não prevista, limite
   ou pool diferente do plano — deve ser registrada no build-logs.md
   da feature no momento em que é tomada, com: decisão, motivo, alternativas
   descartadas, impacto e se houve divergência em relação ao plan.md/spec.md.
10. Ao concluir cada bloco de implementação, explique brevemente o que foi
    feito antes de seguir para o próximo.
11. Ao final, rode os portões de .ai/go/testes.md e valide a entrega contra
    os critérios de aceite, as regras de negócio, os CCxx, os DPxx e o
    checklist de tasks.md.

## Antes de implementar

Depois de ler todos os arquivos, e antes de escrever qualquer código,
responda com:

- resumo do entendimento da feature;
- principais regras de negócio envolvidas;
- desenho de concorrência que será implementado (cada CCxx → padrão,
  limite, dono, cancelamento, teste);
- DPxx e como serão medidos;
- pacotes e arquivos que provavelmente serão alterados;
- ordem de implementação baseada no tasks.md;
- decisões já registradas no build-logs.md que sejam relevantes para o que
  vem a seguir (se o arquivo existir);
- riscos, dúvidas ou lacunas identificadas antes de começar.

Não implemente nada antes que eu confirme esse resumo.

Contexto adicional desta tarefa (se houver):
[descreva aqui qualquer informação extra, restrição de tempo, ou foco
específico desta rodada de implementação]
```

---

## 3. Continuar feature já em andamento

Use quando a implementação já começou e você só quer retomar o trabalho seguindo o mesmo rigor, sem repetir a fase de confirmação completa.

```txt
Continue a implementação desta feature seguindo Spec Driven Development.

Releia rapidamente:
1. .ai/specs/[NNN-nome-da-feature]/tasks.md
2. .ai/specs/[NNN-nome-da-feature]/build-logs.md (para retomar de onde as decisões anteriores pararam)
3. a seção "Desenho de concorrência" do plan.md, se a próxima tarefa tocar concorrência

Confirme qual é a próxima tarefa pendente no tasks.md e continue a partir
dela, respeitando spec.md, plan.md, architecture.md e os guias .ai/go/.

Regras:
- registre toda nova decisão relevante no build-logs.md da feature, com o motivo;
- não amplie o escopo sem autorização;
- rode `go test -race` do pacote ao concluir o bloco;
- ao concluir o bloco, explique brevemente o que foi feito e qual a
  próxima tarefa.
```

---

## 4. Validar contra a spec

Use na Fase 7, depois que a implementação (ou um bloco dela) estiver concluída.

```txt
Revise a implementação contra a spec.md.

Primeiro, rode os portões de .ai/go/testes.md (gofmt, go vet, lint,
go test -race, integração, govulncheck, build CGO_ENABLED=0 GOOS=linux
GOARCH=arm64, go mod tidy sem diff) e registre o resultado no tests.md.

Depois verifique:
- todos os critérios de aceite foram cumpridos?
- todas as regras de negócio foram implementadas?
- cada CCxx foi implementado como no "Desenho de concorrência", com limite,
  cancelamento e teste que prova?
- o código concorrente novo respeita CONC-01 a CONC-11
  (.ai/go/concorrencia.md, seção 5)?
- os DPxx foram medidos e atendidos?
- os casos de erro foram tratados e mapeados na borda?
- as permissões (inclusive IAM de privilégio mínimo) estão corretas?
- existe algo fora do escopo?
- a arquitetura e o idioma Go (.ai/go/idiomatico.md) foram respeitados?
- houve mudança não registrada no go.mod ou dependência nova sem
  build-logs?

Liste o que está concluído, o que ficou pendente e o que precisa de atenção.

Registre o resultado desta revisão em `review.md`, dentro da pasta da
feature (`.ai/specs/[NNN-nome-da-feature]/review.md`). Se o arquivo ainda não
existir, crie-o. Cada execução desta validação deve gerar uma nova entrada
em `review.md`, com data e o que foi revisado — não sobrescreva entradas
anteriores. Cada entrada deve seguir o formato de
.ai/specs/template/review.md e conter:

- data da revisão;
- critérios de aceite cumpridos e não cumpridos;
- regras de negócio cobertas e não cobertas;
- situação de cada CCxx e DPxx;
- resultado dos portões Go;
- divergências encontradas em relação à spec.md;
- pendências e itens que precisam de atenção;
- conclusão: entrega aprovada, aprovada com pendências, ou reprovada.
  "Aprovada" exige todos os portões passando.
```

---

## 5. Atualizar documentação

Use na Fase 8, sempre que o que foi implementado divergir do que estava documentado.

```txt
Atualize a documentação da feature com base no que foi realmente implementado.

Verifique se spec.md, plan.md (inclusive o "Desenho de concorrência") e
tasks.md continuam coerentes com o código final.

Se algo mudou durante o desenvolvimento, registre a decisão no build-logs.md da
feature e explique o motivo.

Se a entrega produziu medições de desempenho representativas, proponha
atualizar a "Linha de base de desempenho" do architecture-<projeto>.md.
```

---

## 6. Revisão de concorrência (auditoria)

Use a qualquer momento para auditar código concorrente, dentro de uma feature (antes do review) ou como análise de um pacote existente. Não altera código: produz achados.

```txt
Faça uma auditoria de concorrência em [pacote(s) ou arquivos], usando
.ai/go/concorrencia.md como referência.

Para cada `go`, errgroup, WaitGroup, canal, select, mutex, atomic,
sync.Once/OnceValue, singleflight e semáforo encontrado, responda:

- qual CCxx/decisão do build-logs o justifica (ou "nenhum");
- quem é o dono, quando termina e como é cancelado;
- qual é o limite e de onde ele vem;
- quem fecha cada canal e se todo envio pode ser cancelado;
- se erros e panics são coletados;
- se há estado compartilhado sem sincronização;
- se algo sobrevive ao retorno de uma Lambda;
- se há lock segurado durante I/O.

Rode `go test -race -count=20 -cpu=1,2,4` nos pacotes e, se houver
goleak, confira vazamentos.

Entregue uma tabela de achados (arquivo:linha, regra CONC violada,
severidade, correção sugerida) e os testes que faltam para provar cada
comportamento. Não implemente as correções: se forem feitas, entram por
spec ou como pendência da spec em andamento.
```

---

## 7. Investigação de desempenho

Use quando um `DPxx` não foi atingido ou para estabelecer uma linha de base. Segue `.ai/go/performance-e-custo.md`.

```txt
Investigue o desempenho de [endpoint / função Lambda / pacote] em relação
a [DPxx ou objetivo], seguindo .ai/go/performance-e-custo.md.

1. Descreva a condição de medição (carga, dados, limites de CPU/memória,
   arquitetura, versão do Go) e meça a linha de base com a ferramenta
   adequada (benchmark com -benchmem e -count=10, carga, ou Lambda Power
   Tuning).
2. Colete perfis (CPU, heap, goroutine, mutex/block) e, se for cauda de
   latência, trace.
3. Meça também o downstream (CPU do banco, throttling, conexões): o
   gargalo pode não estar no Go.
4. Liste as hipóteses em ordem de custo/benefício (round-trips de I/O,
   concorrência de I/O, alocações, JSON, GC, PGO).
5. Para cada mudança proposta, mostre o antes/depois com benchstat ou com
   a carga repetida, nas mesmas condições.

Registre tudo no tests.md e as decisões no build-logs.md da spec em
andamento. Não mantenha nenhuma otimização sem ganho medido.
```

---

## 8. Portar um serviço existente para Go

Use quando uma API ou Lambda existente (Node, Python, Java...) vai ganhar uma implementação em Go. Esse foi o caminho do estudo que originou este framework.

```txt
Vamos portar [serviço/função] de [linguagem] para Go seguindo SDD-GO.

Antes das specs:
1. Mapeie o comportamento observável atual: contrato (rotas/eventos),
   status, códigos e mensagens de erro, regras de negócio, efeitos no
   banco, idempotência e concorrência. O comportamento REAL em execução
   é o contrato; onde a documentação divergir dele, registre a divergência
   e me pergunte qual vale.
2. Proponha a divisão em specs numeradas (fundação → recursos por domínio
   → paridade → medição), cada uma com a tabela de projetos e os guias Go.

Nas specs:
- cada regra/mensagem do serviço original vira RN/CA com a mesma
  semântica;
- inclua um critério de aceite de PARIDADE: roteiro automatizado que roda
  os mesmos casos nas duas implementações e compara status, código e
  corpo;
- identifique onde o modelo do serviço original (event loop, processos,
  threads) vira goroutines, e escreva os CCxx correspondentes;
- inclua DPxx comparativos (vazão, p99, CPU/req, memória, custo) medidos
  nas MESMAS condições para as duas implementações, conforme a metodologia
  de .ai/go/performance-e-custo.md.

Não gere código até eu aprovar a divisão em specs.
```
