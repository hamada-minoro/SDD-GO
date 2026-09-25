# DynamoDB em Go

> **Leitura condicional:** quando a spec marca DynamoDB em "Guias Go aplicáveis". Vale para API e Lambda: a borda muda, o repositório não.

## 1. Cliente e repositório

- `aws-sdk-go-v2/service/dynamodb`: **um cliente**, criado no wiring (`main`, INIT da Lambda) e compartilhado pelas goroutines, pois é seguro para uso concorrente.
- O repositório depende de uma **interface pequena** com só os métodos usados (`GetItem`, `Query`, `PutItem`...), definida no pacote do repositório. Nos testes, entra um fake dessa interface.
- Nome da tabela vem da config (env var), nunca fixo no código.
- Conversão com `feature/dynamodb/attributevalue` (`MarshalMap`/`UnmarshalMap`) e tags `dynamodbav:"nome"`. Expressões com `feature/dynamodb/expression` em vez de montar strings à mão.

## 2. Modelagem a partir dos padrões de acesso

- A spec descreve **como os dados são buscados** (por qual chave, com qual filtro, em qual ordem). O plan deriva disso partition key, sort key e GSIs.
- Toda leitura no caminho quente é **`GetItem` ou `Query` por chave**. **`Scan` é proibido no caminho de requisição/invocação**, exceto com decisão registrada.
- Use `ProjectionExpression` para trazer só os atributos necessários.
- `ConsistentRead: true` só quando a spec exige ler a própria escrita; GSI é sempre eventualmente consistente.
- Limites que o plan precisa respeitar: item ≤ 400 KB; página de `Query` ≤ 1 MB (pagine com `dynamodb.NewQueryPaginator`); `BatchGetItem` ≤ 100 chaves; `BatchWriteItem` ≤ 25 itens; `TransactWriteItems` ≤ 100 itens.

## 3. Escritas, idempotência e concorrência

- **Idempotência:** `PutItem` com `ConditionExpression: attribute_not_exists(pk)`. `ConditionalCheckFailedException` significa "já processado", e o comportamento vem da spec.
- **Atualização concorrente do mesmo item:** controle otimista com atributo `version` (`ConditionExpression: version = :v`). Em conflito, releia e decida conforme a spec, nunca com retry cego.
- **Várias escritas que precisam ser atômicas:** `TransactWriteItems`.
- Erros tipados com `errors.As`:

```go
var ccf *types.ConditionalCheckFailedException
if errors.As(err, &ccf) {
	return ErrJaProcessado // erro de domínio, mapeado na borda
}
```

## 4. Leituras de vários itens

| Situação | Escolha |
|---|---|
| Até 100 chaves conhecidas, mesma tabela ou várias | `BatchGetItem`, reenviando `UnprocessedKeys` com backoff |
| Chaves independentes que precisam de condição/projeção própria, ou mais de 100 | Fan-out `P2` com `GetItem` e limite |
| Itens do mesmo partition key | Uma `Query` |

`BatchWriteItem` também devolve `UnprocessedItems`: trate sempre, pois ignorar perde dados em silêncio.

## 5. Capacidade e erros de infraestrutura

- Capacidade (on-demand ou provisionada, limites por partição) está em "Capacidade dos recursos compartilhados" do `architecture.md` e define o limite de fan-out.
- O SDK já faz retry com backoff em throttling (retryer padrão). Não empilhe retry próprio por cima sem decisão registrada. Ajuste `RetryMaxAttempts` na config do cliente se a spec pedir.
- Throttling persistente ou timeout: 503 com `Retry-After` na API, falha parcial na Lambda.
- Toda chamada recebe o `ctx` da requisição, com o prazo do plan.
- **Partição quente** (muitas escritas na mesma chave) é risco de desenho: registre no plan como risco técnico.

## 6. Testes

- Unitário: fake da interface do repositório/cliente, cobrindo condição falhada, item ausente, `Unprocessed*` e throttling.
- Integração (`-tags integration`): DynamoDB Local ou LocalStack, conforme `infraestrutura-testes.md`, com tabela criada pelo próprio teste.
- Idempotência: mesma operação duas vezes, e o segundo resultado é o que a spec define.
