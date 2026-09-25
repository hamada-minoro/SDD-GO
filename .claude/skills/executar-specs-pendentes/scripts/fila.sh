#!/usr/bin/env bash
# Fila de specs pendentes, na ordem numérica de criação.
#
# Uso: fila.sh [caminho-para-.ai/specs]
#
# Convenção de nome das pastas: "NNN-nome-da-feature" (ex.: 001-login,
# 012-exportar-relatorio). O prefixo numérico define a ordem de execução.
#
# Saída (stdout): uma linha por spec pendente, "<numero><TAB><nome-da-pasta>",
# ordenada pelo número (crescente, comparação numérica) e, no empate, por
# ordem alfabética do nome da pasta. Pastas sem spec.md, "concluidos" e
# "template" ficam de fora.
#
# Pastas com spec.md mas sem prefixo numérico NÃO entram na fila: são
# listadas em stderr como "ignorada (sem numeração): <nome>", para que o
# desenvolvedor as renomeie seguindo a sequência.
set -euo pipefail

SPECS_DIR="${1:-.ai/specs}"

if [[ ! -d "$SPECS_DIR" ]]; then
  echo "erro: diretório não encontrado: $SPECS_DIR" >&2
  exit 1
fi

for dir in "$SPECS_DIR"/*/; do
  [[ -d "$dir" ]] || continue
  name="$(basename "$dir")"
  [[ "$name" == "concluidos" || "$name" == "template" ]] && continue
  [[ -f "$dir/spec.md" ]] || continue
  if [[ "$name" =~ ^([0-9]+)- ]]; then
    printf '%s\t%s\n' "${BASH_REMATCH[1]}" "$name"
  else
    echo "ignorada (sem numeração): $name" >&2
  fi
done | sort -t $'\t' -k1,1n -k2,2
