# Agente desenvolvedor SDD — como usar

> Camada de automação do framework SDD para o Claude Code. Ela processa as
> specs pendentes de `.ai/specs/` em loop, uma por vez, com contexto zerado
> entre specs, seguindo integralmente o `.ai/ai-instructions.md`.
>
> Pré-requisito: a pasta `.ai/` instalada e a Fase 0 (setup) já executada —
> `architecture.md` e `ai-instructions.md` preenchidos com a realidade do
> projeto. Sem isso, o agente não tem limites reais para respeitar.

## O que existe nesta pasta

```txt
.claude/
├── README.md                                     # este arquivo
├── agents/
│   └── executor-spec-sdd.md                      # subagente: executa o ciclo SDD completo de UMA spec
└── skills/
    └── executar-specs-pendentes/
        ├── SKILL.md                              # skill orquestradora: o loop (/executar-specs-pendentes)
        └── scripts/
            ├── fila.sh                           # calcula a fila de pendências (determinístico)
            └── fila.test.sh                      # teste automatizado do fila.sh
```

Duas camadas, de propósito:

- **Orquestradora** (`SKILL.md`) — gerencia a fila, dispara um subagente por
  spec, confere o resultado e move as aprovadas para `concluidos/`. Não
  implementa nada diretamente.
- **Executor** (`executor-spec-sdd.md`) — um subagente **novo por spec**
  (nasce sem memória da conversa nem das specs anteriores). É ele quem lê os
  documentos na ordem obrigatória, cria `plan.md`/`tasks.md` quando faltam,
  implementa, testa, documenta e commita.

## Uso básico

1. Abra o Claude Code **na raiz do projeto** (os caminhos da automação são
   relativos à raiz, onde ficam `.ai/` e `.claude/`).
2. Invoque a skill:

   ```txt
   /executar-specs-pendentes
   ```

3. Deixe rodar. O loop processa as specs **na ordem numérica das pastas**
   (`001-...`, `002-...`, …, empate por ordem alfabética) e **encerra
   sozinho** quando não sobrar pendência, apresentando o relatório final.

### Numeração das specs = ordem de execução

A fila segue a mesma convenção de `.ai/ai-instructions.md` (seção 3): cada pasta de
spec se chama `NNN-nome-da-feature`, e o número é atribuído na criação como
**o maior número já usado em `.ai/specs/` e `.ai/specs/concluidos/` + 1**.
Quem quer que uma feature rode antes de outra cria a spec antes (número
menor); a automação nunca reordena por outro critério.

Pastas com `spec.md` mas **sem** prefixo numérico ficam fora da fila: o
`fila.sh` avisa em stderr e o relatório final as lista para você renomear.

Não precisa aprovar nada durante a rodada — o modo é autônomo por decisão de
spec. Sua revisão acontece **depois**, sobre o resultado acumulado.

### Ver a fila sem executar nada

```bash
bash .claude/skills/executar-specs-pendentes/scripts/fila.sh .ai/specs
```

Saída: `<número><TAB><pasta da spec>`, já na ordem em que o loop vai
processar (ex.: `003	003-exportar-relatorio`). Pastas sem numeração
aparecem em stderr como `ignorada (sem numeração): <pasta>`. Útil antes de disparar uma rodada, para saber o que vem pela
frente.

## O que o agente faz com cada spec

Para cada spec pendente, o executor (em contexto limpo):

1. Lê os arquivos na ordem obrigatória do `.ai/ai-instructions.md` (seção 2):
   os globais (incluindo os guias Go `idiomatico`, `concorrencia` e
   `testes`), a `spec.md`, **somente** as arquiteturas e os guias
   condicionais marcados nela, e os demais arquivos da spec. Se faltar
   alguma arquitetura, a spec sai reprovada sem código.
2. Confere se o(s) repositório(s) tocados estão com working tree limpo —
   se houver mudança não commitada de outra origem, **não toca em nada**,
   registra e marca a spec como reprovada. Confere também se o `go version`
   instalado atende ao `go.mod` (roda tudo com `GOTOOLCHAIN=local`).
3. Cria `plan.md`/`tasks.md` a partir de `.ai/specs/template/` quando não
   existirem (sempre com o "Desenho de concorrência"); reaproveita quando
   existirem.
4. Cria uma branch `feat/<slug>` ou `fix/<slug>` a partir da branch padrão
   de cada repositório tocado e implementa tarefa por tarefa.
5. Escreve os testes exigidos (inclusive os de concorrência de cada
   `CCxx`), roda os portões Go (`gofmt`, `go vet`, lint, `go test -race`,
   integração, `govulncheck`, build `linux/arm64`, `go mod tidy`) e
   documenta tudo em `tests.md`. "Aprovada" exige todos os portões verdes.
6. Valida contra os critérios de aceite e registra nova entrada em
   `review.md`; decisões não óbvias vão para o `build-logs.md` da própria
   spec (`.ai/specs/<spec>/build-logs.md`).
7. Commita na branch da spec. O nome da branch é o nome da pasta sem o
   número (`007-correcao-login` → `fix/correcao-login`), e a mensagem
   descreve a mudança sem citar a spec (as regras do `ai-instructions.md`
   proíbem referências ao SDD em commits; só os comentários de regra de
   negócio usam o padrão `NNN-RNxx` / `NNN-CAxx`). A ligação spec → branch fica
   no relatório final.

A orquestradora então lê o `review.md` da spec:

- Conclusão **"Aprovada"** → a pasta vai para `.ai/specs/concluidos/`.
- **"Aprovada com pendências"** ou **"Reprovada"** → a pasta fica em
  `.ai/specs/` com o motivo documentado, e o loop segue para a próxima.

Cada spec recebe **uma única tentativa por rodada** — as que falharem só são
retentadas quando você disparar uma nova rodada.

## Garantias de segurança (o que o agente NUNCA faz)

- **Nunca dá `git push` nem abre/mescla PR.** Todo envio para o remoto é
  manual, seu, depois de revisar as branches.
- **NENHUM `Co-Authored-By:`. NENHUMA IA é listada como
  `Co-Authored-By:`**, nem "Generated with ...", "🤖" ou nome de modelo, em
  nenhum commit. O autor é só o do seu `git config`. O executor confere o
  último commit antes de encerrar, e a orquestradora confere as branches da
  rodada.
- **Nunca commita na branch padrão** (`main`/`master`) — sempre em branch
  própria por spec.
- **Nunca edita os arquivos do framework** (`AGENTS.md`, `CLAUDE.md`,
  `ai-instructions.md`, `architecture*.md`, `README.md`, `INSTRUCTIONS.md`,
  `prompts.md`, `go/`, `specs/template/`), nunca cria specs novas e nunca
  renomeia ou renumera pastas de spec.
- **Nunca altera as diretivas `go`/`toolchain` do `go.mod`** como efeito
  colateral nem introduz CGO/dependência nativa sem entrada no
  `build-logs.md`.
- **Nunca implementa o que o `ai-instructions.md` proíbe** (a lista de
  "o que não pode ser aprovado" da seção "Informações específicas do
  projeto") — se uma spec pedir, essa parte não é feita, o conflito é
  documentado e a spec sai como reprovada.
- Specs que tocam **áreas sensíveis** (a lista de "nunca alterar sem
  validação humana" do `ai-instructions.md`) são implementadas, mas ganham
  entrada `⚠️ ÁREA SENSÍVEL:` no `build-logs.md` da spec para você revisar com
  atenção redobrada.

## Como revisar depois de uma rodada

1. **Relatório final da skill** — resumo de aprovadas/reprovadas, branches
   criadas e alertas de área sensível.
2. **`.ai/specs/concluidos/<spec>/`** — `review.md` (validação contra a
   spec) e `tests.md` (o que foi testado) de cada spec aprovada.
3. **`build-logs.md` de cada spec** — o porquê de cada decisão tomada;
   procure entradas `⚠️ ÁREA SENSÍVEL:` primeiro:

   ```bash
   grep -rl "ÁREA SENSÍVEL" .ai/specs/*/build-logs.md .ai/specs/concluidos/*/build-logs.md
   ```
4. **Branches criadas** — em cada repositório tocado:

   ```bash
   git branch --list 'feat/*' 'fix/*'   # branches criadas pelo agente
   git log main..feat/<slug> --stat     # o que a branch mudou
   ```

5. Aprovou? Você mesmo faz o push e abre o PR.

## Avisos

- **Não rode duas rodadas ao mesmo tempo** — não há lock; o estado vive no
  sistema de arquivos.
- Uma rodada completa implementa e commita **todas** as specs pendentes de
  forma autônoma. Se quiser algo menor, mova temporariamente para fora de
  `.ai/specs/` as specs que não quer processar ainda (ou peça uma spec
  específica numa conversa normal, fora da skill).
- A rodada pode ser interrompida sem perder progresso: specs já aprovadas
  ficam em `concluidos/` com seus commits nas branches; a próxima rodada
  recalcula a fila do zero a partir do sistema de arquivos.
- Para conferir a saúde do script da fila após mudanças:
  `bash .claude/skills/executar-specs-pendentes/scripts/fila.test.sh`.
