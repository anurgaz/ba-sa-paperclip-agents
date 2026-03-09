---
title: "User Story — api � пе� и� ика� ия � � мена подпи� ки �"
agent: sa
type: user-story
date: 2026-03-09 11:48 UTC
validation: 4/4 PASS
---

# [DRAFT] API Спецификация: Отмена подписки на рекуррентные платежи

**ID:** SA-2026-003  
**Дата:** 2026-03-09  
**Автор:** SA Agent  
**Статус:** [DRAFT]  
**Тип:** API Specification  

## Обзор

API endpoint для отмены подписки на рекуррентные платежи. Позволяет мерчанту отменить активную подписку, прекратив будущие автоматические списания с карты держателя.

## User Story

**Как** мерчант  
**Я хочу** иметь возможность отменить подписку клиента на рекуррентные платежи  
**Чтобы** прекратить автоматические списания по запросу клиента или при необходимости

## Acceptance Criteria

### Happy Path
- ✅ Мерчант может отменить активную подписку по subscription_id
- ✅ После отмены все будущие MIT транзакции прекращаются
- ✅ Статус подписки меняется на "cancelled"
- ✅ Отправляется webhook уведомление о статусе подписки
- ✅ Записывается audit log запись об отмене

### Edge Cases
- ✅ Отмена уже отмененной подписки возвращает текущий статус без ошибки
- ✅ Отмена подписки с истекшим сроком действия обрабатывается корректно
- ✅ Частичная отмена для multi-schedule подписки не поддерживается

### Error Scenarios
- ❌ Подписка не найдена → 404 Not Found
- ❌ Подписка принадлежит другому мерчанту → 403 Forbidden
- ❌ Недействительный токен авторизации → 401 Unauthorized
- ❌ Превышен rate limit → 429 Too Many Requests

## API Specification

### Endpoint
```
DELETE /v1/subscriptions/{subscription_id}/cancel
```

### Authentication
```
Authorization: Bearer {jwt_token}
```

### Headers
```http
Content-Type: application/json
Idempotency-Key: {unique_key}  # Обязателен для данной операции
```

### Path Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| subscription_id | string | Yes | Уникальный идентификатор подписки (UUID format) |

### Request Body
```json
{
  "reason": "customer_request",
  "effective_date": "2026-03-15T00:00:00Z",
  "notify_customer": true,
  "metadata": {
    "cancelled_by": "customer_service",
    "ticket_id": "CS-12345"
  }
}
```

#### Request Schema
| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| reason | string | No | Причина отмены | Enum: customer_request, merchant_decision, fraud_suspected, card_expired |
| effective_date | string (ISO8601) | No | Дата вступления отмены в силу | Не ранее текущего времени, по умолчанию - немедленно |
| notify_customer | boolean | No | Отправить уведомление клиенту | По умолчанию: false |
| metadata | object | No | Дополнительные данные | Максимум 10 полей, каждое до 255 символов |

### Response Body

#### Success Response (200 OK)
```json
{
  "subscription_id": "sub_1234567890abcdef",
  "status": "cancelled",
  "cancelled_at": "2026-03-09T12:00:00Z",
  "effective_date": "2026-03-15T00:00:00Z",
  "reason": "customer_request",
  "next_billing_date": null,
  "remaining_amount": 0.00,
  "currency": "EUR",
  "metadata": {
    "cancelled_by": "customer_service",
    "ticket_id": "CS-12345"
  }
}
```

#### Response Schema
| Field | Type | Description |
|-------|------|-------------|
| subscription_id | string | ID отмененной подписки |
| status | string | Новый статус (cancelled) |
| cancelled_at | string (ISO8601) | Timestamp отмены |
| effective_date | string (ISO8601) | Дата прекращения списаний |
| reason | string | Причина отмены |
| next_billing_date | null | Всегда null после отмены |
| remaining_amount | number | Остаток к возврату (если применимо) |
| currency | string | Валюта (ISO 4217) |
| metadata | object | Переданные метаданные |

### Error Responses

#### 400 Bad Request
```json
{
  "error": "invalid_request",
  "error_description": "Invalid effective_date: cannot be in the past",
  "details": {
    "field": "effective_date",
    "code": "invalid_date_range"
  }
}
```

#### 401 Unauthorized
```json
{
  "error": "unauthorized",
  "error_description": "Invalid or expired access token"
}
```

#### 403 Forbidden
```json
{
  "error": "forbidden",
  "error_description": "Subscription belongs to different merchant",
  "details": {
    "subscription_id": "sub_1234567890abcdef"
  }
}
```

#### 404 Not Found
```json
{
  "error": "subscription_not_found",
  "error_description": "Subscription with given ID does not exist",
  "details": {
    "subscription_id": "sub_1234567890abcdef"
  }
}
```

#### 409 Conflict
```json
{
  "error": "subscription_already_cancelled",
  "error_description": "Subscription is already in cancelled status",
  "details": {
    "current_status": "cancelled",
    "cancelled_at": "2026-03-01T10:00:00Z"
  }
}
```

#### 422 Unprocessable Entity
```json
{
  "error": "validation_error",
  "error_description": "Request validation failed",
  "details": [
    {
      "field": "reason",
      "message": "Invalid reason code"
    }
  ]
}
```

#### 429 Too Many Requests
```json
{
  "error": "rate_limit_exceeded",
  "error_description": "Too many requests",
  "retry_after": 60
}
```

#### 500 Internal Server Error
```json
{
  "error": "internal_error",
  "error_description": "An internal error occurred"
}
```

### Rate Limits
- **Subscription operations:** 20 requests per minute per MID
- **Burst limit:** 50 requests per minute
- **Headers returned:**
  - `X-RateLimit-Limit: 20`
  - `X-RateLimit-Remaining: 15`
  - `X-RateLimit-Reset: 1709985600`

### Idempotency
- Обязательный заголовок `Idempotency-Key` для данной операции (C-012)
- Повторный запрос с тем же ключом возвращает результат первого успешного выполнения
- TTL ключа: 24 часа
- Формат ключа: строка длиной 1-255 символов

### Webhook Events
После успешной отмены отправляется webhook:

```json
{
  "event": "subscription.cancelled",
  "data": {
    "subscription_id": "sub_1234567890abcdef",
    "merchant_id": "mid_123456789012345",
    "status": "cancelled",
    "cancelled_at": "2026-03-09T12:00:00Z",
    "reason": "customer_request"
  },
  "created_at": "2026-03-09T12:00:01Z"
}
```

### Audit Log
Каждая операция отмены записывается в audit log:

```json
{
  "timestamp": "2026-03-09T12:00:00Z",
  "action": "subscription_cancelled",
  "actor": "merchant",
  "merchant_id": "mid_123456789012345",
  "subscription_id": "sub_1234567890abcdef",
  "ip_address": "203.0.113.1",
  "user_agent": "FlowlixSDK/1.0",
  "idempotency_key": "idem_abc123",
  "details": {
    "reason": "customer_request",
    "effective_date": "2026-03-15T00:00:00Z"
  }
}
```

## Sequence Diagram

```plantuml
@startuml Subscription Cancellation Flow

participant Merchant as M
participant "API Gateway" as GW  
participant "Subscription Service" as SS
participant "Token Vault" as TV
participant "Audit Service" as AS
participant "Webhook Service" as WS
participant "External Scheme" as ES

== Happy Path ==
M -> GW: DELETE /v1/subscriptions/{id}/cancel\nAuthorization: Bearer token\nIdempotency-Key: key123
activate GW

GW -> GW: Validate JWT token
GW -> GW: Check rate limit (20/min per MID)
GW -> SS: Forward request
activate SS

SS -> SS: Validate subscription_id format
SS -> SS: Check subscription ownership by MID
SS -> SS: Validate subscription status
SS -> SS: Check idempotency key

SS -> AS: Write audit log entry
activate AS
AS -> AS: Store immutable log
AS --> SS: Log written
deactivate AS

SS -> TV: Get tokenized card details
activate TV
TV --> SS: Return token info
deactivate TV

SS -> SS: Update subscription status to "cancelled"
SS -> SS: Set next_billing_date to null

SS -> WS: Queue webhook event
activate WS
WS -> WS: Schedule webhook delivery
deactivate WS

SS --> GW: 200 OK + subscription details
deactivate SS
GW --> M: Response with cancelled subscription
deactivate GW

== Error Path 1: Subscription Not Found ==
M -> GW: DELETE /v1/subscriptions/invalid_id/cancel
GW -> SS: Forward request
SS -> SS: Lookup subscription by ID
SS -> SS: Subscription not found
SS --> GW: 404 Not Found
GW --> M: 404 + error details

== Error Path 2: Rate Limit Exceeded ==
M -> GW: DELETE /v1/subscriptions/{id}/cancel
GW -> GW: Check rate limit
GW -> GW: Rate limit exceeded (>20/min)
GW --> M: 429 Too Many Requests\nRetry-After: 60

@enduml
```

## Data Flow

```plantuml
@startuml Subscription Cancellation Data Flow

[Merchant] -> (API Gateway) : DELETE request
(API Gateway) -> [Subscription DB] : Update status
[Subscription DB] -> [Audit Log] : Record cancellation
[Subscription DB] -> [Webhook Queue] : Queue event
[Webhook Queue] -> [Merchant Webhook] : Notify cancellation

note right of [Subscription DB]
  Status: active -> cancelled
  next_billing_date: null
  cancelled_at: timestamp
end note

note right of [Audit Log]
  Immutable record of:
  - Who cancelled
  - When cancelled  
  - Reason
  - IP address
end note

@enduml
```

## Security Considerations

1. **PCI DSS Compliance:** Никакие данные карт (PAN, CVV) не передаются в этом API - только токены (C-002)
2. **JWT Validation:** Обязательная проверка подписи и срока действия токена
3. **MID Authorization:** Мерчант может отменять только свои подписки
4. **Rate Limiting:** Защита от злоупотребления согласно C-012
5. **Audit Logging:** Полное логирование для соответствия C-009

## Constraints

Данный артефакт затрагивает следующие ограничения:

- **C-002:** Запрет хранения чувствительных данных карт - API работает только с токенами
- **C-009:** Логирование и audit trail - каждая операция отмены логируется  
- **C-012:** Rate limiting и защита API - endpoint защищен лимитами (20 req/min)

## Implementation Notes

1. Отмена подписки не влияет на уже авторизованные, но не захваченные транзакции
2. При отмене с датой в будущем - подписка остается активной до effective_date
3. Webhook отправляется асинхронно, сбой доставки не влияет на результат отмены
4. Поддерживается мягкая отмена (soft delete) - данные подписки сохраняются для аудита

---
**Создан:** SA Agent  
**Требует утверждения:** Tech Lead + SA (согласно decision-matrix.md, пункт 4)
