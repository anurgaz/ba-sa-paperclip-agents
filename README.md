# AI-native инфраструктура документации для BA/SA агентов платёжной B2B процессинговой платформы

**GitHub Pages:** [anurgaz.github.io/ba-sa-paperclip-agents](https://anurgaz.github.io/ba-sa-paperclip-agents/)
**Paperclip UI:** [159.69.28.60:3100](http://159.69.28.60:3100)

---

## Architecture Overview

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

## Pipeline Flow

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

## Структура репозитория

```
flowlix-docs/
├── docs/                   # Документация и контекст
│   ├── context/            # Глоссарий, ограничения, decision matrix, tech stack
│   ├── adr/                # Architecture Decision Records
│   ├── business-rules/     # Бизнес-правила (онбординг, транзакции, споры, AML)
│   ├── data/               # Data dictionary, SLA metrics, KPI
│   ├── integrations/       # Интеграции (Visa/MC, KYC, TMS)
│   ├── artifact-templates/ # Шаблоны артефактов (User Story, API Spec, etc.)
│   ├── examples/           # Эталонные примеры (few-shot)
│   └── artifacts/          # Сгенерированные артефакты по фичам
├── agents/                 # Профили и system prompts агентов
│   ├── ba-agent/           # Business Analyst агент
│   └── sa-agent/           # System Analyst агент
├── validation/             # Скрипты автовалидации (4 проверки)
├── pipeline/               # Pipeline: run-agent, adapter, publish
└── .github/workflows/      # CI/CD (GitHub Pages deploy)
```

## Компоненты

### Paperclip Platform

| Компонент | Технология | Описание |
|-----------|-----------|----------|
| SPA Frontend | React | UI для управления агентами, задачами, логами |
| API Server | Node.js / Express | REST API, Process Adapter, Heartbeat, Auth |
| Database | PostgreSQL | Agents, Issues, Runs, Comments, API Keys |

### Agent Pipeline

| Скрипт | Описание |
|--------|----------|
| `pipeline/paperclip-adapter.sh` | Принимает задачу от Paperclip Process Adapter, определяет BA/SA |
| `pipeline/run-agent.sh` | Загружает контекст, Claude API, валидация, retry до 3 раз |
| `pipeline/publish-to-pages.sh` | Публикация артефакта в GitHub Pages (транслитерация, mkdocs.yml) |
| `validation/validate.sh` | Оркестратор 4 проверок валидации |

### Автовалидация (4 проверки)

| Проверка | Файл | Что проверяет |
|----------|------|---------------|
| Constraints | `constraints-check.sh` | Ссылки на C-XXX из constraints.md |
| Completeness | `completeness-check.sh` | Обязательные секции для типа артефакта |
| Glossary | `glossary-check.sh` | Использование терминов из глоссария |
| Consistency | `consistency-check.sh` | Ссылки на BR-XXX бизнес-правила |

### Внешние системы

| Система | Роль |
|---------|------|
| Claude API | `claude-sonnet-4-20250514`, Messages API, max_tokens 8192 |
| GitHub Actions | CI/CD: `mkdocs build --strict` → GitHub Pages deploy |
| GitHub Pages | MkDocs Material + Kroki (PlantUML rendering) |

## Быстрый старт

### Через Paperclip UI (рекомендуется)

1. Открыть [Paperclip UI](http://159.69.28.60:3100)
2. Создать задачу и назначить на BA Agent или SA Agent
3. Агент автоматически выполнит pipeline
4. Результат: комментарий в задаче + публикация в [GitHub Pages](https://anurgaz.github.io/ba-sa-paperclip-agents/)

### Через CLI

```bash
# BA Agent — User Story
./pipeline/run-agent.sh \
  --agent ba \
  --task "Создай user story для онбординга нового мерчанта через API"

# SA Agent — API Specification
./pipeline/run-agent.sh \
  --agent sa \
  --task "Создай API спецификацию для POST /api/v1/merchants"

# Валидация артефакта
./validation/validate.sh output/ba-20260309-120000.md
```

## Decision Matrix

| Действие | Уровень | Апрувер |
|----------|---------|---------|
| User Story | suggest+approve | PO |
| API Spec | suggest+approve | Tech Lead |
| Test Cases | auto | — |
| Business Rules | manual only | PO + Compliance |
| AML/Compliance | manual only | MLRO |
