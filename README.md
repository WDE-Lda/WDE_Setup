# WDE_Setup

Launcher publico para preparar um PC novo da WDE. Nao contem codigo nem segredos da WDE: os repositorios
(GitWorkflow, WDE_AI) sao privados, por isso o unico passo manual e entrar no GitHub no browser.

```powershell
irm https://raw.githubusercontent.com/WDE-Lda/WDE_Setup/main/setup.ps1 | iex
```

Instala Git e GitHub CLI (winget), pede o login no GitHub, instala o GitWorkflow e corre o `task setup`
(ferramentas, plugins Claude Code e configuracao do Git).

Como publicar: `task start-dev` / `task open-pr` / `task merge` com o [GitWorkflow](https://github.com/WDE-Lda/GitWorkflow),
sem Release (quem usa o script corre o `main`).
