# Sequence Diagram Template

> Шаблон для SA агента. Каждая sequence диаграмма — PlantUML формат.

---

## [SEQ-XXX] Название flow

### Metadata
- **Author:** [SA Agent / Human]
- **Status:** [DRAFT] / [APPROVED]
- **Related:** US-XXX, API-XXX

### Description
Краткое описание flow.

### Happy Path

```plantuml
@startuml SEQ-XXX-happy
title Flow Name — Happy Path

skinparam sequenceMessageAlign center
skinparam responseMessageBelowArrow true

actor "Actor" as actor
participant "Service A" as svc_a
participant "Service B" as svc_b
database "Database" as db
participant "Audit Log" as audit

== Step 1: Action ==

actor -> svc_a: Request
activate svc_a

svc_a -> audit: Log action (no PAN/CVV)
svc_a -> svc_b: Internal call
activate svc_b
svc_b --> svc_a: Response
deactivate svc_b

svc_a -> db: Persist
svc_a --> actor: Success Response

deactivate svc_a
@enduml
```

### Error Path 1: [Описание ошибки]

```plantuml
@startuml SEQ-XXX-error1
title Flow Name — Error Path 1

actor "Actor" as actor
participant "Service A" as svc_a

actor -> svc_a: Request
activate svc_a
svc_a --> actor: Error Response (4XX/5XX)
deactivate svc_a
@enduml
```

### Error Path 2: [Описание ошибки]

```plantuml
@startuml SEQ-XXX-error2
title Flow Name — Error Path 2
note right: Add your error flow here
@enduml
```

### Notes
- Граничные случаи и assumptions
- Ссылки на constraints: C-XXX

---

## Инструкция для агента

1. **ОБЯЗАТЕЛЬНО:** happy path + минимум 2 error paths
2. Формат: PlantUML (@startuml / @enduml)
3. Audit log ВСЕГДА присутствует как участник (C-009)
4. PAN никогда не передаётся вне CDE boundary (C-002, C-010)
5. Показывайте timeout и retry логику
6. Используйте activate/deactivate для наглядности
7. Группируйте шаги с == Step N: Name ==
8. Для CDE boundary используйте box "CDE" #LightCoral
