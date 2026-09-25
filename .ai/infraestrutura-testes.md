# Infraestrutura local de testes — referência verificada

> Referência central sobre o ambiente local de testes do projeto, para
> desenvolvedores e agentes executores de spec. **Leia antes de tentar rodar
> testes de integração/E2E.** Se uma pendência de teste cair em uma limitação
> já listada aqui, cite este arquivo no `review.md` da spec e siga em frente
> — não re-investigue nem re-documente do zero. Se descobrir uma limitação de
> ambiente **nova** (não específica de uma spec), acrescente-a aqui em nova
> seção, sem sobrescrever as existentes.
>
> Quando uma feature **muda ou melhora** a infraestrutura de testes (serviço,
> container ou porta nova, outro comando para subir a stack, seed, variável
> de ambiente, script ou ferramenta de teste), quem a implementou atualiza a
> seção correspondente aqui, só com o que verificou na prática. Limitação
> resolvida é marcada como resolvida, com data, e não apagada.
>
> Preencha este arquivo conforme o ambiente local for sendo verificado na
> prática (a Fase 0 de setup pode gerar a primeira versão). Atualize a data
> abaixo a cada verificação real.
>
> Última verificação prática: **AAAA-MM-DD**.

## Toolchain Go e ferramentas

| Ferramenta | Versão verificada | Como conferir | Como instalar, se faltar |
|---|---|---|---|
| Go | | `go version` | https://go.dev/dl/ |
| golangci-lint (ou staticcheck) | | `golangci-lint version` | conforme a doc da ferramenta |
| govulncheck | | `govulncheck -version` | `go install golang.org/x/vuln/cmd/govulncheck@latest` |
| benchstat | | `benchstat -h` | `go install golang.org/x/perf/cmd/benchstat@latest` |
| Docker / buildx | | `docker buildx version` | |
| IaC (SAM / CDK / Terraform) | | | |

Notas:

- Rode as ferramentas com `GOTOOLCHAIN=local` para não trocar de toolchain silenciosamente.
- A diretiva `go` do `go.mod` não pode ser maior que a versão instalada. Se for, registre como limitação em vez de atualizar o `go.mod`.
- Race detector: registre aqui se ele exige `CGO_ENABLED=1`/compilador C nesta máquina, e se funciona.

## Comandos de teste

Os comandos padrão são os portões de `.ai/go/testes.md` (seção 1). Registre aqui **só** o que é específico deste ambiente:

| O quê | Pré-requisito ou diferença neste ambiente |
|---|---|
| Integração (`-tags integration`) | ex.: stack local de pé (abaixo), variável `DATABASE_URL_TEST` |
| Race detector | ex.: exige `gcc` instalado |
| Benchmarks | ex.: máquina ociosa, `GOMAXPROCS` fixo |
| `govulncheck` | ex.: precisa de rede |

## Stack local — serviços, portas e como verificar

| Serviço | Onde roda | Porta | Verificação rápida |
|---|---|---|---|
| ex.: API Go | processo local (`go run ./cmd/api`) | 0000 | `curl -s -o /dev/null -w "%{http_code}" localhost:0000/health` → 200 |
| ex.: Postgres | container `nome-do-container` | 0000 | `docker ps`, `pg_isready -h localhost -p 0000` |
| ex.: DynamoDB Local / LocalStack | container | 0000 | |

Notas importantes:

- **Não assuma portas padrão** — confira `.env`/compose do repositório e registre aqui o valor real (portas comuns costumam estar ocupadas por outros projetos na máquina).
- Registre credenciais de desenvolvimento local (nunca de produção) apenas
  se forem necessárias para subir a stack de teste.
- Testes de integração usam banco/tabela **próprios de teste**, nunca os de desenvolvimento manual.

## Como subir a stack local

Descreva os comandos, na ordem, para colocar o ambiente de pé (docker
compose, migrations, seeds, variáveis obrigatórias).

## Lambda localmente

Descreva, se o projeto usar: como invocar a função localmente (SAM CLI `sam local invoke`, LocalStack, ou só testes Go chamando o handler com eventos de `testdata/`), e como rodar a imagem/binário ARM64 localmente (emulação QEMU via `docker run --platform linux/arm64`, se disponível).

## Testes de carga

Descreva, se o projeto tiver: ferramenta (Locust, k6, vegeta), onde ficam os cenários, como rodar, limites de CPU/memória usados e onde ficam os resultados.

## Limitações conhecidas

Liste aqui, em seções datadas, as limitações verificadas do ambiente local
(ex.: serviço externo sem sandbox, teste E2E que depende de credencial
inexistente, race detector indisponível sem compilador C, emulação ARM64
lenta demais para carga). Cada entrada
deve dizer: qual é a limitação, como foi verificada e o que fazer a respeito
(contornar, pular com pendência citada no `review.md`, etc.).
