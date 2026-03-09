---
title: "User Story"
feature: "Рекуррентные платежи"
agent: BA Agent
type: user-story
date: 2026-03-09 12:08 UTC
validation: 4/4 PASS
---

# User Story: Рекуррентные платежи через API

**Статус:** [DRAFT] - требует ревью PO  
**ID:** US-REC-001  
**Эпик:** Payment Processing  
**Дата создания:** 2024-12-19  

## User Story

**Как** Integration Partner (мерчант с SaaS/подписочной моделью)  
**Я хочу** настроить автоматические периодические списания с карт моих клиентов  
**Чтобы** обеспечить бесшовное продление подписок без участия клиента в каждом платеже  

## Business Context

Мерчанты с подписочными моделями (SaaS, медиа, фитнес-клубы) нуждаются в автоматизации регулярных платежей. Первый платёж требует полной аутентификации клиента (3DS), последующие - проходят как Merchant Initiated Transactions (MIT) без участия клиента.

## Constraints & Compliance

- **C-001:** SCA обязательна для первого платежа (CIT), MIT исключены из SCA согласно PSD2 Article 14
- **C-002:** PAN хранится только в токенизированном виде, CVV не сохраняется
- **C-009:** Все операции с подписками логируются в audit trail

## Acceptance Criteria

### Happy Path
**Given** Integration Partner настроил подписку через API  
**When** наступает дата очередного списания  
**Then** система автоматически проводит MIT транзакцию по сохранённому токену  
**And** уведомляет мерчанта о результате через webhook  
**And** клиент получает receipt на email  

### Edge Cases

#### EC-1: Soft Decline при рекуррентном списании
**Given** подписка в статусе "active"  
**When** MIT транзакция отклонена с soft decline (insufficient funds, temporary issue)  
**Then** система переводит подписку в статус "past_due"  
**And** запускает retry logic: попытки через 3, 7, 14 дней  
**And** уведомляет мерчанта через webhook с reason_code  
**And** после 3 неудачных попыток → статус "cancelled"  

#### EC-2: Истечение срока карты
**Given** подписка активна, токен привязан к карте с истекающим сроком  
**When** система обнаруживает приближение expiry date (<30 дней)  
**Then** отправляет мерчанту webhook "card_expiring"  
**And** мерчант может запросить обновление токена через Account Updater  
**And** при успешном обновлении продолжает списания с новым токеном  

#### EC-3: Изменение суммы подписки
**Given** активная подписка с суммой €9.99/месяц  
**When** мерчант обновляет сумму до €14.99 через API  
**Then** следующее списание проходит на новую сумму  
**And** клиент уведомляется об изменении за 14 дней (если увеличение >20%)  
**And** система логирует изменение в audit trail  

### Error Scenarios

#### ES-1: Hard Decline при первом платеже (CIT)
**Given** клиент проходит 3DS аутентификацию  
**When** транзакция отклонена с hard decline (fraud, closed account)  
**Then** подписка создаётся в статусе "failed"  
**And** возвращается error response с decline_reason  
**And** токен не сохраняется  
**And** ретраи не запускаются  

#### ES-2: Отмена подписки клиентом через мерчанта
**Given** активная подписка  
**When** мерчант отправляет DELETE /subscriptions/{id}  
**Then** подписка переводится в статус "cancelled"  
**And** токен остается действительным (для возможного re-activation)  
**And** запланированные списания отменяются  
**And** отправляется webhook "subscription.cancelled"  

## API Endpoints

```
POST /v1/subscriptions - создание подписки (CIT)
GET /v1/subscriptions/{id} - получение статуса
PATCH /v1/subscriptions/{id} - обновление (сумма, частота)
DELETE /v1/subscriptions/{id} - отмена подписки
GET /v1/subscriptions/{id}/transactions - история списаний
```

## Data Model (новые поля)

### Subscription Entity
```
- id (UUID)
- merchant_id (FK)
- customer_id (string) 
- payment_token (string) - C-002 compliant
- amount (decimal)
- currency (ISO 4217)
- frequency (enum: monthly, yearly)
- status (enum: created, active, past_due, cancelled, expired)
- next_billing_date (timestamp)
- retry_count (integer, max 3)
- created_at (timestamp)
- updated_at (timestamp)
```

## Webhooks

- `subscription.created`
- `subscription.payment_succeeded` 
- `subscription.payment_failed`
- `subscription.past_due`
- `subscription.cancelled`
- `card_expiring`

## Out of Scope

- Account Updater интеграция (отдельный эпик)
- Prorating при изменении планов
- Multiple payment methods per subscription
- Dunning management UI

## Definition of Done

- [ ] PO ревью и approve
- [ ] Sequence diagram для CIT → MIT flow
- [ ] API спека с OpenAPI 3.0
- [ ] Webhook payload specifications
- [ ] Error code dictionary обновлён
- [ ] Test scenarios для QA

## Business Rules

- BR-001: Первый платёж (CIT) обязательно с 3DS для EU карт
- BR-002: MIT исключены из SCA согласно PSD2 Article 14
- BR-003: Retry logic только для soft declines
- BR-004: Maximum 3 retry attempts с экспоненциальным backoff

---

**Следующий шаг:** Ожидание ревью и approve от PO для перехода к детальному проектированию API.

