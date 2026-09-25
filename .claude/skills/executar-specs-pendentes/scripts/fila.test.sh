#!/usr/bin/env bash
# Teste de fila.sh. Roda com: bash fila.test.sh
# Sai com código 0 se todos os cenários passarem; != 0 e mensagem em caso de falha.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILA="$HERE/fila.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FALHOU: $1" >&2
  echo "--- saída obtida ---" >&2
  echo "$2" >&2
  exit 1
}

# Fixture: specs/ numeradas fora de ordem alfabética/de tamanho, número com
# mais dígitos (010 > 009 e 100 > 010), empate de número, pasta sem
# numeração, pasta sem spec.md, e concluidos/ + template/ que devem ser
# ignoradas.
mkdir -p "$TMP/specs"/{010-grande,002-b-empate,002-a-empate,009-pequena,100-centena,sem-numero,003-sem-spec,concluidos/001-feita,template}
printf 'l\n%.0s' {1..50} >"$TMP/specs/010-grande/spec.md"
printf 'l\n%.0s' {1..20} >"$TMP/specs/002-b-empate/spec.md"
printf 'l\n%.0s' {1..20} >"$TMP/specs/002-a-empate/spec.md"
printf 'l\n%.0s' {1..5}  >"$TMP/specs/009-pequena/spec.md"
printf 'l\n%.0s' {1..1}  >"$TMP/specs/100-centena/spec.md"
printf 'l\n%.0s' {1..1}  >"$TMP/specs/sem-numero/spec.md"
printf 'l\n%.0s' {1..3}  >"$TMP/specs/concluidos/001-feita/spec.md"
printf 'l\n%.0s' {1..3}  >"$TMP/specs/template/spec.md"
touch "$TMP/specs/003-sem-spec/plan.md"

out="$(bash "$FILA" "$TMP/specs" 2>"$TMP/stderr")"

esperado="$(printf '002\t002-a-empate\n002\t002-b-empate\n009\t009-pequena\n010\t010-grande\n100\t100-centena')"
[[ "$out" == "$esperado" ]] || fail "ordenação numérica + desempate alfabético + exclusões" "$out"

grep -qx "ignorada (sem numeração): sem-numero" "$TMP/stderr" \
  || fail "pasta sem numeração deveria ser avisada em stderr" "$(cat "$TMP/stderr")"

# Fila vazia: diretório só com concluidos/template/pasta sem spec.md
mkdir -p "$TMP/vazia"/{concluidos,template,001-sem-spec}
out_vazia="$(bash "$FILA" "$TMP/vazia")"
[[ -z "$out_vazia" ]] || fail "fila vazia deveria não imprimir nada" "$out_vazia"

# Diretório inexistente: erro com exit != 0
if bash "$FILA" "$TMP/nao-existe" 2>/dev/null; then
  fail "diretório inexistente deveria falhar" "(exit 0)"
fi

echo "OK: todos os cenários de fila.test.sh passaram"
