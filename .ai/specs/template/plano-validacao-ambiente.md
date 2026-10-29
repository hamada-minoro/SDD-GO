# Plano de validação em ambiente: Nome da Feature

> Preencha só se a spec marcar `.ai/go/validacao-ambiente.md` em "Guias Go aplicáveis"; senão, apague este arquivo da pasta da spec. Siga `.ai/go/validacao-ambiente.md` e `.ai/infraestrutura-testes.md`. Não registre valores de credenciais nem dados pessoais reais.

## 0. Regras desta execução

- Conta, região e stage de teste, e como foram confirmados (`aws sts get-caller-identity`):
- Versão publicada testada (commit, alias/versão da função, `CodeSha256` ou tag do deploy):
- Operações permitidas e escopo da autorização atual:
- Passos 🔒 que gravam ou geram efeitos externos:
- Ações irreversíveis que exigem aprovação específica:
- Variáveis exigidas no `.env` local, **somente nomes**:

| Nome da variável | Uso | Como verificar sem exibir o valor |
|---|---|---|
| `AWS_PROFILE` | perfil da conta de teste | `aws sts get-caller-identity --query Account` |
| `TEST_API_URL` | endpoint de teste | `test -n "$TEST_API_URL"` |

## 0.A Onde paramos e como retomar

| Seção/passo | Situação | Evidência/ID criado | Próxima ação |
|---|---|---|---|
| | Não iniciado | | |

- Autorizações já recebidas (passos exatos e escopo):
- Gravações executadas e estado atual dos dados:
- Ordem exata de retomada, sem repetir gravações:

## 1. Pré-requisitos

| Item | Como verificar neste projeto | Situação em AAAA-MM-DD |
|---|---|---|
| Branch e `git status` de cada projeto | | |
| Deploy de teste corresponde ao commit | | |
| Função: `arm64`, `provided.al2023`, memória e timeout do plan | `aws lambda get-function-configuration` | |
| Mapeamento de evento: `ReportBatchItemFailures`, `BatchSize`, `MaximumConcurrency` | `aws lambda list-event-source-mappings` | |
| Variáveis de ambiente e segredos resolvidos (só nomes) | | |
| Endpoint / health check | | |
| Identidade de teste e permissões | | |

## 2. Evidências

- Pasta: `.ai/specs/NNN-feature/evidencias/`
- Diário: `evidencias/00-registro-execucao.md`
- Padrão dos nomes: `NN-passo-descricao.json` ou `.txt`, com campos sensíveis mascarados.
- Dados preparados: `evidencias/dados-teste/` (backup, rollback e IDs).
- Prefixo das chaves criadas neste teste: `teste-NNN-<timestamp>`

## 3. Dados de teste

| Dado necessário | Origem | Preparação/backup | ID ou chave | Rollback |
|---|---|---|---|---|
| | | | | |

## 4. Passos

> Uma tabela por entrega ou fluxo. Use o status/corpo literal esperado e IDs existentes na `spec.md`. Marque 🔒 antes da ação que grava. Toda linha tem a leitura que confirma o efeito.

| Passo | Ação concreta (`curl`, `aws lambda invoke`, `aws sqs send-message`...) | Esperado | Confirmação por leitura | Evidência | Cobre (RN/CA/CC/DP) |
|---|---|---|---|---|---|
| 4.1 | | | | `01-descricao.json` | CA01 |
| 4.2 🔒 | | | | `02-descricao.json` | RN01, CA02 |
| 4.3 🔒 | repetir o evento do 4.2 | uma única gravação | | `03-idempotencia.json` | |
| 4.4 🔒 | lote com um item inválido | só o item inválido volta para a fila; DLQ conforme o plan | | `04-falha-parcial.txt` | CC01 |

## 5. Métricas (se houver `DPxx` medidos em ambiente)

| DP | Métrica (`Duration`, `InitDuration`, `MaxMemoryUsed`, `Throttles`...) | Período/condição | Obtido | Critério do plan | Status |
|---|---|---|---|---|---|
| | | | | | |

## Falhas e observações

| ID | Passo | Esperado | Obtido (mensagem exata) | Evidência | Tipo (defeito/ambiente/dado/observação) | Encaminhamento |
|---|---|---|---|---|---|---|
| | | | | | | |

## Checklist de evidências

- [ ] Cada passo executado tem resultado observado, leitura de confirmação e evidência segura.
- [ ] Escritas e IDs criados estão no diário.
- [ ] Segredos, tokens e dados pessoais foram omitidos ou mascarados.
- [ ] Passos bloqueados e cobertura não provada estão identificados.

## Encerramento e limpeza

- [ ] Encerrar processos iniciados e reverter configuração temporária; conferir `git diff`/`git status`.
- [ ] Limpar apenas dados criados neste teste e autorizados; registrar pendências com IDs e rollback.
- [ ] Atualizar `tests.md` (tabela "Validação em ambiente") e acrescentar entrada em `review.md`.
- [ ] Registrar fatos novos verificados em `.ai/infraestrutura-testes.md`.
