# Интеграция с KYC/KYB провайдером

> Спецификация API для верификации юр. лиц (KYB) и физ. лиц (KYC / UBO check).

---

## Provider

| Параметр | Значение |
|----------|---------|
| Провайдер | _TBD_ (placeholder: Generic KYC Provider) |
| Base URL | `https://api.kyc-provider.example/v2` |
| Auth | API Key + HMAC signature |
| Format | REST JSON |
| Rate Limit | 100 req/min |
| SLA | 99.9% uptime, p95 response <5s |

## KYB — Проверка юридического лица

### POST /business/verify

**Request:**
```json
{
  "reference_id": "ps_merchant_550e8400",
  "company": {
    "legal_name": "Acme GmbH",
    "registration_number": "HRB 123456",
    "country": "DE",
    "legal_address": {
      "street": "Hauptstraße 1",
      "city": "Berlin",
      "postal_code": "10115",
      "country": "DE"
    }
  },
  "checks": ["company_registration", "active_status", "address_verification", "adverse_media"],
  "webhook_url": "https://api.payment-service.com/webhooks/kyb-result"
}
```

**Response (async — webhook):**
```json
{
  "reference_id": "ps_merchant_550e8400",
  "status": "COMPLETED",
  "result": "VERIFIED | FAILED | MANUAL_REVIEW",
  "checks": [
    {
      "type": "company_registration",
      "result": "PASS",
      "details": "Company registered in Handelsregister, active since 2020-01-15"
    },
    {
      "type": "address_verification",
      "result": "PASS",
      "details": "Address matches registered address"
    },
    {
      "type": "adverse_media",
      "result": "CLEAR",
      "details": "No adverse media found"
    }
  ],
  "completed_at": "2026-03-08T10:05:00Z"
}
```

**Ошибки:**
| HTTP Status | Error Code | Описание |
|------------|-----------|----------|
| 400 | INVALID_REQUEST | Невалидные данные |
| 404 | COMPANY_NOT_FOUND | Компания не найдена в реестре |
| 429 | RATE_LIMITED | Превышен rate limit |
| 503 | PROVIDER_UNAVAILABLE | Внешний реестр недоступен |

## KYC — Проверка физического лица (UBO)

### POST /individual/verify

**Request:**
```json
{
  "reference_id": "ps_ubo_660f9500",
  "individual": {
    "full_name": "Hans Mueller",
    "date_of_birth": "1985-06-15",
    "nationality": "DE",
    "document": {
      "type": "PASSPORT",
      "number": "C01X00T47",
      "country": "DE",
      "expiry_date": "2030-12-31"
    }
  },
  "checks": ["document_verification", "liveness", "sanctions", "pep", "adverse_media"],
  "webhook_url": "https://api.payment-service.com/webhooks/kyc-result"
}
```

**Response (async — webhook):**
```json
{
  "reference_id": "ps_ubo_660f9500",
  "status": "COMPLETED",
  "result": "CLEAR | MATCH | PEP_FLAG | FAILED",
  "checks": [
    {"type": "document_verification", "result": "PASS"},
    {"type": "liveness", "result": "PASS"},
    {"type": "sanctions", "result": "CLEAR", "lists_checked": ["EU", "OFAC", "UN", "UK_HMT"]},
    {"type": "pep", "result": "CLEAR"},
    {"type": "adverse_media", "result": "CLEAR"}
  ],
  "completed_at": "2026-03-08T14:30:00Z"
}
```

## Sanctions Screening (Batch)

### POST /screening/batch

**Request:**
```json
{
  "reference_id": "ps_daily_20260308",
  "entities": [
    {"id": "merchant_001", "type": "BUSINESS", "name": "Acme GmbH", "country": "DE"},
    {"id": "ubo_001", "type": "INDIVIDUAL", "name": "Hans Mueller", "dob": "1985-06-15"}
  ],
  "lists": ["EU_CONSOLIDATED", "OFAC_SDN", "UN_SC", "UK_HMT"],
  "match_threshold": 85,
  "webhook_url": "https://api.payment-service.com/webhooks/screening-result"
}
```

**Response:**
```json
{
  "reference_id": "ps_daily_20260308",
  "status": "COMPLETED",
  "total_screened": 2,
  "matches": 0,
  "potential_matches": 0,
  "results": [
    {"entity_id": "merchant_001", "result": "CLEAR"},
    {"entity_id": "ubo_001", "result": "CLEAR"}
  ]
}
```

## Retry Policy

| Сценарий | Действие | Max Retries | Backoff |
|----------|---------|-------------|---------|
| Timeout (>30s) | Retry | 3 | Exponential (1s, 2s, 4s) |
| 429 Rate Limited | Retry after Retry-After header | 5 | As specified |
| 503 Unavailable | Retry | 3 | Exponential (5s, 15s, 45s) |
| 5xx Other | Retry | 2 | Exponential (2s, 4s) |
| 4xx (non-429) | No retry | 0 | — |

---

> **Связанные constraints:** C-003 (UBO identification), C-004 (Sanctions screening), C-007 (GDPR — data minimization)
