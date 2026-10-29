# Validação em ambiente de teste (stack publicada)

> **Leitura condicional:** quando a spec marca este guia em "Guias Go aplicáveis", ou quando o desenvolvedor pede uma validação ponta a ponta. Marque quando a entrega depende de IAM, gatilho, configuração ou integração que só a stack publicada prova. No modo autônomo, o executor prepara o roteiro mas não o executa (seção 7). Complementa `testes.md` (portões), `infraestrutura-testes.md` (fatos do ambiente), `plano-validacao-ambiente.md` (roteiro da spec), `tests.md` (resultado por RN/CA/CC/DP) e `review.md` (conclusão). Não substitui teste unitário nem de integração.

## 1. Por que existe

Unitário, integração local e handler chamado com evento de `testdata/` não provam o que só a stack publicada prova:

| Risco | Só aparece em ambiente |
|---|---|
| IAM | permissão faltando ou sobrando; LocalStack não aplica a maioria das políticas |
| Formato do evento | API Gateway v1 × v2 × Function URL, atributos reais do SQS, `BatchItemFailures` com `ReportBatchItemFailures` ligado no mapeamento |
| Configuração | variáveis de ambiente, Secrets Manager/SSM resolvidos, VPC, endpoints |
| Empacotamento | `bootstrap`, `provided.al2023`, `arm64` de fato na função publicada |
| Prazo e memória | cold start e duração reais contra o orçamento de prazos do plan |
| Escala × downstream | `ReservedConcurrentExecutions`/`MaximumConcurrency` do SQS respeitando a capacidade do `architecture.md` |

## 2. Regras de segurança

1. **Só ambiente de teste/homologação.** Antes de qualquer chamada que grave, confirme conta, região e stage:

   ```bash
   aws sts get-caller-identity --query Account --output text   # compare com a conta de teste do infraestrutura-testes.md
   aws configure get region
   ```

   Não conseguiu confirmar o destino? Pare antes de autenticar ou gravar. Nunca use conta, perfil ou dados de produção.
2. **Escritas marcadas.** Todo passo que grava ou dispara efeito externo (publicar em fila/tópico, `PutItem`, `INSERT`, e-mail, webhook, cobrança) recebe 🔒 no roteiro. A autorização recebida cobre os 🔒 listados explicitamente. Ação irreversível ou fora desse escopo exige aprovação específica. Aprovar spec/plan/tasks **não** autoriza efeito externo irreversível.
3. **Segredos fora de tudo.** Credenciais e tokens ficam em `.ai/specs/NNN-feature/.env` (`chmod 600`), ignorado pelo `.ai/.gitignore`. Nunca `set -x`, `echo` de variável secreta, resposta completa com token ou log sem filtro em documentação ou saída de ferramenta. Registre só os campos necessários, mascarados.
4. **Não simule sucesso.** Não altere estado do backend nem configuração da função para fazer um passo passar. Contorno só se não contornar a regra testada, registrado com o motivo e a cobertura que deixou de provar.
5. **Bloqueado não é aprovado.** Falha de ambiente (deploy indisponível, credencial expirada, dependência externa fora) é bloqueio, não falha nem aprovação da feature.

## 3. Antes de cada execução

- Branch e `git status` de cada projeto; o artefato publicado corresponde ao commit testado (versão/alias da função, `CodeSha256` ou tag do deploy).
- Função publicada com a configuração do plan:

  ```bash
  aws lambda get-function-configuration --function-name "$FN" \
    --query '{arch:Architectures,runtime:Runtime,mem:MemorySize,timeout:Timeout,handler:Handler}'
  ```

- Mapeamentos de evento conferidos quando houver SQS/Kinesis/Streams (`FunctionResponseTypes` contém `ReportBatchItemFailures`, `BatchSize`, `MaximumConcurrency`).
- Dados necessários: o que já existe, o que será criado, IDs a rastrear e rollback. Prefira chaves com prefixo do teste (ex.: `teste-NNN-<timestamp>`) para a limpeza ser exata.

## 4. Executar

Cada passo do roteiro: ação concreta → resultado observado literal → **confirmação por leitura** → evidência → RN/CA/CC/DP cobertos.

| Entrega | Ação | Confirmação por leitura |
|---|---|---|
| API (API Gateway / Function URL) | `curl` com status e corpo esperados, incluindo erros (400, 401/403, 404, 409, 422) | `GetItem`/`Query`, `SELECT`, ou `GET` da própria API |
| Lambda síncrona | `aws lambda invoke --payload fileb://evento.json out.json` | resposta + leitura do efeito |
| Lambda por fila/tópico/evento | 🔒 `aws sqs send-message` / `sns publish` / `events put-events` | efeito no dado, fila vazia, DLQ vazia (ou com a mensagem esperada), `BatchItemFailures` no log |
| Idempotência | repetir o mesmo evento/`Idempotency-Key` | uma única gravação |
| Falha parcial | lote com um item inválido | só o item inválido volta para a fila |

Logs e métricas da execução, filtrados pelo request ID ou pela chave de teste:

```bash
aws logs filter-log-events --log-group-name "/aws/lambda/$FN" \
  --start-time "$INICIO_MS" --filter-pattern '"teste-NNN-"' \
  --query 'events[].message' --output text
```

Para `DPxx` medidos em ambiente: `Duration`, `InitDuration` (cold start), `MaxMemoryUsed` e `Throttles` do período do teste, com o número e o critério do plan. Carga em ambiente compartilhado só com autorização explícita.

Classifique cada achado como **defeito**, **ambiente**, **dado de teste** ou **observação**, com passo, mensagem exata e evidência. Defeito novo vira proposta de spec de correção com o próximo número; não é corrigido em silêncio durante a validação.

## 5. Registro e retomada

- Diário em `evidencias/00-registro-execucao.md`: data/hora, conta/região/stage (sem segredos), versão publicada, passo, resultado, evidência, autorização aplicada, IDs criados, achados (`F01`… falhas, `O01`… observações). Artefatos `.txt`/`.json` mascarados, nomeados em ordem (`01-criar-pedido.json`).
- Ao interromper, atualize "Onde paramos e como retomar" do roteiro com a próxima ação exata. Na retomada, repita as verificações da seção 3, confira o estado por leitura e **não repita uma gravação já concluída**.

## 6. Encerramento

1. Encerre processos iniciados e reverta configuração temporária; confira `git diff`/`git status`.
2. Limpe só os dados que este teste criou e cujos IDs estão no diário, dentro da autorização. Sem autorização para limpar, deixe IDs e rollback como pendência. Nunca apague dados de terceiros.
3. Atualize `tests.md` (tabela "Validação em ambiente") e acrescente entrada no `review.md` com cobertura, bloqueios, achados e dados remanescentes.
4. Registre fatos novos e verificados do ambiente no `infraestrutura-testes.md`, com data.

As evidências ignoradas pelo Git só existem nesta máquina: o resultado essencial precisa estar em `tests.md` e `review.md`. Ao mover a spec para `concluidos/`, mova também a pasta local `evidencias/` se precisar preservar os links.

## 7. Efeito na conclusão

- Spec com este guia marcado só é **"Aprovada"** com todos os passos do roteiro executados e passando.
- Passo bloqueado ou não executado deixa a conclusão em no máximo **"Aprovada com pendências"**, com o motivo.
- Defeito encontrado na validação resulta em **"Reprovada"** ou em pendência com spec de correção proposta, conforme a gravidade.
- **Modo autônomo:** sem humano para autorizar escritas nem confirmar o destino, o executor preenche o `plano-validacao-ambiente.md` (passos, confirmações, dados), não executa nenhum passo contra a conta AWS e conclui no máximo "Aprovada com pendências" (motivo: validação em ambiente aguardando execução com o desenvolvedor).
