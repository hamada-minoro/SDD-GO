---
name: executar-specs-pendentes
description: Processa em loop as specs pendentes de .ai/specs/ (uma por vez, contexto zerado entre specs, ciclo SDD completo via subagente executor-spec-sdd), até esgotar a fila. Use quando o desenvolvedor pedir para executar/implementar as specs pendentes em sequência.
---

# Executar specs pendentes em sequência

Você é a **orquestradora** do modo autônomo do framework SDD. Seu papel é
gerenciar a fila e disparar um subagente novo por spec — você **não**
implementa nenhuma spec diretamente (isso é do subagente `executor-spec-sdd`,
que nasce sem contexto desta conversa, garantindo contexto zerado entre
specs).

Restrição: não rode duas instâncias desta skill ao mesmo tempo — não há
lock; o estado vive no sistema de arquivos.

## Loop

Mantenha durante a rodada uma lista `tentadas` (nomes de spec já processados
nesta rodada, qualquer que tenha sido o resultado).

1. **Calcular a fila:** rode
   `bash .claude/skills/executar-specs-pendentes/scripts/fila.sh .ai/specs`
   a partir da raiz do projeto. A saída (`<numero><TAB><pasta>`) já vem na
   ordem de execução: pelo prefixo numérico da pasta (`001-...`, `002-...`,
   comparação numérica), empate por ordem alfabética — a mesma regra de
   numeração de `.ai/ai-instructions.md` (seção 3). Nunca reordene a fila por outro
   critério. Pastas com `spec.md` mas sem prefixo numérico não entram na
   fila; o script as avisa em stderr (`ignorada (sem numeração): <pasta>`) —
   guarde esses nomes para o relatório final e não as renomeie você mesma.
   Recalcule a cada iteração — a lista muda conforme pastas são movidas.
2. **Uma tentativa por rodada:** remova da fila as specs em `tentadas` —
   cada spec tem no máximo **uma** tentativa por rodada; retentativa só numa
   próxima rodada disparada manualmente pelo desenvolvedor.
3. **Fila vazia?** Encerre com o relatório final (ver abaixo).
4. **Disparar o executor:** para a primeira spec da fila, chame a ferramenta
   `Agent` com `subagent_type: "executor-spec-sdd"` e
   `run_in_background: false` (sequencial — nunca dispare dois em paralelo).
   Prompt mínimo: o nome da pasta da spec e a raiz do projeto. Não repasse
   nenhuma informação de specs anteriores (decisões, arquivos, resultados) —
   o executor deve ler tudo do zero.
5. **Checar interrupção antes de avaliar:** se a chamada do executor
   terminou com erro de infraestrutura (ver seção "Interrupções e retomada
   automática"), isso **não** é resultado da spec — siga o protocolo de
   retomada daquela seção e só avance para o passo 6 quando o ciclo da spec
   de fato terminar. Se o executor retornou "rápido demais" sem o relatório
   estruturado da seção 8 do seu contrato, trate como trabalho em andamento:
   aguarde a notificação de conclusão ou consulte
   `.ai/specs/<spec>/.execution-state.json` antes de decidir retomar via
   `SendMessage`.
6. **Conferir o resultado você mesma:** ao terminar o executor, leia
   `.ai/specs/<spec>/review.md` — a fonte de verdade é o arquivo, não o
   relato do subagente.
   - Se a entrada **mais recente** conclui **"Aprovada"** (não "aprovada com
     pendências", não "reprovada"): mova a pasta com
     `mv .ai/specs/<spec> .ai/specs/concluidos/<spec>`.
   - Caso contrário: deixe a pasta onde está; confirme que o motivo está
     registrado em `review.md`/`build-logs.md` da spec e siga em frente — nunca
     fique parado numa spec.
7. Adicione a spec a `tentadas` e volte ao passo 1.

## Interrupções e retomada automática

Quando uma chamada ao executor (ou a própria conversa) falha com um destes
padrões, a spec **não** foi reprovada — a infraestrutura de execução ficou
indisponível. Não conte a tentativa como consumida (exceção à regra de uma
tentativa por rodada), não mova a pasta, e **não espere o desenvolvedor
digitar "continue"**: retome sozinha.

### Padrões de erro reconhecidos (observados em rodadas reais)

| Padrão (substring, case-insensitive) | Tipo | Quando tentar de novo |
|---|---|---|
| `You've hit your monthly spend limit` (ex.: `API Error: You've hit your monthly spend limit · raise it at claude.ai/settings/usage`) | Limite de gasto mensal — sem horário de reset na mensagem | Backoff: reagendar a cada 60 min até voltar |
| `You've hit your session limit · resets <hora>` (ex.: `resets 8pm`, `resets 4:10am`) | Limite de sessão — **a mensagem informa o horário de reset**; extraia-o | No horário de reset + 5 min de folga |
| `Connection closed mid-response` (ex.: `API Error: Connection closed mid-response. The response above may be incomplete.`) | Erro de conexão transitório | Imediatamente (1 retomada direta; se falhar de novo, aguardar 5 min) |
| Fallback: qualquer mensagem casando `hit your .* limit` ou `usage limit reached` | Variante de limite ainda não catalogada | Backoff de 60 min |

### Protocolo de retomada

1. **Registrar o ponto de parada:** anote o `agentId` do executor
   interrompido e a spec em andamento. Determine a fase alcançada lendo
   `.ai/specs/<spec>/.execution-state.json` (escrito pelo executor a cada
   etapa); se o arquivo não existir (executor interrompido cedo), use a
   heurística: existe `review.md` com entrada nova? → ciclo completo;
   existe `plan.md`/`tasks.md`? → interrompido durante implementação.
2. **Agendar a nova tentativa** com `ScheduleWakeup`, usando o prazo da
   tabela acima. `delaySeconds` é limitado a 3600; se o horário de reset
   estiver a mais de 1h de distância, encadeie wakeups de 3600s até
   alcançá-lo (`reason` explicando: "aguardando reset do limite às Xh").
   No `prompt` do wakeup, passe instruções completas para se
   re-orientar sem depender de memória, ex.:
   `Continue a rodada da skill executar-specs-pendentes: retome o agente
   <agentId> da spec <spec> via SendMessage (trabalho parcial em disco em
   .ai/specs/<spec>/) e depois continue o loop normal da fila.`
3. **Ao acordar, retomar — não reiniciar:** envie `SendMessage` ao **mesmo**
   `agentId`, instruindo-o a continuar do ponto registrado no
   `.execution-state.json` (preserva `plan.md`/`tasks.md`/`tests.md` e
   investigações já feitas). Só se o `SendMessage` falhar (agente não existe
   mais) dispare um executor novo para a mesma spec, avisando no prompt que
   há trabalho parcial em disco a ser reaproveitado, não refeito.
4. **Se o limite ainda não resetou** (o mesmo erro volta), reagende
   silenciosamente. Só escale para o desenvolvedor se, após **6 tentativas**
   consecutivas falhando pelo mesmo motivo (~6h no backoff de 60 min), o
   bloqueio persistir — aí sim encerre a rodada com relatório parcial
   indicando exatamente onde parou e como retomar.

## Guarda-corpos (valem para você e para qualquer coisa que o executor reporte)

- Nunca dê `git push`, nunca abra/mescle PR — revisão e envio são sempre
  manuais do desenvolvedor, mesmo em modo autônomo.
- Commits só nas branches criadas pelo executor (`feat/<slug>` /
  `fix/<slug>`), nunca na branch padrão.
- **NENHUM `Co-Authored-By:`. NENHUMA IA pode ser listada como
  `Co-Authored-By:`** nos commits da rodada, nem "Generated with ...",
  "🤖" ou nome de modelo. Depois de cada executor, confira com
  `git log <branch-padrão>..<branch> --format=%B | grep -i "co-authored-by\|generated with"`
  em cada repositório; se aparecer algo, registre como violação no
  relatório final para o desenvolvedor corrigir antes do push.
- Nunca edite `AGENTS.md`, `CLAUDE.md`, `ai-instructions.md`,
  `architecture*.md`, `README.md`, `INSTRUCTIONS.md`, `prompts.md` ou
  `specs/template/` do framework (fora de escopo da spec), e nunca renomeie
  nem renumere pastas de spec — a numeração é do desenvolvedor.
- Não pause para pedir aprovação entre specs — o desenvolvedor revisa o
  resultado acumulado no final.

## Relatório final

Ao esgotar a fila, apresente ao desenvolvedor:

- **Aprovadas e movidas para `concluidos/`:** spec (com número) →
  projetos envolvidos → repositório(s)/branch(es) do commit. Como as
  mensagens de commit não citam a spec, este relatório é o registro da
  ligação spec → branch.
- **Não aprovadas (permanecem pendentes):** spec → conclusão do review e
  motivo resumido.
- **Alertas de área sensível:** specs com entrada `⚠️ ÁREA SENSÍVEL:`
  no próprio `build-logs.md` (procure em `.ai/specs/*/build-logs.md` e
  `.ai/specs/concluidos/*/build-logs.md`), para revisão redobrada.
- **Ignoradas por falta de numeração:** pastas avisadas pelo `fila.sh`, com
  a sugestão de renomeá-las para `NNN-<nome>` seguindo a sequência.
- **Interrupções e retomadas:** quantas ocorreram, por qual motivo (limite
  mensal / limite de sessão / conexão) e quanto tempo de espera acumularam.
- Lembrete: nenhuma branch recebeu push — revisar e enviar manualmente.
