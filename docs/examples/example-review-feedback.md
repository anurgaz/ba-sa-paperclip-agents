# Пример: Review Feedback

> Эталонный пример обратной связи при ревью артефакта агента.

---

## Review: US-001 — Онбординг нового мерчанта через API

### Reviewer: Product Owner
### Date: 2026-03-08
### Decision: **APPROVED with comments**

---

### Passed Checks

- [x] Все обязательные секции заполнены
- [x] Acceptance criteria покрывают happy path + edge cases + errors
- [x] Ссылки на constraints корректны (C-002, C-003, C-004, C-007, C-008, C-009, C-012)
- [x] Ссылки на business rules корректны (BR-ONB-001 — BR-ONB-005)
- [x] Термины соответствуют glossary.md
- [x] Story points адекватны сложности (8 — сложная интеграция)

### Comments

1. **Edge Case 2 (UBO <25%):** Добавить acceptance criteria для случая, когда ЕДИНСТВЕННЫЙ UBO имеет долю <25% (нет UBO >=25%). Система должна вернуть 422.

2. **Webhook URL:** Уточнить — webhook_url обязателен или опционален при создании? Если опционален, как мерчант получает notifications без webhook? (Dashboard only?)

3. **Expected monthly volume:** Добавить upper limit. Что если мерчант указывает €100M/month? Нужна ли ручная проверка?

### Action Items
- [ ] BA Agent: Добавить edge case для отсутствия UBO >=25%
- [ ] BA Agent: Уточнить обязательность webhook_url
- [ ] PO: Определить upper limit для expected_monthly_volume

### Validation Report

```
=== Validation Report ===
Artifact: docs/examples/example-user-story.md
Date: 2026-03-08T10:30:00Z

[PASS] constraints-check: 7/7 constraints referenced
[PASS] completeness-check: All required sections present
[PASS] glossary-check: All terms match glossary.md
[PASS] consistency-check: No conflicts with business rules

Result: PASSED (4/4 checks)
```

---

> **Для агентов:** при получении feedback с APPROVED with comments — исправьте comments и пересоздайте артефакт. При REJECTED — проанализируйте причины, исправьте и отправьте на повторный review.
