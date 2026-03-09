---
title: "User Story"
feature: "Онбординг мерчанта"
agent: BA Agent
type: user-story
date: 2026-03-09 12:08 UTC
validation: 4/4 PASS
---

# [DRAFT] User Story: Merchant Onboarding via API

## Базовая информация
- **ID:** US-ONB-001
- **Тип:** Epic  
- **Приоритет:** High
- **Статус:** [DRAFT] - REQUIRES APPROVAL (PO + Compliance)

## User Story

**Как** Integration Partner (PayFac/PSP)  
**Я хочу** отправить POST /api/v1/merchants для онбординга нового мерчанта  
**Чтобы** автоматически подключить его к карточному эквайрингу через Flowlix в рамках модели PayFac

## Acceptance Criteria

### Happy Path
**AC-1:** Успешный онбординг с полными данными
```
GIVEN Integration Partner имеет валидный API ключ
AND все обязательные поля заполнены корректно  
AND UBO данные предоставлены для всех владельцев ≥25%
WHEN отправляется POST /api/v1/merchants
THEN возвращается 201 Created с merchant_id
AND мерчант получает статус "pending_verification"
AND запускается процесс KYB + sanctions screening
AND SLA онбординга ≤48ч активируется
```

### Edge Cases
**AC-2:** UBO с долей точно 25%
```
GIVEN юр.лицо имеет владельца с долей ровно 25.0%
WHEN отправляется запрос онбординга
THEN этот владелец ОБЯЗАН быть включён как UBO
AND проходит полный KYC
```

**AC-3:** Сложная структура собственности
```
GIVEN мерчант имеет многоуровневую структуру собственности
AND есть косвенные владельцы с суммарной долей ≥25%
WHEN отправляется запрос
THEN система требует данные всех прямых и косвенных UBO
AND вычисляет итоговую долю каждого физлица
```

### Error Scenarios
**AC-4:** Sanctions screening match
```
GIVEN в запросе указан UBO, совпадающий с санкционным списком
WHEN выполняется автоматический скрининг
THEN возвращается 422 Unprocessable Entity
AND error_code: "SANCTIONS_MATCH"
AND онбординг блокируется
AND создаётся alert для MLRO
```

**AC-5:** Недостающие UBO данные
```
GIVEN в запросе не указаны данные UBO с долей ≥25%
WHEN валидируются входные данные
THEN возвращается 400 Bad Request  
AND error_code: "UBO_DATA_REQUIRED"
AND указываются недостающие поля
```

## Бизнес-правила
- **BR-ONB-001:** Онбординг только для юр.лиц (физлица через отдельный endpoint)
- **BR-ONB-002:** Mandatory UBO identification для всех долей ≥25% (прямых и косвенных)
- **BR-ONB-003:** Real-time sanctions screening при получении запроса
- **BR-ONB-004:** GDPR consent обязателен для всех персональных данных UBO

## Constraints
- **C-003:** Идентификация UBO при онбординге — порог 25% жёсткий
- **C-004:** Sanctions screening обязателен при онбординге + ongoing
- **C-007:** GDPR минимизация данных + retention 5 лет (AML)
- **C-008:** SLA онбординга ≤48ч при прохождении KYB

## Definition of Done
- [ ] API endpoint задокументирован в OpenAPI spec
- [ ] Интеграция с sanctions screening сервисом
- [ ] UBO calculation engine для сложных структур
- [ ] GDPR consent management integration  
- [ ] Monitoring/alerting для SLA ≤48ч
- [ ] MLRO dashboard для sanctions matches
- [ ] E2E тесты для всех AC

## Open Questions
1. Какие MCC коды разрешены для автоматического онбординга?
2. Нужна ли интеграция с external KYB провайдерами?
3. Процедура manual review для edge cases sanctions screening?

---

**Эскалация:** Требует аппрув от **PO** (user story) + **Compliance Officer** (onboarding flow с AML/sanctions требованиями).

