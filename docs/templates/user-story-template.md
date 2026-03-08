# User Story Template

> Шаблон для BA агента. Каждая user story должна следовать этой структуре.

---

## [US-XXX] Название

### Metadata
- **Epic:** [Название эпика]
- **Priority:** [Critical / High / Medium / Low]
- **Story Points:** [1 / 2 / 3 / 5 / 8 / 13]
- **Sprint:** [TBD]
- **Author:** [BA Agent / Human]
- **Status:** [DRAFT] / [APPROVED] / [IN PROGRESS] / [DONE]

### User Story
**As a** [роль],
**I want to** [действие],
**So that** [бизнес-ценность].

### Context
- Краткое описание бизнес-контекста
- Связь с другими stories и features
- Ссылки на business rules: BR-XXX

### Acceptance Criteria

#### Happy Path
```gherkin
Given [предусловие]
When [действие]
Then [ожидаемый результат]
```

#### Edge Cases
```gherkin
Given [граничное условие]
When [действие]
Then [ожидаемый результат]
```

#### Error Scenarios
```gherkin
Given [ошибочное условие]
When [действие]
Then [обработка ошибки]
```

### Constraints
- [ ] C-XXX: [название constraint и как он учтён]

### Dependencies
- Upstream: [от чего зависит эта story]
- Downstream: [что зависит от этой story]

### Technical Notes
_Опционально. Заметки для SA/Dev команды._

### Test Scenarios
_Ссылка на тест-кейсы (генерируются автоматически после approve)._

---

## Инструкция для агента

1. **ОБЯЗАТЕЛЬНО** заполните все секции. Пустая секция = невалидная story
2. Минимум 1 happy path + 2 edge cases + 2 error scenarios в Acceptance Criteria
3. Ссылайтесь на конкретные BR-XXX и C-XXX
4. Используйте термины ТОЛЬКО из glossary.md
5. Если не хватает контекста — добавьте секцию "Open Questions" и СПРОСИТЕ
6. Story points: 1-3 = простые CRUD, 5 = с бизнес-логикой, 8+ = сложная интеграция/flow
7. Пометьте [DRAFT] в статусе — финальное решение за PO
