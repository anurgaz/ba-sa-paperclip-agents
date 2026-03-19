# Пример: API Specification — POST /api/v1/merchants

> Эталонный пример для few-shot. SA агент должен генерировать артефакты этого уровня качества.

---

## [API-001] Create Merchant

### Metadata
- **Service:** Onboarding Service
- **Version:** v1
- **Author:** SA Agent
- **Status:** [DRAFT]
- **Related User Stories:** US-001

### Endpoint

```
POST /api/v1/merchants
```

### Description
Регистрация нового мерчанта (суб-мерчанта) на платформе Payment Service. Создаёт сущность Merchant, инициирует асинхронную KYB проверку компании и KYC проверку каждого UBO. Результат KYB/KYC приходит через webhook.

### Authentication
- **Type:** Bearer Token (OAuth 2.0)
- **Scopes:** `merchants:write`

### Rate Limits
| Scope | Limit | Window |
|-------|-------|--------|
| Per API Key | 5 req/min | 1 minute |
| Per IP | 10 req/min | 1 minute |

> См. C-012: Onboarding endpoints — строгий rate limit.

### Headers

| Header | Required | Description |
|--------|---------|-------------|
| Authorization | Yes | Bearer {access_token} |
| Content-Type | Yes | application/json |
| Idempotency-Key | Yes | UUID v4, уникальный per merchant application |
| X-Request-ID | No | UUID v4, correlation ID for tracing |

### Request

#### Request Body
```json
{
  "legal_name": "Acme GmbH",
  "trading_name": "Acme Shop",
  "registration_number": "HRB 123456",
  "country": "DE",
  "legal_address": {
    "street": "Hauptstrasse 1",
    "city": "Berlin",
    "postal_code": "10115",
    "country": "DE"
  },
  "business_type": "5411",
  "website_url": "https://acme-shop.de",
  "contact_email": "merchant@acme.de",
  "contact_phone": "+49301234567",
  "bank_account": {
    "iban": "DE89370400440532013000",
    "bic": "COBADEFFXXX",
    "account_holder": "Acme GmbH"
  },
  "expected_monthly_volume": 50000.00,
  "expected_monthly_volume_currency": "EUR",
  "ubo_list": [
    {
      "full_name": "Hans Mueller",
      "date_of_birth": "1985-06-15",
      "nationality": "DE",
      "ownership_percentage": 60.00,
      "document": {
        "type": "PASSPORT",
        "number": "C01X00T47",
        "country": "DE",
        "expiry_date": "2030-12-31"
      },
      "address": {
        "street": "Berliner Str. 10",
        "city": "Berlin",
        "postal_code": "10115",
        "country": "DE"
      }
    },
    {
      "full_name": "Anna Schmidt",
      "date_of_birth": "1990-03-22",
      "nationality": "DE",
      "ownership_percentage": 40.00,
      "document": {
        "type": "ID_CARD",
        "number": "L01X00456",
        "country": "DE",
        "expiry_date": "2028-06-30"
      },
      "address": {
        "street": "Musterweg 5",
        "city": "Munich",
        "postal_code": "80331",
        "country": "DE"
      }
    }
  ],
  "webhook_url": "https://acme-shop.de/webhooks/payment-service"
}
```

| Field | Type | Required | Validation | Description |
|-------|------|---------|-----------|-------------|
| legal_name | string | Yes | 1-255 chars | Юридическое наименование компании |
| trading_name | string | No | 1-255 chars | Торговое наименование |
| registration_number | string | Yes | 1-50 chars | Номер гос. регистрации |
| country | string | Yes | ISO 3166-1 alpha-2 | Страна регистрации |
| legal_address | object | Yes | — | Юридический адрес |
| legal_address.street | string | Yes | 1-255 chars | Улица |
| legal_address.city | string | Yes | 1-100 chars | Город |
| legal_address.postal_code | string | Yes | 1-20 chars | Почтовый индекс |
| legal_address.country | string | Yes | ISO 3166-1 alpha-2 | Страна |
| business_type | string | Yes | 4 digits, valid MCC | MCC код |
| website_url | string | Yes | Valid URL, https only | URL сайта мерчанта |
| contact_email | string | Yes | Valid email | Email для связи |
| contact_phone | string | Yes | E.164 format | Телефон |
| bank_account.iban | string | Yes | Valid IBAN | IBAN для settlement |
| bank_account.bic | string | No | Valid BIC | BIC/SWIFT |
| bank_account.account_holder | string | Yes | 1-255 chars | Владелец счёта |
| expected_monthly_volume | decimal | Yes | > 0 | Ожидаемый месячный объём |
| expected_monthly_volume_currency | string | Yes | ISO 4217 | Валюта объёма |
| ubo_list | array | Yes | min 1 item | Список UBO |
| ubo_list[].full_name | string | Yes | 1-255 chars | ФИО UBO |
| ubo_list[].date_of_birth | date | Yes | ISO 8601, age ≥18 | Дата рождения |
| ubo_list[].nationality | string | Yes | ISO 3166-1 alpha-2 | Гражданство |
| ubo_list[].ownership_percentage | decimal | Yes | 0.01-100.00 | Доля владения (%) |
| ubo_list[].document.type | enum | Yes | PASSPORT, ID_CARD, RESIDENCE_PERMIT | Тип документа |
| ubo_list[].document.number | string | Yes | 1-50 chars | Номер документа |
| ubo_list[].document.country | string | Yes | ISO 3166-1 alpha-2 | Страна выдачи |
| ubo_list[].document.expiry_date | date | Yes | ISO 8601, future date | Срок действия |
| webhook_url | string | No | Valid HTTPS URL | URL для webhooks |

### Response

#### 201 Created
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "mid": null,
    "legal_name": "Acme GmbH",
    "trading_name": "Acme Shop",
    "registration_number": "HRB 123456",
    "country": "DE",
    "status": "PENDING",
    "kyb_status": "PENDING",
    "risk_level": null,
    "ubo_list": [
      {
        "id": "660f9500-a1b2-c3d4-e5f6-778899001122",
        "full_name": "Hans Mueller",
        "ownership_percentage": 60.00,
        "kyc_status": "PENDING",
        "sanctions_status": "PENDING",
        "pep_status": "PENDING"
      },
      {
        "id": "770a8600-b2c3-d4e5-f6a7-889900112233",
        "full_name": "Anna Schmidt",
        "ownership_percentage": 40.00,
        "kyc_status": "PENDING",
        "sanctions_status": "PENDING",
        "pep_status": "PENDING"
      }
    ],
    "created_at": "2026-03-08T10:00:00Z"
  },
  "meta": {
    "request_id": "req_abc123def456",
    "timestamp": "2026-03-08T10:00:00Z"
  }
}
```

#### Error Responses
| HTTP Status | Error Code | Description | Retry |
|------------|-----------|-------------|-------|
| 400 | VALIDATION_ERROR | Невалидные или отсутствующие обязательные поля | No |
| 401 | UNAUTHORIZED | Невалидный или отсутствующий токен | No |
| 403 | FORBIDDEN | Токен не имеет scope merchants:write | No |
| 409 | CONFLICT | Мерчант с таким registration_number + country уже существует | No |
| 409 | IDEMPOTENCY_CONFLICT | Тот же Idempotency-Key с другим payload | No |
| 422 | UBO_REQUIRED | Массив ubo_list пуст или нет UBO с >=25% | No |
| 422 | SANCTIONED_COUNTRY | Страна регистрации в санкционном списке | No |
| 429 | RATE_LIMITED | Превышен rate limit | Yes (Retry-After header) |
| 500 | INTERNAL_ERROR | Внутренняя ошибка сервера | Yes (exponential backoff) |

### Webhook Events
| Event | Trigger | Payload |
|-------|---------|---------|
| merchant.created | Мерчант создан, KYB инициирован | {merchant_id, status: PENDING} |
| merchant.kyb_completed | KYB проверка завершена | {merchant_id, kyb_status, risk_score} |
| merchant.ubo_kyc_completed | KYC UBO завершен | {merchant_id, ubo_id, kyc_status, sanctions_status, pep_status} |
| merchant.activated | Мерчант активирован | {merchant_id, mid, tid, status: ACTIVE} |
| merchant.rejected | Мерчант отклонён | {merchant_id, reason_code} |

### Constraints
- [x] C-002: PAN не участвует в онбординге. Документы UBO — чувствительные данные, шифруются at rest
- [x] C-003: UBO с долей >=25% обязательны. Валидация в request body
- [x] C-004: Sanctions screening инициируется автоматически для всех UBO
- [x] C-007: Только необходимые поля. Retention: 5 лет после offboarding
- [x] C-008: SLA <=48ч. KYB/KYC запускаются немедленно после создания
- [x] C-009: Audit log: merchant.create action, все поля кроме document numbers (masked)
- [x] C-012: Rate limit 5 req/min per API key

### Audit Log
- **Action:** `merchant.create`
- **Logged fields:** merchant_id, legal_name, country, business_type, ubo_count, risk_level, status, actor_id
- **Excluded fields:** document.number (masked), iban (masked: DE89****3000), contact_phone (masked)

### Idempotency Behavior
- Same Idempotency-Key + same payload = return original response (201)
- Same Idempotency-Key + different payload = 409 IDEMPOTENCY_CONFLICT
- Idempotency-Key TTL: 24 hours
