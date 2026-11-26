# Reference

# 2026-08-03 - Refatoração para o Antigravity e Desvinculação de `refs/`
- Removidas dependências das skills legadas em `refs/` (`refs/grilling`, `refs/prototype`, `refs/research` e `refs/setup-matt-pocock-skills`).
- Definido o GitHub CLI (`gh issue ...`) como padrão principal de rastreamento de tickets, com fallback automático para Markdown local em `.agents/wayfinder/maps/`.
- Substituídas as sessões de `/grilling` por entrevistas nativas via `ask_question` e o comando nativo `/grill-me`.
- Generalizado o tipo de ticket `Prototype` para Proof of Concept (POC) científica (Python, Slurm/HPC via `/cluster-ccdb`, LaTeX, etc.).
- Conectado o tipo de ticket `Research` à nova skill oficial `.agents/skills/research/`.
