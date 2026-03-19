# Пример: User Story — Создание мерчанта через API

> Эталонный пример для few-shot. BA агент должен генерировать артефакты этого уровня качества.

---

## [US-001] Онбординг нового мерчанта через API

### Metadata
- **Epic:** Merchant Onboarding
- **Priority:** Critical
- **Story Points:** 8
- **Sprint:** TBD
- **Author:** BA Agent
- **Status:** [DRAFT]

### User Story
**As an** Integration Partner,
**I want to** зарегистрировать нового мерчанта через REST API, отправив данные компании и UBO,
**So that** мерчант может начать принимать карточные платежи через платформу Payment Service в течение 48 часов.

### Context
- Payment Service работает по PayFac модели (ADR-001): мерчанты регистрируются как суб-мерчанты
- При регистрации автоматически запускается KYB проверка компании и KYC проверка UBO
- SLA на онбординг: ≤48ч для auto-approve, ≤5 рабочих дней для manual review (C-008)
- Все UBO с долей ≥25% должны быть идентифицированы (C-003)
- Связанные business rules: BR-ONB-001, BR-ONB-002, BR-ONB-003, BR-ONB-004, BR-ONB-005

### Acceptance Criteria

#### Happy Path
```gherkin
Given Integration Partner имеет валидный API token с scope "merchants:write"
  And данные мерчанта корректны и полны
  And указан минимум 1 UBO с долей ≥25%
When Integration Partner отправляет POST /api/v1/merchants с данными компании и UBO
Then система возвращает 201 Created с merchant_id и статусом PENDING
  And система инициирует асинхронную KYB проверку (BR-ONB-002)
  And система инициирует KYC проверку для каждого UBO (BR-ONB-003)
  And webhook merchant.created отправляется на URL мерчанта
  And запись создаётся в audit log (C-009)
```

#### Edge Case 1: Несколько UBO
```gherkin
Given данные мерчанта содержат 3 UBO с долями 40%, 30%, 30%
When Integration Partner отправляет POST /api/v1/merchants
Then система создаёт мерчанта и инициирует KYC для всех 3 UBO параллельно
  And мерчант переходит в ACTIVE только после CLEAR для всех UBO
```

#### Edge Case 2: UBO с долей менее 25%
```gherkin
Given данные мерчанта содержат 2 UBO: 60% и 15%
When Integration Partner отправляет POST /api/v1/merchants
Then система создаёт мерчанта
  And KYC инициируется только для UBO с 60%
  And UBO с 15% сохраняется, но не проходит обязательный KYC
  And если сумма идентифицированных UBO < 75%, система запрашивает уточнение структуры
```

#### Edge Case 3: High-risk MCC
```gherkin
Given мерчант имеет MCC 7995 (Gambling)
When Integration Partner отправляет POST /api/v1/merchants
Then система создаёт мерчанта со статусом PENDING
  And KYB результат принудительно устанавливается в MANUAL_REVIEW
  And alert отправляется Compliance Officer
  And Enhanced Due Diligence (EDD) обязателен перед активацией
```

#### Error Scenario 1: Невалидные данные
```gherkin
Given запрос не содержит обязательного поля registration_number
When Integration Partner отправляет POST /api/v1/merchants
Then система возвращает 400 Bad Request
  And error body содержит {"field": "registration_number", "issue": "required"}
  And мерчант НЕ создаётся
  And audit log фиксирует failed attempt
```

#### Error Scenario 2: Дублирование
```gherkin
Given мерчант с registration_number "HRB 123456" и country "DE" уже существует
When Integration Partner отправляет POST /api/v1/merchants с тем же registration_number + country
Then система возвращает 409 Conflict
  And error body содержит {"code": "DUPLICATE_MERCHANT"}
```

#### Error Scenario 3: Нет UBO
```gherkin
Given запрос содержит пустой массив ubo_list
When Integration Partner отправляет POST /api/v1/merchants
Then система возвращает 422 Unprocessable Entity
  And error body содержит {"code": "UBO_REQUIRED", "message": "At least one UBO with ≥25% ownership is required"}
```

### Constraints
- [x] C-002: PAN не участвует в этом flow (нет карточных данных при онбординге)
- [x] C-003: UBO identification обязателен, порог 25%
- [x] C-004: Sanctions screening инициируется для каждого UBO
- [x] C-007: Только необходимые данные (GDPR minimization)
- [x] C-008: SLA ≤48ч для auto-approve
- [x] C-009: Audit log для всех действий
- [x] C-012: Rate limiting на endpoint

### Dependencies
- **Upstream:** KYC/KYB Provider API (docs/integrations/kyc-provider.md)
- **Downstream:** US-002 (Merchant Dashboard), US-010 (First Transaction)

### Technical Notes
- Endpoint idempotent по Idempotency-Key (при повторе с тем же ключом — вернуть существующий merchant)
- KYB/KYC — асинхронные, результаты приходят через webhook от провайдера
- Risk scoring (BR-ONB-004) запускается после KYB VERIFIED + all UBO CLEAR

### Open Questions
_Нет. Все данные доступны в business rules и integrations._
