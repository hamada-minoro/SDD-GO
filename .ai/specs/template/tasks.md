# Tasks: Nome da Feature

## Preparação

> Leia **somente** os arquivos desta lista, na ordem de `.ai/ai-instructions.md` (seção 2). Um item por arquitetura da tabela da spec e por guia condicional marcado, com o caminho real.

- [ ] Ler .ai/ai-instructions.md
- [ ] Ler .ai/architecture.md (mapa do ecossistema)
- [ ] Ler .ai/infraestrutura-testes.md
- [ ] Ler .ai/go/idiomatico.md
- [ ] Ler .ai/go/concorrencia.md
- [ ] Ler .ai/go/testes.md
- [ ] Ler spec.md
- [ ] Ler .ai/architecture-pasta-do-projeto.md
- [ ] Ler .ai/go/<guia condicional marcado na spec>.md
- [ ] Ler plan.md
- [ ] Confirmar leitura do build-logs.md desta feature (decisões anteriores)
- [ ] Conferir `go version` × diretiva `go` do `go.mod` (sem troca de toolchain)

## Tipos e regras puras

- [ ] Criar/alterar tipos de domínio e erros de domínio
- [ ] Implementar parse/validação como funções puras
- [ ] Testes table-driven das funções puras (com IDs RN/CA)

## Persistência

- [ ] Migration / modelagem de chaves
- [ ] Repositório (queries parametrizadas, `ctx` em tudo)
- [ ] Transação, ordem de lock e idempotência conforme o plan
- [ ] Testes de integração do repositório (`-tags integration`)

## Service

- [ ] Regra de negócio no service (sem HTTP/Lambda)
- [ ] Mapeamento de erros de domínio
- [ ] Testes do service com fakes

## Concorrência

> Uma tarefa por `CCxx` do "Desenho de concorrência" do `plan.md`.

- [ ] Ler em .ai/go/concorrencia-padroes.md só as seções dos padrões do desenho (ex.: P1, P5)
- [ ] CC01: implementar <padrão> em <função>, com limite <origem> e comentário `// NNN-CC01`
- [ ] CC01: teste de <cancelamento/limite/falha parcial/ordem>
- [ ] `goleak.VerifyTestMain` nos pacotes com goroutines novas
- [ ] `go test -race -count=50 -cpu=1,2,4` nos testes de concorrência

## Borda (HTTP ou Lambda)

- [ ] Handler fino: decode → service → resposta
- [ ] Erros do contrato / falha parcial (`BatchItemFailures`)
- [ ] Prazo e margem de segurança (Lambda)
- [ ] Fixtures em `testdata/` e testes da borda (httptest / evento)
- [ ] Fuzz do parser de entrada externa

## Wiring, configuração e deploy

- [ ] Wiring no `cmd/<binario>/main.go` (clientes e pools criados uma vez)
- [ ] Variáveis de ambiente novas com validação na subida
- [ ] IaC: arquitetura `arm64`, memória, timeout, concorrência, DLQ, IAM mínimo
- [ ] Observabilidade: logs, métricas e alarmes do plan

## Desempenho

> Só se a spec tiver `DPxx`.

- [ ] Benchmarks das funções quentes (`b.Loop`, `-benchmem`)
- [ ] Medição de cada DPxx conforme o "Plano de medição" do plan
- [ ] Resultados (com `benchstat`, quando micro) registrados em tests.md

## Validação

- [ ] Portões 1–8 de `.ai/go/testes.md` (seção 1) passando, resultado registrado em tests.md
- [ ] Conferir regras de negócio, CC, DP, permissões, critérios de aceite e casos de erro

## Documentação

- [ ] Atualizar spec.md/plan.md, se necessário
- [ ] Atualizar README/API/CHANGELOG do projeto, se necessário
- [ ] Atualizar .ai/infraestrutura-testes.md, se a infra de testes mudou
- [ ] Confirmar que toda decisão relevante está registrada no build-logs.md desta feature
