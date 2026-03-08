# API Specification Template

> Шаблон для SA агента. Каждая API спека должна следовать этой структуре.

---

## [API-XXX] Endpoint Name

### Metadata
- **Service:** [Название микросервиса]
- **Version:** v1
- **Author:** [SA Agent / Human]
- **Status:** [DRAFT] / [APPROVED]
- **Related User Stories:** US-XXX

### Endpoint

```
METHOD /api/v1/resource
```

### Description
Краткое описание: что делает endpoint, зачем нужен.

### Authentication
- **Type:** Bearer Token (OAuth 2.0)
- **Scopes:** [required scopes]

### Rate Limits
| Scope | Limit | Window |
|-------|-------|--------|
| Per MID | X req/sec | 1 second |
| Per IP | X req/min | 1 minute |

### Headers

| Header | Required | Description |
|--------|---------|-------------|
| Authorization | Yes | Bearer {token} |
| Content-Type | Yes | application/json |
| Idempotency-Key | Yes (for mutations) | UUID v4, unique per request |
| X-Request-ID | No | Correlation ID for tracing |

### Request

#### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|---------|-------------|
| id | UUID | Yes | Resource identifier |

#### Query Parameters
| Parameter | Type | Required | Default | Description |
|-----------|------|---------|---------|-------------|
| page | integer | No | 1 | Page number |
| per_page | integer | No | 20 | Items per page (max 100) |

#### Request Body
```json
{
  "field": "value"
}
```

| Field | Type | Required | Validation | Description |
|-------|------|---------|-----------|-------------|
| field | string | Yes | max 255 chars | Description |

### Response

#### Success (2XX)
```json
{
  "data": {},
  "meta": {
    "request_id": "uuid",
    "timestamp": "ISO 8601"
  }
}
```

#### Error Responses
| HTTP Status | Error Code | Description | Retry |
|------------|-----------|-------------|-------|
| 400 | VALIDATION_ERROR | Invalid request body | No |
| 401 | UNAUTHORIZED | Invalid or missing token | No |
| 403 | FORBIDDEN | Insufficient permissions | No |
| 404 | NOT_FOUND | Resource not found | No |
| 409 | CONFLICT | Duplicate idempotency key with different payload | No |
| 422 | UNPROCESSABLE | Business rule violation | No |
| 429 | RATE_LIMITED | Rate limit exceeded | Yes (after Retry-After) |
| 500 | INTERNAL_ERROR | Server error | Yes (exponential backoff) |

#### Error Body
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable description",
    "details": [
      {"field": "field_name", "issue": "specific validation error"}
    ]
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "ISO 8601"
  }
}
```

### Pagination
```json
{
  "data": [],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

### Webhook Events
| Event | Trigger | Payload |
|-------|---------|---------|
| resource.created | On successful creation | Full resource object |

### Constraints
- [ ] C-XXX: Как constraint учтён в данном endpoint

### Audit Log
- Action: `resource.action`
- Logged fields: [list]
- Excluded fields: [PAN, CVV — never logged]

---

## Инструкция для агента

1. **ОБЯЗАТЕЛЬНО** заполните: endpoint, auth, rate limits, request/response, errors, audit log
2. Error codes: включите ВСЕ из таблицы выше (400, 401, 403, 404, 409, 422, 429, 500)
3. PAN/CVV НИКОГДА не появляются в response body (C-002)
4. Каждый мутирующий endpoint требует Idempotency-Key
5. Pagination для list endpoints
6. Укажите связанные webhook events
7. Ссылайтесь на constraints (C-XXX)
8. Используйте термины из glossary.md
