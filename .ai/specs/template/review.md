# Review: Nome da Feature

> Histórico de revisões da implementação contra a `spec.md`.
> Cada execução do prompt "4. Validar contra a spec" (`prompts.md`) deve adicionar uma nova entrada abaixo — nunca sobrescreva uma entrada anterior.

---

## Revisão — [data]

### Critérios de aceite

- [ ] Cumprido: ...
- [ ] Não cumprido: ...

### Regras de negócio

- Cobertas:
- Não cobertas / parcialmente cobertas:

### Concorrência (CCxx)

| CC | Implementado como no plan? | Limite respeitado? | Cancelamento/prazo ok? | Teste que prova | Situação |
|---|---|---|---|---|---|
| CC01 | | | | | |

Regras CONC-01 a CONC-11 (`.ai/go/concorrencia.md`, seção 5) conferidas em todo código concorrente novo. Violações encontradas:

-

### Desempenho e custo (DPxx)

| DP | Medido como | Resultado | Critério | Situação |
|---|---|---|---|---|
| | | | | |

### Casos de erro

- Tratados:
- Não tratados:

### Permissões e segurança

- Autenticação/autorização corretas:
- IAM com privilégio mínimo:
- Segredos/dados pessoais fora de logs:

### Portões de qualidade Go

- Portões 1–8 de `.ai/go/testes.md` passando (tabela do tests.md): sim/não, e quais falharam
- Mudança não registrada em `go`/`toolchain` do go.mod: sim/não

### Testes

- Testes relevantes em `tests.md` conferidos: sim/não
- Todo RN, CA e CC tem teste: sim/não
- Testes faltando para cobrir esta revisão:
- Validação em ambiente (se a spec marcar `validacao-ambiente.md`): stage e versão testados, passos executados, RN/CA/CC/DP comprovados, leituras de confirmação:
- Passos bloqueados, falhas e cobertura não provada:
- Dados criados no ambiente (IDs), limpeza realizada ou pendente:

### Fora de escopo identificado

-

### Arquitetura e idioma Go

- Arquitetura do projeto respeitada: sim/não (detalhar divergências, se houver)
- `.ai/go/idiomatico.md` respeitado; dependências novas registradas no build-logs: sim/não

### Pendências

- [ ]

### Conclusão

> Aprovada / Aprovada com pendências / Reprovada

Justificativa:
