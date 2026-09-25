# Desempenho e custo em Go

> **Leitura condicional:** quando a spec tem requisitos `DPxx`. Regra: não escolha arquitetura, runtime ou otimização por opinião; meça o workload.

## 1. Como escrever um `DPxx`

Número + condição + forma de medir:

```md
- DP01: p99 de POST /pedidos ≤ 200 ms com 500 req/s sustentadas por 5 min, 0% de 5xx.
- DP02: Lambda processar-pedidos, 512 MB, arm64: lote de 10 mensagens em ≤ 1,5 s (p95).
- DP03: custo ≤ US$ X por milhão de pedidos.
- DP04: p99 ≤ 500 ms até 2.000 usuários simultâneos (ponto de saturação).
- DP05: memória em regime ≤ 128 MiB por instância.
```

Proibido: "rápido", "alta performance", "escalável". Sem número conhecido, a spec cria uma tarefa de **medição de linha de base**.

## 2. Métricas

| Métrica | API | Lambda |
|---|---|---|
| Vazão (req/s, itens/s) | ✅ | ✅ |
| Latência p50 / p95 / p99 / p99.9 | ✅ | ✅ (`Duration`) |
| Taxa de erro | ✅ | ✅ (inclui falhas parciais) |
| CPU por requisição: `(CPU% ÷ 100) × 1000 ÷ req/s` ms | ✅ (a métrica justa com CPU saturada) | — |
| Memória em regime | ✅ | ✅ (`Max Memory Used`) |
| Cold start | — | ✅ (`Init Duration`) |
| Ponto de saturação (carga máxima com p99 ≤ SLO) | ✅ | ✅ |
| Saturação do downstream (CPU do banco, throttling) | ✅ | ✅ |
| Custo por unidade de trabalho | ✅ | ✅ |

## 3. Ferramentas

- **Micro:** `testing.B` com `b.Loop()`, `-benchmem`, `-count=10`, comparado com `benchstat` (`testes.md`, seção 5).
- **Perfil:** `-cpuprofile`/`-memprofile` + `go tool pprof`; em serviço, `net/http/pprof` em porta interna (`profile`, `heap`, `goroutine`, `mutex`, `block`); `go tool trace` e `runtime/trace.FlightRecorder` (Go ≥ 1.25) para a cauda da latência. O perfil de goroutines é o primeiro lugar para procurar vazamento.
- **Carga:** Locust, k6 ou vegeta. Para Lambda, AWS Lambda Power Tuning (memória × arquitetura × custo).

## 4. Metodologia

1. Mesmas condições entre as variantes: limites de CPU/memória, dataset, banco e algoritmo.
2. Aquecimento antes de medir.
3. ≥ 5 min por cenário; mais de uma execução quando a diferença esperada for pequena.
4. Cenários separados (leitura, escrita, contenção, misto) e uma rampa para achar a saturação.
5. **Meça o downstream junto.** Um runtime mais eficiente satura o banco, e isso aparece como cauda de latência.
6. Correção junto com velocidade: confira o invariante da spec a cada rodada.
7. Registre as versões (Go, dependências, imagem, arquitetura) e as ressalvas.
8. Em carga de laço fechado, a latência inclui fila: informe a condição junto do número.

## 5. Otimizações (em ordem de custo/benefício, só com `DPxx` e medição antes/depois)

1. Menos round-trips: batch no banco, menos chamadas por requisição, `singleflight`.
2. Concorrência de I/O onde há independência (`concorrencia.md`).
3. Menos alocação: structs tipadas em vez de `map[string]any`, `make` com capacidade, `strings.Builder`, reuso de buffers. `sync.Pool` só com benchmark.
4. JSON: structs com tags. `encoding/json/v2` (experimental no Go 1.25) só com decisão registrada.
5. GC: `GOMEMLIMIT` alinhado ao limite; `GOGC` só com medição.
6. **PGO:** perfil de CPU representativo como `default.pgo` no pacote `main`. O build usa automaticamente e costuma ganhar alguns por cento de CPU.
7. Análise de escape (`-gcflags=-m`) em funções críticas.

Micro-otimização que complica o código sem `DPxx` é recusada no review.

## 6. Custo

- **ARM64 é o padrão.** O preço por GB-s em arm64 é menor na Lambda (confira a tabela vigente), e Graviton também custa menos no Fargate e no EC2. A decisão final sai da medição do workload.
- Go usa pouca memória: em container isso vira densidade; na Lambda, memória também compra CPU, então o ponto ótimo sai do Power Tuning.
- Métrica de decisão:

```txt
Lambda:    custo/1M itens ≈ duração s × memória GB × preço GB-s × invocações + preço/req × invocações
Container: custo/1M req  ≈ custo/hora ÷ (req/s sustentável no SLO × 3.600) × 1.000.000
```

- Lote maior reduz invocações, mas aumenta a latência e o raio de falha: é decisão de `DPxx`.
