# Технологический стек

> Placeholder-документ. Заполняется заказчиком после выбора технологий. Агенты используют зафиксированный стек при генерации артефактов.

## Backend

| Компонент | Технология | Версия | Статус |
|-----------|-----------|--------|--------|
| Язык | _TBD_ | — | ⏳ Ожидает решения |
| Framework | _TBD_ | — | ⏳ Ожидает решения |
| ORM / Data Access | _TBD_ | — | ⏳ Ожидает решения |
| API Protocol | REST + gRPC (internal) | — | ✅ Зафиксировано |
| API Documentation | OpenAPI 3.1 | — | ✅ Зафиксировано |
| Message Broker | _TBD_ (Kafka / RabbitMQ) | — | ⏳ Ожидает решения |

## Database

| Компонент | Технология | Статус |
|-----------|-----------|--------|
| Primary DB | _TBD_ (PostgreSQL рекомендуется) | ⏳ Ожидает решения |
| Cache | _TBD_ (Redis рекомендуется) | ⏳ Ожидает решения |
| Search | _TBD_ | ⏳ Ожидает решения |
| Audit Log Storage | Append-only (immutable) | ✅ Принцип зафиксирован |

## Infrastructure

| Компонент | Технология | Статус |
|-----------|-----------|--------|
| Container Runtime | Docker | ✅ Зафиксировано |
| Orchestration | _TBD_ (Kubernetes рекомендуется) | ⏳ Ожидает решения |
| CI/CD | _TBD_ | ⏳ Ожидает решения |
| Cloud Provider | _TBD_ | ⏳ Ожидает решения |
| Monitoring | _TBD_ | ⏳ Ожидает решения |
| Log Aggregation | _TBD_ (ELK / Datadog) | ⏳ Ожидает решения |

## Security

| Компонент | Технология | Статус |
|-----------|-----------|--------|
| Tokenization Service | _TBD_ | ⏳ Ожидает решения |
| HSM | _TBD_ | ⏳ Ожидает решения |
| WAF | _TBD_ | ⏳ Ожидает решения |
| Secret Management | _TBD_ (Vault рекомендуется) | ⏳ Ожидает решения |
| TLS | TLS 1.2+ (1.3 preferred) | ✅ Зафиксировано |

## Integrations

| Интеграция | Протокол | Статус |
|-----------|----------|--------|
| Card Schemes (Visa/MC) | ISO 8583 / API | ✅ Зафиксировано |
| KYC/KYB Provider | REST API | ✅ Зафиксировано |
| Sanctions Screening | REST API | ✅ Зафиксировано |
| Transaction Monitoring | REST API / Event Stream | ✅ Зафиксировано |

## Architectural Principles (зафиксированы)

1. **Microservices** — каждый домен (onboarding, processing, disputes, settlement) = отдельный сервис
2. **Event-Driven** — межсервисное взаимодействие через события
3. **CQRS** — разделение read/write моделей для высоконагруженных сервисов
4. **CDE Isolation** — компоненты с PAN в изолированном сегменте (C-010)
5. **Idempotency** — все мутирующие операции идемпотентны (idempotency key)
6. **Audit-first** — каждая операция сначала пишет audit log, потом выполняет действие

---

> **Для агентов:** при генерации API спеков и диаграмм используйте зафиксированные решения (✅). Для TBD — используйте абстрактные названия (e.g., "Primary DB", "Message Broker") и добавляйте комментарий `<\!-- TBD: awaiting tech stack decision -->`.
