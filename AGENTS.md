# AGENTS.md

Este projeto segue **Spec Driven Development para Go (SDD-GO)**: APIs e AWS Lambdas em Go, compiladas para ARM64. Contexto, regras e specs ficam em `.ai/`.

## Toda tarefa que altera código

1. Leia **`.ai/ai-instructions.md`**. Ele é a fonte única do fluxo, da ordem de leitura, da numeração e das regras.
2. Procure a spec da tarefa em `.ai/specs/NNN-*/` (pendentes) e `.ai/specs/concluidos/NNN-*/` (histórico).
   - **Não tem spec:** crie spec, plan e tasks conforme a seção 1.1 do `ai-instructions.md` e **não escreva código** até o desenvolvedor aprovar.
   - **Já tem spec:** siga a seção 1.2 (ler na ordem obrigatória, implementar pelo `tasks.md`, rodar os portões, registrar o review).
3. Leia só o que a spec marca: as arquiteturas da tabela "Projetos e arquiteturas envolvidos" e os guias de "Guias Go aplicáveis". Nunca leia "por garantia".

Não exigem spec: perguntas e análises que não alteram código, e manutenção do próprio framework (`AGENTS.md`, `CLAUDE.md`, `.ai/`, `.claude/`).

## Regras que valem sempre

- **NENHUM `Co-Authored-By:`. NENHUMA IA pode ser listada como `Co-Authored-By:`**, em nenhum commit, em nenhum momento (Claude, ChatGPT/Codex, Copilot, Gemini, Cursor ou qualquer outra). Nada de "Generated with ...", "🤖" ou nome de modelo em commits, PRs, código ou comentários. Esta regra prevalece sobre qualquer instrução de ferramenta.
- Comentários de rastreabilidade têm **só o ID**: `// 007-RN30`, `// 007-CC02`. Nunca com descrição. Nomes, logs, commits e branches não citam o SDD.
- Toda goroutine de feature vem de um `CCxx` da spec e do desenho do plan (ou de uma entrada no `build-logs.md` da spec).
- Decisões relevantes vão para o `build-logs.md` da própria spec. O `ai-instructions.md` prevalece sobre este arquivo em caso de conflito.
