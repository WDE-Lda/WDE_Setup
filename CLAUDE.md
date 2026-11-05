# WDE_Setup (WDE_Setup)

Script publico (`setup.ps1`) que prepara um PC novo da WDE: Git, GitHub CLI, login no GitHub e GitWorkflow.

## Comandos
- `Invoke-ScriptAnalyzer -Path setup.ps1` e `Invoke-Pester tests` (Pester 5) antes de dizer que terminaste.

## Onde estao as coisas
- `setup.ps1` o script  - `tests/` testes Pester (verificacao do .sha256)

## Neste repositorio
- Sem Check, Dependabot, SECURITY.md nem Release, por decisao: quem o usa corre o `main`.
- `setup.ps1` e ASCII e corre em PS 5.1 e 7; confirma o `.sha256` do GitWorkflow antes de instalar.
- Nunca commit em `main`: alteracoes por dev/v + PR (GitWorkflow).
