---
title: "User Story"
feature: "Инициирование спора"
agent: BA Agent
type: user-story
date: 2026-03-09 12:08 UTC
validation: 4/4 PASS
---

# User Story: Merchant Dispute Initiation via API

**ID:** US-DISP-001  
**Epic:** Dispute Management System  
**Status:** [DRAFT] - REQUIRES APPROVAL  
**Priority:** High  
**Created:** 2024-12-19  

## User Story

**As a** Merchant  
**I want** to инициировать dispute через API  
**So that** I can оспорить транзакцию cardholder программно через мою систему управления заказами

## Business Context

Merchant должен иметь возможность оспаривать незаконные чарджбэки через автоматизированный API, соблюдая строгие дедлайны схем (C-005). Это критично для защиты выручки и снижения chargeback ratio.

## Acceptance Criteria

### Happy Path
- **AC1:** GIVEN merchant имеет активный MID и валидный API token  
  WHEN отправляет POST запрос на `/disputes` с transaction_id и dispute_reason  
  THEN система создаёт dispute с status="initiated" и возвращает dispute_id  
  AND система автоматически рассчитывает дедлайн для схемы (30 дней Visa, 45 дней Mastercard)

### Edge Cases
- **AC2:** GIVEN merchant инициирует dispute для транзакции старше 120 дней (scheme deadline прошёл)  
  WHEN отправляет запрос  
  THEN система возвращает 400 "Dispute deadline exceeded" с конкретной датой дедлайна

- **AC3:** GIVEN для транзакции уже существует активный dispute  
  WHEN merchant пытается создать ещё один  
  THEN система возвращает 409 "Dispute already exists" с dispute_id существующего

### Error Scenarios
- **AC4:** GIVEN merchant отправляет dispute без обязательного supporting_evidence  
  WHEN отправляет запрос  
  THEN система возвращает 422 "Missing required evidence" со списком необходимых документов

- **AC5:** GIVEN merchant не авторизован (недействительный API token)  
  WHEN отправляет запрос на создание dispute  
  THEN система возвращает 401 "Unauthorized" без раскрытия деталей о причине

## Technical Requirements

### API Endpoint
```
POST /api/v1/disputes
```

### Request Fields (минимальные)
- `transaction_id` (required) - ID оспариваемой транзакции
- `dispute_reason` (required) - код причины (fraud, authorization, processing_error)  
- `supporting_evidence[]` (required) - массив URL документов-доказательств
- `merchant_statement` (optional) - текстовое объяснение

### Response Success (201)
```json
{
  "dispute_id": "disp_abc123",
  "status": "initiated", 
  "deadline": "2024-01-18T23:59:59Z",
  "scheme_deadline_days": 30
}
```

## Business Rules References
- BR-DISP-001: Дедлайны по схемам (Visa 30 дней, Mastercard 45 дней)
- BR-DISP-002: Обязательные evidence по типу dispute
- BR-AML-001: Логирование всех dispute actions для audit trail (C-009)

## Constraints
- **C-005:** Сроки обработки чарджбэков - система ОБЯЗАНА рассчитывать корректные дедлайны по схемам и блокировать просроченные disputes
- **C-009:** Логирование и audit trail - каждое действие с dispute логируется с merchant_id, timestamp, IP
- **C-008:** SLA по доступности - API должен быть доступен 99.95% времени

## Definition of Done
- [ ] API endpoint реализован согласно спеке
- [ ] Автоматический расчёт дедлайнов по схемам 
- [ ] Валидация supporting evidence по типу dispute
- [ ] Unit тесты для всех AC
- [ ] Integration тесты с mock схемами
- [ ] Audit logging реализован
- [ ] API документация обновлена
- [ ] Нагрузочное тестирование (rate limiting C-012)

## Dependencies
- Dispute Management Service
- Transaction Lookup Service  
- Evidence Storage Service
- Audit Logging Service
- Scheme Rules Engine

## Assumptions
- Merchant уже прошёл KYB онбординг
- Transaction в статусе settled
- Evidence documents уже загружены в secure storage
- Merchant имеет активный API access

---

**Approval Required:** PO + Disputes Manager  
**Next Steps:** После approval → создание API specification (SA Agent)  
**Risk Level:** Medium (deadline compliance критичен)

