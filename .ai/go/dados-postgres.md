# Postgres em Go (pgx)

> **Leitura condicional:** quando a spec marca Postgres/RDS/Aurora em "Guias Go aplicáveis". Vale para API e Lambda.

## 1. Pool

- `github.com/jackc/pgx/v5` + `pgxpool`. **Um pool por processo** (ou por ambiente Lambda), criado no wiring e compartilhado por todas as goroutines. Um pool único rende mais que vários pools fatiados.
- `MaxConns` vem da config e é dimensionado pela Lei de Little (`concorrencia.md`, seção 6), nunca "o maior possível".
- `Ping` com timeout na subida (fail fast).
- **Timeout de aquisição separado do tempo da operação:** adquira com `context.WithTimeout` e rode a query ou transação no `ctx` da requisição. Aplicar o timeout de aquisição à transação inteira gera 503 falsos sob contenção de lock.

```go
acquireCtx, cancel := context.WithTimeout(ctx, cfg.AcquireTimeout)
conn, err := pool.Acquire(acquireCtx)
cancel()
if err != nil {
	return fmt.Errorf("adquirir conexão: %w", err) // vira 503 na borda
}
defer conn.Release()
err = WithTx(ctx, conn, func(tx pgx.Tx) error { ... }) // ctx original, sem o timeout de aquisição
```

## 2. Repositório e transações

- Queries sempre parametrizadas. O pgx faz cache de prepared statements.
- O repositório aceita uma interface `Querier` satisfeita pelo pool **e** por `pgx.Tx`, para reusar a mesma query dentro e fora de transação.
- Transação por helper `WithTx(ctx, db, fn)` com rollback garantido em erro ou panic. Isolamento explícito (padrão `READ COMMITTED`).
- Migrations: a ferramenta está no `architecture.md`. Migration é tarefa própria no `tasks.md`.

## 3. Concorrência sobre o mesmo registro

- **Lock pessimista em ordem determinística** (`SELECT ... FOR UPDATE` com ids em ordem crescente) evita deadlock quando uma operação toca várias linhas.
- **Idempotência:** `INSERT ... ON CONFLICT DO NOTHING`. Se nada foi inserido, outra execução venceu: releia o registro vencedor e resolva conforme a spec (replay ou conflito).
- Mutex em memória **não** protege dado persistente.

## 4. Desempenho

- Menos round-trips primeiro: `pgx.Batch` agrupa várias queries numa ida ao banco. Adote quando um `DPxx` pedir e a medição mostrar ganho.
- `COPY` (`CopyFrom`) para carga em massa.

## 5. Erros

- Timeout de aquisição, conexão recusada e códigos de indisponibilidade (`57P01`–`57P03`, classe `08`) → 503 `service_unavailable` com `Retry-After`.
- Violação de unicidade (`23505`) e de checagem → erro de domínio quando a spec define comportamento.
- Use `errors.As(err, &pgErr)` com `*pgconn.PgError`.

## 6. Lambda e muitas réplicas

- **Conexões = ambientes (ou réplicas) × pool por ambiente.** Em Lambda, o pool é mínimo (1–2 conexões, ou o limite de fan-out interno) e o acesso passa por **RDS Proxy**.
- Com RDS Proxy, confira o *pinning* de sessão causado por prepared statements e `SET`. Se ocorrer, ajuste o modo de execução de queries do pgx e registre a decisão.
- Limite a escala na origem (concorrência reservada, `MaximumConcurrency` do SQS) para não estourar as conexões do banco.

## 7. Testes

- Unitário: fake do `Querier`/repositório.
- Integração (`-tags integration`): banco de teste próprio (`infraestrutura-testes.md`), cobrindo transação, lock, `ON CONFLICT` e o invariante da spec com N operações simultâneas.
