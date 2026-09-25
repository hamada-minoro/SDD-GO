# Concorrência em Go: da spec ao código

> **Leitura obrigatória.** Concorrência é requisito: nasce na `spec.md` (`CCxx`), vira desenho no `plan.md`, é implementada com `// NNN-CCxx` no ponto em que nasce e é provada por teste. O código de cada padrão está em `concorrencia-padroes.md`, que só é lido na implementação, e só nas seções escolhidas no plan.

## 1. Ciclo de um `CCxx`

| Etapa | O que se escreve |
|---|---|
| `spec.md` | Linguagem de negócio: "as 3 consultas são independentes; falha de uma cancela o pedido; prazo 800 ms" |
| `plan.md` | Padrão (`P1`–`P10`), limite e origem, dono, término, cancelamento, falha, teste |
| Código | `// 007-CC01` onde a goroutine, o limite, o canal ou o lock é criado |
| `tests.md` / `review.md` | Teste que prova + checagem das regras da seção 5 |

## 2. Perguntas que toda spec responde

Cada resposta relevante vira um `CCxx`. "Não se aplica" é válido, mas escrito.

1. **Trabalho independente:** chamadas, itens ou etapas que não dependem umas das outras?
2. **Ordem:** global ou **por chave** (cliente, conta, `MessageGroupId`)?
3. **Estado compartilhado:** execuções simultâneas disputam o mesmo registro? Como a consistência é garantida?
4. **Capacidade downstream:** conexões, rate limit, capacidade do DynamoDB, concorrência reservada.
5. **Falha parcial:** tudo ou nada, melhor esforço, retry só do item?
6. **Prazo e cancelamento:** prazo total (SLO, timeout da Lambda); o que fazer se o cliente desistir?
7. **Idempotência:** o mesmo trabalho pode chegar duas vezes? Qual a chave?
8. **Volume:** itens por requisição/lote e req/s, típico e pico.

## 3. Usar goroutines ou não?

- **Sem trabalho independente → sequencial.** Em HTTP, o `net/http` já dá uma goroutine por requisição; não crie outra "para ficar paralelo".
- **I/O independente (rede, banco, SDK AWS) → paralelize** para sobrepor latência (tempo ≈ o da chamada mais lenta, não a soma). Vale até com fração de vCPU.
- **CPU → só com mais de 1 core efetivo e custo por item muito maior que o de coordenar.** Limite = `GOMAXPROCS`; exige benchmark (CONC-11).
- **Ordem global → sequencial. Ordem por chave → `P5`.**
- **Falha deve cancelar o resto → `P1`. Não deve → `P2`.**

## 4. Padrões (escolha um por `CCxx`)

`golang.org/x/sync` é dependência pré-aprovada. Padrão fora desta tabela exige justificativa no plan e entrada no `build-logs.md`.

| ID | Padrão | Quando usar |
|---|---|---|
| P1 | `errgroup.WithContext` | Poucas chamadas independentes, todas necessárias (tudo ou nada) |
| P2 | `errgroup.Group` + `SetLimit` + erro por slot | Lista de tamanho variável, falha de um não invalida os outros |
| P3 | Worker pool sobre canal | Fluxo contínuo ou tamanho desconhecido (consumidor, stream) |
| P4 | Pipeline por estágios | Etapas com perfis diferentes (parse CPU → gravação I/O), paralelismo por estágio |
| P5 | Particionamento por chave | Ordem por chave (SQS FIFO, eventos por conta, Kinesis) |
| P6 | Semáforo global / `rate.Limiter` | Recurso de capacidade fixa disputado por várias requisições |
| P7 | `singleflight` | Muitas requisições simultâneas pela mesma chave (cache miss, token) |
| P8 | Goroutine de longa duração + `WaitGroup.Go` | Consumidor/ticker em container, encerrado no shutdown. **Nunca em Lambda** |
| P9 | Confinamento → canal → mutex → atomic → `OnceValue` | Estado compartilhado **em memória** |
| P10 | `recover` na goroutine filha | Goroutine que roda código com risco de panic |

## 5. Regras invioláveis

| ID | Regra |
|---|---|
| CONC-01 | Toda goroutine tem dono, condição de término e cancelamento. Sem resposta para "quando ela termina?", não a crie. |
| CONC-02 | Concorrência sempre limitada; o limite vem da config e da capacidade downstream. Proibido `for ... { go ... }` sem limite. |
| CONC-03 | `ctx` é o primeiro parâmetro de toda função com I/O e é repassado até o driver/SDK. Nunca `context.Background()` no caminho da requisição. |
| CONC-04 | Só o produtor fecha o canal. Todo envio que pode bloquear usa `select` com `ctx.Done()`. |
| CONC-05 | Erros de goroutines nunca se perdem (errgroup, slot indexado ou canal de resultado). |
| CONC-06 | Panic em goroutine derruba o processo, e o `recover` do middleware HTTP não o pega. Use `P10` onde há risco. |
| CONC-07 | Nenhuma goroutine sobrevive ao retorno da Lambda: o ambiente é congelado. |
| CONC-08 | `go test -race` é obrigatório; race detectado reprova. |
| CONC-09 | Sem `time.Sleep` para sincronizar, nem em teste (use `testing/synctest`). |
| CONC-10 | Toda goroutine de feature tem `// NNN-CCxx` no ponto de criação ou entrada no `build-logs.md`. |
| CONC-11 | Paralelismo de CPU só com benchmark antes/depois (`benchstat`). |

Também reprovam no review: `wg.Add` dentro da goroutine; mutex segurado durante I/O; canal fechado pelo consumidor; `append` concorrente num slice compartilhado; buffer enorme de canal escondendo backpressure; goroutine para trabalho de CPU minúsculo.

## 6. Limite = capacidade de quem recebe a carga

Go eficiente não elimina gargalo, empurra-o para baixo (banco, API de terceiro). Todo limite nasce da capacidade downstream documentada no `architecture.md`.

- **Lei de Little:** `concorrência necessária = vazão × latência`. Ex.: 2.000 req/s × 5 ms de conexão ocupada = 10 conexões em média; pool de 20 a 40 cobre picos.
- Limite de fan-out de uma operação ≤ capacidade ÷ operações simultâneas esperadas.
- Aquisição de recurso tem timeout **próprio**, separado do tempo da operação.
- Limite estourado → rejeitar rápido (503/429 + `Retry-After`) ou deixar na fila. Nunca acumular goroutines esperando sem fim.

## 7. Lambda: dois níveis

- **Nível 1:** a AWS escala ambientes, com uma invocação por vez em cada um. Quem controla são a concorrência reservada e o `MaximumConcurrency` do SQS.
- **Nível 2:** goroutines dentro da invocação, controladas por `P1`/`P2`/`P5` com limite.
- **Carga no downstream = nível 1 × nível 2.** Não aumente o `BatchSize` "para aproveitar goroutines" sem recalcular prazo, memória e falha parcial.

## 8. Como provar

Ferramentas e exemplos em `testes.md`, seção 4:

- `-race` sempre;
- `goleak` nos pacotes com goroutines novas;
- `synctest` para prazo, cancelamento e retry;
- fake que mede a concorrência máxima para provar o limite;
- fakes que falham em itens específicos (falha parcial) ou registram a sequência (ordem por chave);
- estresse com `-count=50 -cpu=1,2,4`;
- integração com N operações simultâneas conferindo o invariante da spec.
