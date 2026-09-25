# Padrões de concorrência: código de referência

> **Leitura sob demanda, na implementação.** Leia **só** as seções dos padrões (`P1`–`P10`) escolhidos no "Desenho de concorrência" do `plan.md`. A escolha do padrão e as regras estão em `concorrencia.md`.

## P1. Fan-out tudo-ou-nada (N pequeno e fixo): `errgroup.WithContext`

```go
func (s *Service) Enrich(ctx context.Context, order Order) (Enriched, error) {
	var (
		customer Customer
		stock    Stock
		price    Price
	)

	// 007-CC01
	g, ctx := errgroup.WithContext(ctx)
	g.Go(func() error {
		var err error
		customer, err = s.customers.Get(ctx, order.CustomerID)
		return err
	})
	g.Go(func() error {
		var err error
		stock, err = s.inventory.Check(ctx, order.Items)
		return err
	})
	g.Go(func() error {
		var err error
		price, err = s.pricing.Quote(ctx, order)
		return err
	})
	if err := g.Wait(); err != nil {
		return Enriched{}, fmt.Errorf("enriquecer pedido %s: %w", order.ID, err)
	}
	return Enriched{Customer: customer, Stock: stock, Price: price}, nil
}
```

Cada goroutine escreve na **sua** variável e a leitura é depois de `Wait()`: sem mutex, sem race. O primeiro erro cancela o `ctx` das outras.

## P2. Fan-out limitado, melhor esforço (N variável): `errgroup.Group` + `SetLimit`

```go
func (p *Processor) ProcessAll(ctx context.Context, items []Item) []error {
	errs := make([]error, len(items)) // um slot por item: sem mutex

	// 007-CC02
	var g errgroup.Group
	g.SetLimit(p.maxConcurrency) // da config, derivado da capacidade downstream
	for i, item := range items {
		g.Go(func() error {
			errs[i] = p.process(ctx, item)
			return nil // não cancela os demais
		})
	}
	_ = g.Wait()
	return errs
}
```

Go ≥ 1.22: variáveis do `for` são por iteração; capturar `i` e `item` é seguro.

## P3. Worker pool sobre canal (fluxo contínuo ou tamanho desconhecido)

```go
func RunWorkers(ctx context.Context, jobs <-chan Job, workers int, handle func(context.Context, Job) error) error {
	g, ctx := errgroup.WithContext(ctx)
	for range workers {
		g.Go(func() error {
			for {
				select {
				case <-ctx.Done():
					return ctx.Err()
				case job, ok := <-jobs:
					if !ok {
						return nil // produtor fechou o canal: fim normal
					}
					if err := handle(ctx, job); err != nil {
						return err
					}
				}
			}
		})
	}
	return g.Wait()
}
```

## P4. Pipeline por estágios

```go
func (imp *Importer) Import(ctx context.Context, rows [][]byte) error {
	g, ctx := errgroup.WithContext(ctx)
	records := make(chan Record, 64) // buffer = amortecedor entre estágios

	// 012-CC01: um produtor, que fecha o canal
	g.Go(func() error {
		defer close(records)
		for _, raw := range rows {
			rec, err := parseRecord(raw)
			if err != nil {
				return err
			}
			select {
			case records <- rec:
			case <-ctx.Done():
				return ctx.Err()
			}
		}
		return nil
	})

	// 012-CC02: N gravadores, limitado pelo pool do banco
	for range imp.writers {
		g.Go(func() error {
			for rec := range records {
				if err := imp.repo.Save(ctx, rec); err != nil {
					return err
				}
			}
			return nil
		})
	}
	return g.Wait()
}
```

Se um gravador falha, o `ctx` é cancelado e o produtor sai pelo `select`: nenhuma goroutine fica presa.

## P5. Particionamento por chave (ordem na chave, paralelo entre chaves)

```go
func processByKey(ctx context.Context, msgs []Message, limit int, handle func(context.Context, Message) error) map[string]error {
	groups := make(map[string][]Message)
	var keys []string
	for _, m := range msgs {
		if _, ok := groups[m.Key]; !ok {
			keys = append(keys, m.Key)
		}
		groups[m.Key] = append(groups[m.Key], m) // preserva a ordem dentro da chave
	}

	results := make([]error, len(keys))
	var g errgroup.Group
	g.SetLimit(limit)
	for i, key := range keys {
		g.Go(func() error {
			for _, m := range groups[key] {
				if err := handle(ctx, m); err != nil {
					results[i] = err
					return nil // para ESTA chave; as outras seguem
				}
			}
			return nil
		})
	}
	_ = g.Wait()

	failed := make(map[string]error)
	for i, key := range keys {
		if results[i] != nil {
			failed[key] = results[i]
		}
	}
	return failed
}
```

## P6. Semáforo global (limite compartilhado entre requisições)

```go
type Limiter struct{ slots chan struct{} }

func NewLimiter(n int) *Limiter { return &Limiter{slots: make(chan struct{}, n)} }

func (l *Limiter) Do(ctx context.Context, fn func(context.Context) error) error {
	select {
	case l.slots <- struct{}{}:
	case <-ctx.Done():
		return ctx.Err() // a espera respeita o prazo do chamador
	}
	defer func() { <-l.slots }()
	return fn(ctx)
}
```

Pesos diferentes por operação: `golang.org/x/sync/semaphore`. Limite de **taxa** (req/s) em vez de simultaneidade: `golang.org/x/time/rate`.

## P7. Deduplicação de chamadas simultâneas: `singleflight`

```go
v, err, _ := s.flight.Do(key, func() (any, error) {
	return s.loadFromOrigin(ctx, key)
})
```

A função roda com o `ctx` de quem chegou primeiro; se ele cancelar, todos recebem o erro. Quando isso importa, use `context.WithoutCancel(ctx)` + `context.WithTimeout` próprio dentro da função e registre a decisão.

## P8. Goroutine de longa duração (só em container, nunca em Lambda)

```go
func run(ctx context.Context) error {
	ctx, stop := signal.NotifyContext(ctx, syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	var wg sync.WaitGroup
	wg.Go(func() { consumer.Run(ctx) }) // Go ≥ 1.25

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	err := server.Shutdown(shutdownCtx)
	wg.Wait() // só sai depois que o consumidor terminou
	return err
}
```

## P9. Estado compartilhado em memória

Em ordem de preferência:

1. **Confinamento:** cada goroutine escreve só no que é dela (slot de slice, variável própria); leitura após o `Wait`.
2. **Canal:** passe a posse do dado em vez de compartilhá-lo.
3. **`sync.Mutex` / `RWMutex`:** seção crítica curta, nunca segurando lock durante I/O.
4. **`sync/atomic`** (`atomic.Int64`, `atomic.Pointer[T]`): contadores, troca de configuração.
5. **`sync.OnceValue` / `OnceValues`:** inicialização preguiçosa (cliente pouco usado).
6. **`sync.Map`:** só para chaves estáveis com muita leitura; na dúvida, `map` + `Mutex`.

Dado **persistente** (saldo, estoque) não se protege com mutex: há várias instâncias. Use o banco (ver `dados-postgres.md` / `dados-dynamodb.md`).

## P10. Recuperar panic em goroutine filha (CONC-06)

```go
g.Go(func() (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("panic ao processar item %s: %v", item.ID, r)
		}
	}()
	return p.process(ctx, item)
})
```

Use quando a goroutine chama código de terceiros ou faz parse de entrada externa. Confira se a versão de `golang.org/x/sync` usada já propaga panics no `errgroup`; na dúvida, recupere explicitamente.
