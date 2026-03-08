# Test Case Template

> Шаблон для SA агента. Тест-кейсы генерируются автоматически после approve user story.

---

## [TC-XXX] Название тест-кейса

### Metadata
- **Related User Story:** US-XXX
- **Related API:** API-XXX
- **Type:** Functional / Integration / Security / Performance
- **Priority:** Critical / High / Medium / Low
- **Author:** [SA Agent / Auto]
- **Status:** [DRAFT] / [APPROVED]

### Preconditions
1. Описание начального состояния системы
2. Необходимые тестовые данные
3. Необходимые конфигурации

### Test Steps

| # | Действие | Входные данные | Ожидаемый результат |
|---|---------|---------------|-------------------|
| 1 | Step description | Input data | Expected output |
| 2 | Step description | Input data | Expected output |

### Expected Result
Итоговое ожидаемое состояние системы.

### Postconditions
- Что должно быть в БД
- Что должно быть в audit log
- Какие events/webhooks отправлены

### Test Data

```json
{
  "key": "value"
}
```

### Edge Cases
| # | Сценарий | Ожидаемый результат |
|---|---------|-------------------|
| 1 | Scenario | Expected |

### Constraints Verified
- [ ] C-XXX: Как проверяется

---

## Инструкция для агента

1. Минимум 1 happy path + 3 negative test cases на каждую user story
2. Security test: проверка auth, rate limits, input validation
3. Для endpoints с PAN: verify PAN NOT in response/logs (C-002)
4. Включайте test data в формате JSON
5. Postconditions обязательно включают audit log verification
6. Edge cases: boundary values, empty inputs, max lengths, special characters
