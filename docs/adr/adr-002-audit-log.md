# ADR-002: Архитектура Audit Log — Append-Only Event Store

## Status
Accepted

## Date
2026-03-08

## Context
PCI DSS v4.0 (Requirement 10) и AMLD5 требуют полного audit trail для всех операций с платёжными данными. Необходимо выбрать архитектуру хранения audit логов, обеспечивающую неизменяемость, высокую производительность записи и эффективный поиск.

**Constraints затронуты:** C-002 (PAN в логах), C-007 (GDPR retention), C-009 (Audit trail), C-010 (CDE isolation)

## Decision Drivers
- Неизменяемость логов (PCI DSS Requirement 10.3)
- Высокая пропускная способность записи (каждая транзакция = audit entry)
- Поиск по временным диапазонам, actor, entity, action
- Retention: 1 год онлайн + 5 лет архив (C-009)
- PAN, CVV, пароли НИКОГДА не попадают в лог (C-002)

## Considered Options

### Option A: Реляционная таблица с soft-delete protection
- PostgreSQL таблица с triggers, предотвращающими UPDATE/DELETE
- **Плюсы:** Простота, SQL-запросы, транзакционность
- **Минусы:** Triggers обходимы superuser-ом, performance при высоком write volume, сложность partitioning

### Option B: Append-Only Event Store (dedicated service)
- Отдельный микросервис с append-only storage
- Write API: только INSERT, без UPDATE/DELETE endpoints
- Данные подписываются hash chain (каждая запись содержит hash предыдущей)
- **Плюсы:** Криптографическая неизменяемость, независимое масштабирование, чёткая граница CDE
- **Минусы:** Дополнительный сервис, сложность hash chain при recovery

### Option C: Managed solution (AWS CloudTrail / Azure Monitor)
- **Плюсы:** Managed, compliance-certified
- **Минусы:** Vendor lock-in, ограниченная кастомизация, стоимость при высоком volume

## Decision
**Выбрана Option B: Append-Only Event Store** как отдельный микросервис.

Обоснование:
1. Криптографическая неизменяемость (hash chain) превышает требования PCI DSS
2. Отдельный сервис = чёткая граница CDE (C-010)
3. Независимое масштабирование write path
4. Не зависим от cloud provider

## Consequences

### Positive
- Гарантия неизменяемости через hash chain
- Audit log сервис вне CDE (не обрабатывает PAN — получает только маскированные данные)
- Независимое масштабирование и retention management
- Упрощает PCI DSS аудит (отдельный scope)

### Negative
- Дополнительный микросервис (operational overhead)
- Hash chain rebuild при disaster recovery
- Eventual consistency (async write)

### Risks
- Потеря записей при сбое async pipeline → mitigation: at-least-once delivery + deduplication
- Hash chain corruption → mitigation: periodic integrity check job
- Storage growth → mitigation: tiered storage (hot 1Y → cold 5Y → delete)

## Schema (высокоуровневая)

```
AuditEntry {
  id: UUID
  timestamp: ISO 8601
  previous_hash: SHA-256
  entry_hash: SHA-256
  actor_id: string        // user/system ID
  actor_type: enum        // USER, SYSTEM, AGENT
  action: string          // e.g., "merchant.create", "transaction.authorize"
  entity_type: string     // e.g., "Merchant", "Transaction"
  entity_id: string
  changes: JSON           // before/after (masked, no PAN/CVV)
  ip_address: string
  user_agent: string
  correlation_id: UUID    // для трейсинга цепочки действий
  metadata: JSON
}
```

## Related
- Constraints: C-002, C-007, C-009, C-010
- Business Rules: —
- ADRs: ADR-001 (PayFac model → high volume writes)
