# Build Logs: Nome da Feature

> Diário de decisões tomadas durante a implementação **desta feature**. Cada feature tem o seu próprio `build-logs.md`, dentro da pasta da spec (`.ai/specs/NNN-nome-da-feature/build-logs.md`) — decisões de uma feature nunca são registradas no arquivo de outra.
>
> Cada entrada é independente e adicionada em ordem cronológica ao final do arquivo — o histórico nunca é sobrescrito.
>
> Adicione uma entrada sempre que: escolher entre abordagens técnicas possíveis, desviar do plan.md/tasks.md, preencher uma lacuna da spec.md, introduzir uma dependência nova, ou tomar qualquer decisão que não seria óbvia só de olhar o código depois.
>
> Em Go, estas decisões **sempre** geram entrada:
>
> - dependência nova fora da lista pré-aprovada de `.ai/go/idiomatico.md` (com motivo, Go puro/ARM64 e `govulncheck`);
> - mudança nas diretivas `go` ou `toolchain` do `go.mod`;
> - uso de CGO, biblioteca nativa, Layer/Extension, ou alvo x86_64 em vez de arm64;
> - goroutine, canal ou limite de concorrência que não estava no "Desenho de concorrência" do plan, ou padrão fora do catálogo de `.ai/go/concorrencia.md`;
> - valor de limite de concorrência, tamanho de pool, `GOMAXPROCS`/`GOMEMLIMIT`, memória/timeout de Lambda diferente do plan;
> - otimização de desempenho (com o resultado da medição antes/depois);
> - `map[string]any`, reflexão ou framework web no caminho quente.
>
> Entradas sobre áreas sensíveis (lista de "nunca alterar sem validação humana" do `ai-instructions.md`) começam o título com `⚠️ ÁREA SENSÍVEL:`.

## Modelo de entrada

```md
## AAAA-MM-DD — Tarefa: nome da tarefa em andamento

**Decisão:** o que foi decidido.

**Motivo:** por que essa opção foi escolhida.

**Alternativas descartadas:** o que mais foi considerado e por que foi descartado.

**Impacto:** arquivos, módulos ou comportamento afetados.

**Divergência do plano:** sim/não. Se sim, se foi validada com o desenvolvedor.
```

---

<!-- Novas entradas a partir daqui -->
