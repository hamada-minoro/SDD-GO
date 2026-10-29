# Tests: Nome da Feature

> Registro dos testes escritos para esta feature (unitários, concorrência, integração, fuzz, benchmark).
> Cada teste referencia o que cobre na `spec.md`: regra de negócio (`RNxx`), critério de aceite (`CAxx`), requisito de concorrência (`CCxx`) ou de desempenho (`DPxx`).
> Atualize conforme os testes forem escritos.

## Resumo

- Total de testes:
- Cobertura (`go tool cover -func`):
- Comandos executados:

```bash
go test -race -count=1 ./...
go test -race -count=1 -tags integration ./...
```

## Portões de qualidade

> Os portões 1–8 de `.ai/go/testes.md` (seção 1).

| # | Portão | Resultado (✅ / ❌ / pendente + motivo) |
|---|---|---|
| 1 | Formatação | |
| 2 | Vet | |
| 3 | Lint | |
| 4 | Testes + race | |
| 5 | Integração | |
| 6 | Vulnerabilidades | |
| 7 | Build ARM64 | |
| 8 | Módulo limpo | |

## Testes unitários

### `internal/<pacote>`

| Teste | Cobre | Cenário | Resultado esperado | Status |
|---|---|---|---|---|
| `TestX_Cenario` | RN01, CA01 | | | ⬜ pendente / ✅ passou / ❌ falhou |

## Testes de concorrência

| Teste | Cobre | O que prova (limite, cancelamento, falha parcial, ordem, sem vazamento) | Ferramenta (race, synctest, goleak, estresse) | Status |
|---|---|---|---|---|
| | CC01 | | | |

Estresse executado: `go test -race -count=__ -cpu=1,2,4 -run '...' ./...` → resultado:

## Testes de integração

| Teste | Cobre | Cenário | Resultado esperado | Status |
|---|---|---|---|---|
| | | | | |

## Fuzz

| Alvo | Cobre | Tempo executado | Achados | Status |
|---|---|---|---|---|
| | | | | |

## Benchmarks e medições de desempenho

> Para micro-benchmarks, cole a saída do `benchstat` (antes × depois). Para `DPxx` de sistema, a condição e o resultado.

| Benchmark / DP | Condição | Antes | Depois | Critério | Status |
|---|---|---|---|---|---|
| | | | | | |

```txt
(saída do benchstat)
```

## Validação em ambiente (se a spec marcar `validacao-ambiente.md`)

> Roteiro em `plano-validacao-ambiente.md`; artefatos locais em `evidencias/`. Registre o observado, não só o esperado. Bloqueado não equivale a aprovado.

- Conta/região/stage e versão publicada testada:

| Passo | Cobre (RN/CA/CC/DP) | Esperado | Observado | Confirmação por leitura | Evidência | Status |
|---|---|---|---|---|---|---|
| | | | | | | ⬜ pendente / ✅ passou / ❌ falhou / 🚫 bloqueado |

## Casos de borda cobertos

- [ ]

## Casos de borda não cobertos (e por quê)

- Caso:
  - Motivo de não estar coberto:

## Pendências

- [ ] Teste a escrever:
- [ ] Teste a corrigir:
