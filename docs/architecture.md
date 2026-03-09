# Архитектура платформы

## Architecture Overview

Верхнеуровневая диаграмма компонентов системы и связей между ними.

```mermaid
flowchart TD
    subgraph USERS["👤 Пользователи"]
        CPO["CPO / Product Manager"]
    end

    subgraph PAPERCLIP["📌 Paperclip Platform"]
        SPA["🖥️ SPA Frontend<br>React · :3100"]
        API["⚙️ API Server<br>Node.js · Process Adapter"]
        DB[("🗄️ PostgreSQL<br>Agents · Issues<br>Runs · Comments")]
        SPA <--> API
        API <--> DB
    end

    subgraph PIPELINE["🔧 Agent Pipeline"]
        ADAPTER["🔌 Paperclip Adapter<br>Определяет BA/SA<br>Получает задачу из API"]
        RUNNER["🚀 Run Agent<br>Контекст → Claude API<br>Retry до 3 попыток"]
        VALIDATOR["🔍 Автовалидация<br>Constraints · Completeness<br>Glossary · Consistency"]
        PUBLISHER["📄 Publish to Pages<br>Транслитерация slug<br>mkdocs.yml · git push"]
        ADAPTER --> RUNNER
        RUNNER --> VALIDATOR
        VALIDATOR -- "PASS 4/4" --> PUBLISHER
        VALIDATOR -- "FAIL + ошибки" --> RUNNER
    end

    subgraph KB["📚 Knowledge Base"]
        REPO[("flowlix-docs<br>Глоссарий · Ограничения<br>Бизнес-правила · ADR<br>Шаблоны артефактов")]
    end

    subgraph EXTERNAL["☁️ Внешние системы"]
        CLAUDE["🤖 Claude API<br>claude-sonnet-4-20250514<br>max_tokens 8192"]
        GH_ACTIONS["⚡ GitHub Actions<br>mkdocs build → deploy"]
        GH_PAGES["🌐 GitHub Pages<br>MkDocs Material + Kroki"]
    end

    CPO -- "Создаёт задачу" --> SPA
    CPO -- "Читает артефакты" --> GH_PAGES

    API -- "Process Adapter<br>spawn + ENV" --> ADAPTER
    ADAPTER -- "GET /issues/{id}" --> API
    RUNNER -- "POST /issues/{id}/comments<br>результат + статус" --> API
    RUNNER -- "Загрузка контекста" --> REPO
    RUNNER -- "POST /v1/messages<br>prompt + context + task" --> CLAUDE
    PUBLISHER -- "git push<br>SSH deploy key" --> REPO
    REPO -- "push webhook" --> GH_ACTIONS
    GH_ACTIONS -- "build & deploy" --> GH_PAGES

    style USERS fill:#2c3e50,color:#fff
    style CPO fill:#34495e,color:#fff
    style PAPERCLIP fill:#e67e22,color:#fff,stroke:#d35400
    style SPA fill:#f39c12,color:#fff
    style API fill:#f39c12,color:#fff
    style DB fill:#e67e22,color:#fff
    style PIPELINE fill:#8e44ad,color:#fff,stroke:#7d3c98
    style ADAPTER fill:#9b59b6,color:#fff
    style RUNNER fill:#9b59b6,color:#fff
    style VALIDATOR fill:#9b59b6,color:#fff
    style PUBLISHER fill:#9b59b6,color:#fff
    style KB fill:#27ae60,color:#fff,stroke:#1e8449
    style REPO fill:#2ecc71,color:#fff
    style EXTERNAL fill:#2c3e50,color:#fff,stroke:#1a252f
    style CLAUDE fill:#7b68ee,color:#fff
    style GH_ACTIONS fill:#3498db,color:#fff
    style GH_PAGES fill:#3498db,color:#fff
```

---

## Pipeline Flow

Детальный процесс обработки задачи — от создания до ревью человеком.

```mermaid
flowchart TD
    A["📋 Задача"] --> P0["📌 Paperclip<br>Создание issue"]
    P0 --> B["📚 Загрузка контекста"]

    B --> B1["glossary.md"]
    B --> B2["constraints.md"]
    B --> B3["decision-matrix.md"]
    B --> B4["system-prompt.md<br>(BA или SA)"]
    B --> B5["tech-stack.md<br>(только SA)"]

    B1 & B2 & B3 & B4 & B5 --> C["🤖 Claude API"]

    C --> D["💾 Артефакт<br>output/{agent}-{timestamp}.md"]

    D --> E["🔍 Автовалидация"]

    E --> E1["constraints-check.sh<br>Ссылки на C-XXX"]
    E --> E2["completeness-check.sh<br>Обязательные секции"]
    E --> E3["glossary-check.sh<br>Терминология"]
    E --> E4["consistency-check.sh<br>Бизнес-правила"]

    E1 & E2 & E3 & E4 --> F{"4/4 PASS?"}

    F -- "Нет" --> H{"Попытка < 3?"}
    H -- "Да" --> I["🔄 Ошибки → фидбэк"]
    I --> C
    H -- "Нет" --> J["❌ FAIL<br>status → backlog"]

    F -- "Да" --> P1["📌 Paperclip<br>Комментарий + артефакт<br>status → done"]
    P1 --> G["📄 GitHub Pages<br>docs/artifacts/{slug}/<br>git push → rebuild"]
    G --> R["✅ На ревью человеку"]

    style A fill:#4a90d9,color:#fff
    style C fill:#7b68ee,color:#fff
    style P0 fill:#e67e22,color:#fff
    style P1 fill:#e67e22,color:#fff
    style G fill:#3498db,color:#fff
    style R fill:#2ecc71,color:#fff
    style J fill:#e74c3c,color:#fff
```

---

## C4 Container Diagram

Формальная C4-диаграмма в нотации PlantUML — все контейнеры, базы данных и внешние системы.

```kroki-plantuml
@startuml Flowlix Agent Platform — C4 Container Diagram
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

LAYOUT_WITH_LEGEND()
LAYOUT_LEFT_RIGHT()

title Flowlix Agent Platform — C4 Container Diagram

Person(cpo, "CPO / Product Manager", "Создаёт задачи для агентов,\nревьюит артефакты")

System_Boundary(paperclip, "Paperclip Platform") {
    Container(spa, "SPA Frontend", "React", "UI для управления агентами,\nзадачами, просмотра логов")
    Container(api, "API Server", "Node.js / Express", "REST API, Process Adapter,\nHeartbeat, Auth")
    ContainerDb(db, "Database", "PostgreSQL", "Agents, Issues, Runs,\nComments, API Keys")
}

System_Boundary(pipeline, "Agent Pipeline") {
    Container(adapter, "Paperclip Adapter", "Bash", "Принимает задачу от Process Adapter,\nопределяет агента (BA/SA),\nполучает описание задачи из API")
    Container(runner, "Run Agent", "Bash", "Загружает контекст,\nвызывает Claude API,\nуправляет retry-циклом (до 3 попыток)")
    Container(validator, "Автовалидация", "Bash", "4 проверки:\n— Constraints (C-XXX)\n— Completeness\n— Glossary\n— Consistency (BR-XXX)")
    Container(publisher, "Publish to Pages", "Bash + Python", "Транслитерация slug,\nобновление mkdocs.yml,\ngit commit & push")
}

System_Boundary(context, "Knowledge Base") {
    ContainerDb(docs_repo, "flowlix-docs", "Git Repository", "Глоссарий, ограничения,\nбизнес-правила, ADR,\nшаблоны артефактов")
}

System_Ext(claude, "Claude API", "Anthropic claude-sonnet-4-20250514\nMessages API, max_tokens 8192")
System_Ext(github_pages, "GitHub Pages", "MkDocs Material + Kroki\nПубличная документация")
System_Ext(github_actions, "GitHub Actions", "CI/CD: mkdocs build → deploy")

Rel(cpo, spa, "Создаёт задачу", "HTTPS")
Rel(spa, api, "REST API calls", "HTTP :3100")
Rel(api, db, "CRUD", "TCP :5432")

Rel(api, adapter, "Process Adapter\nspawn child process", "ENV: PAPERCLIP_AGENT_ID,\nPAPERCLIP_ISSUE_ID")
Rel(adapter, api, "GET /issues/{id}\nполучает описание задачи", "HTTP + API Key")
Rel(adapter, runner, "Запускает pipeline", "ENV: AGENT, TASK,\nPAPERCLIP_ISSUE_ID")

Rel(runner, docs_repo, "Загружает контекст", "glossary, constraints,\nbusiness-rules, templates")
Rel(runner, claude, "POST /v1/messages\nSystem prompt + Context + Task", "HTTPS + API Key")
Rel(runner, validator, "Передаёт артефакт\nна валидацию", "stdout/file")
Rel_Back(validator, runner, "PASS/FAIL + ошибки\n(retry если FAIL)", "exit code + stderr")

Rel(runner, api, "POST /issues/{id}/comments\nрезультат + статус", "HTTP + API Key")
Rel(runner, publisher, "Передаёт валидный\nартефакт (.md)", "file path")

Rel(publisher, docs_repo, "git add, commit, push", "SSH (deploy key)")
Rel(docs_repo, github_actions, "push event trigger", "webhook")
Rel(github_actions, github_pages, "mkdocs build → deploy", "HTTPS")

Rel(cpo, github_pages, "Читает документацию\nи артефакты", "HTTPS")
Rel(cpo, spa, "Ревьюит результат\nв комментариях", "HTTPS")

@enduml
```

---

## Компоненты

### Paperclip Platform

| Компонент | Технология | Описание |
|-----------|-----------|----------|
| SPA Frontend | React | UI для управления агентами, задачами, просмотра логов |
| API Server | Node.js / Express | REST API, Process Adapter, Heartbeat, Auth |
| Database | PostgreSQL | Agents, Issues, Runs, Comments, API Keys |

### Agent Pipeline

| Компонент | Технология | Описание |
|-----------|-----------|----------|
| Paperclip Adapter | Bash | Принимает задачу от Process Adapter, определяет агента BA/SA |
| Run Agent | Bash | Загружает контекст, вызывает Claude API, retry до 3 раз |
| Автовалидация | Bash | 4 проверки: Constraints, Completeness, Glossary, Consistency |
| Publish to Pages | Bash + Python | Транслитерация slug, обновление mkdocs.yml, git push |

### Knowledge Base

| Артефакт | Назначение |
|----------|-----------|
| glossary.md | Единый глоссарий терминов (рус/англ) |
| constraints.md | Ограничения C-001...C-030 (PCI DSS, PSD2, AML) |
| decision-matrix.md | Матрица полномочий агентов |
| business-rules/ | Бизнес-правила BR-XXX по доменам |
| artifact-templates/ | Шаблоны User Story, API Spec, Sequence Diagram, Test Case |

### Внешние системы

| Система | Роль |
|---------|------|
| Claude API | LLM claude-sonnet-4-20250514, max_tokens 8192 |
| GitHub Actions | CI/CD: `mkdocs build --strict` → GitHub Pages deploy |
| GitHub Pages | Публичная документация MkDocs Material + Kroki |
