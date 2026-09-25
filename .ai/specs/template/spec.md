# Spec: Nome da Feature

## Contexto

Explique o cenário atual e por que essa funcionalidade é necessária.

## Problema

Descreva o problema que será resolvido.

## Objetivo

Descreva o resultado esperado.

## Projetos e arquiteturas envolvidos

> **Obrigatório.** Esta tabela define **exatamente** quais arquivos de arquitetura a IA lê antes de executar a feature: o `architecture.md` (mapa) mais os arquivos listados aqui, e nenhum outro. Liste só os projetos que a feature **altera**. Em projeto único, preencha uma linha com `(projeto único)` e `—`.

| Projeto (pasta) | Tipo de entrega | Arquitetura a ler | O que muda nele |
|---|---|---|---|
| `pasta-do-projeto/` | API HTTP / Lambda (gatilho: SQS, API GW, EventBridge...) / worker / CLI | `.ai/architecture-pasta-do-projeto.md` | |

## Guias Go aplicáveis

> **Obrigatório.** Os guias sempre lidos (`idiomatico`, `concorrencia`, `testes`) não entram aqui. Marque só os condicionais que esta feature usa; a IA lê **apenas** os marcados.

- [ ] `.ai/go/api-http.md`: API HTTP
- [ ] `.ai/go/lambda-aws.md`: Lambda ou gatilho AWS
- [ ] `.ai/go/dados-dynamodb.md`: DynamoDB
- [ ] `.ai/go/dados-postgres.md`: Postgres/RDS/Aurora
- [ ] `.ai/go/performance-e-custo.md`: requisitos `DPxx`

## Usuários e sistemas envolvidos

- Usuários (papéis):
- Sistemas que chamam esta feature (clientes, filas, eventos):
- Sistemas chamados por esta feature (banco, serviços AWS, APIs de terceiros):

## Fluxo funcional

1. O cliente/evento...
2. O sistema valida...
3. O sistema consulta/grava...
4. O sistema responde/publica...

## Contrato de entrada e saída

> Endpoint (método, rota, corpo, respostas) ou evento (fonte, formato, exemplo), e o que é produzido. Para dados, descreva também os **padrões de acesso** (buscar por qual chave, filtro, ordem).

- Entrada:
- Saída (sucesso):
- Saída (erros): ver "Casos de erro"

## Regras de negócio

> Cada regra tem um ID fixo (`RN01`, `RN02`...). No código, ela é citada como `<número da spec>-RNxx` (ex.: `007-RN01`). Nunca renumere uma regra já implementada; se uma regra sair, mantenha o ID vago.

- RN01:
- RN02:
- RN03:

## Concorrência e paralelismo

> **Obrigatório.** Responda em linguagem de **negócio e operação**, não de código. Cada requisito vira um `CCxx` (no código: `// 007-CC01`). "Não se aplica" é válido, com motivo.

| Pergunta | Resposta |
|---|---|
| Há trabalho independente (chamadas, itens, etapas)? | |
| Existe exigência de ordem? Global ou por chave (cliente, conta, grupo)? | |
| Há estado compartilhado ou contenção (mesmo registro, saldo, estoque)? Como garantir consistência? | |
| Capacidade dos recursos downstream (conexões, rate limit, capacidade do DynamoDB, concorrência reservada)? | |
| Falha parcial: tudo ou nada, melhor esforço ou retry por item? | |
| Prazo total da operação e comportamento no cancelamento? | |
| Idempotência: o mesmo trabalho pode chegar duas vezes? Qual a chave? | |
| Volume típico e de pico (itens por requisição/lote, req/s)? | |

Requisitos de concorrência:

- CC01: (ex.: "As consultas ao cadastro, ao estoque e à tabela de preço são independentes; se qualquer uma falhar, o pedido falha inteiro.")
- CC02: (ex.: "Mensagens do mesmo cliente são processadas na ordem de chegada; clientes diferentes podem ser processados em paralelo.")
- CC03: (ex.: "No máximo 20 chamadas simultâneas à API do parceiro X, somando todas as instâncias/ambientes.")

## Desempenho, escala e custo

> Requisitos **mensuráveis** (número + condição + como medir), com ID `DPxx`. Sem número conhecido: "linha de base a medir". Sem requisito: "Não se aplica: motivo".

- DP01: (ex.: "p99 de POST /pedidos ≤ 200 ms com 500 req/s sustentadas, 0% de 5xx.")
- DP02: (ex.: "Lambda com 512 MB, arm64, timeout 30 s; lote de 10 mensagens em ≤ 1,5 s p95.")
- DP03: (ex.: "Memória em regime ≤ 128 MiB por instância.")

## Permissões

- Quem pode executar/chamar:
- Autenticação exigida (JWT, IAM, API key...):
- Permissões IAM que a feature precisa (privilégio mínimo):

## Dados necessários

- Campo:
- Tipo:
- Obrigatório:
- Validação:

## Casos de erro

| Situação | Resposta (status/código do contrato, ou destino: retry, DLQ) | Mensagem |
|---|---|---|
| Erro de validação | | |
| Recurso não encontrado | | |
| Conflito / idempotência com payload diferente | | |
| Downstream indisponível ou saturado | | |
| Prazo excedido | | |
| Erro inesperado | | |

## Critérios de aceite

> Cada critério tem um ID fixo (`CA01`, `CA02`...). No código, ele é citado como `<número da spec>-CAxx` (ex.: `007-CA01`). Nunca renumere um critério já implementado. Se a feature tem estado compartilhado sob concorrência, inclua um critério de **consistência** verificável (invariante).

- [ ] CA01: O cliente consegue...
- [ ] CA02: O sistema valida...
- [ ] CA03: Sob N requisições/mensagens simultâneas, o invariante ... se mantém.
- [ ] CA04: Os requisitos DPxx são atendidos na medição descrita.

## Casos de borda

-

## Fora de escopo

Liste o que não será feito nesta entrega.
