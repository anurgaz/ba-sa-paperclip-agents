# Бизнес-правила: Транзакции

> Лимиты, маршрутизация, авторизация, capture и settlement.

---

## BR-TXN-001: Авторизация транзакции
- **Описание:** Обработка авторизационного запроса от мерчанта
- **Условие:** POST /api/v1/transactions/authorize
- **Действие:**
  1. Валидация: MID active, TID valid, amount > 0, currency supported
  2. Rate limit check (≤100 req/sec per MID, C-012)
  3. Fraud screening: velocity check, amount anomaly, geo check
  4. 3DS/SCA check: если EEA и не исключение → инициировать 3DS (C-001)
  5. Маршрутизация к эквайреру/процессору (BR-TXN-004)
  6. Forward ISO 8583 authorization request
  7. Response: approved (00) / declined (05, 51, etc.) / error
  8. Audit log entry (C-009)
  9. Webhook notification мерчанту
- **Исключения:** MIT (Merchant Initiated Transaction) — без SCA. Требуется mandate reference от первичной CIT
- **Связанные constraints:** C-001, C-002, C-008, C-009, C-012

## BR-TXN-002: Лимиты транзакций
- **Описание:** Проверка транзакционных лимитов перед авторизацией
- **Условие:** Каждая входящая транзакция
- **Действие:**
  1. Single transaction limit: зависит от risk profile мерчанта (LOW: €10,000, MEDIUM: €5,000, HIGH: €2,000)
  2. Daily limit per MID: LOW: €100,000, MEDIUM: €50,000, HIGH: €20,000
  3. Monthly limit per MID: LOW: €2,000,000, MEDIUM: €1,000,000, HIGH: €400,000
  4. Превышение single → decline с кодом LIMIT_EXCEEDED
  5. Превышение daily/monthly → decline + alert Risk Manager
  6. Кумулятивная проверка: сумма транзакций за 24ч для AML (C-006)
  7. ≥€15,000 за 24ч от одного плательщика → enhanced monitoring alert
- **Исключения:** Лимиты могут быть увеличены по запросу мерчанта + одобрение Risk Manager (фиксируется в audit log)
- **Связанные constraints:** C-006, C-008, C-009

## BR-TXN-003: 3DS / SCA flow
- **Описание:** Аутентификация держателя карты по PSD2
- **Условие:** Транзакция в EEA + не исключение SCA
- **Действие:**
  1. Определение: CIT или MIT
  2. CIT в EEA: обязательная SCA через 3DS 2.x
  3. Проверка исключений: low value (<€30, cumulative <€100), TRA (low fraud rate), trusted beneficiary, recurring (subsequent)
  4. Если исключение применимо → soft decline fallback (если эмитент не согласен)
  5. 3DS Challenge → redirect/SDK → результат: authenticated/not_authenticated/attempt
  6. Liability shift: при успешной 3DS → liability на эмитенте
  7. Не-EEA транзакции: 3DS опционален, рекомендуется для fraud reduction
- **Исключения:** 
  - MIT с valid mandate → без SCA
  - MOTO (Mail Order/Telephone Order) → без SCA, но без liability shift
  - One-leg transactions (issuer вне EEA) → SCA best effort
- **Связанные constraints:** C-001

## BR-TXN-004: Маршрутизация транзакций
- **Описание:** Выбор оптимального маршрута для обработки транзакции
- **Условие:** После успешной валидации и fraud check
- **Действие:**
  1. Определение BIN → card scheme (Visa/Mastercard), issuing country, card type
  2. Правила маршрутизации (приоритет):
     a. Регуляторные: некоторые BIN ranges → конкретный процессор
     b. Стоимость: предпочтение локальному эквайреру (ниже interchange)
     c. Конверсия: historical approval rate по BIN range + процессор
     d. Доступность: failover если primary процессор недоступен
  3. Retry logic: при timeout → retry через альтернативный маршрут (max 1 retry)
  4. Logging: route selection reason в audit log
- **Исключения:** При failover — только на pre-approved альтернативный маршрут. Не маршрутизировать через процессор с expired сертификацией
- **Связанные constraints:** C-008, C-009

## BR-TXN-005: Capture
- **Описание:** Захват авторизованной транзакции для списания
- **Условие:** POST /api/v1/transactions/{id}/capture
- **Действие:**
  1. Проверка: транзакция в статусе AUTHORIZED, не expired (auth validity: 7 дней Visa, 7 дней MC)
  2. Amount: ≤ authorized amount. Partial capture allowed
  3. Если partial → оставшийся hold автоматически снимается
  4. Статус → CAPTURED
  5. Транзакция включается в следующий batch settlement
  6. Audit log entry
- **Исключения:** Auto-capture: мерчант может настроить auto-capture через N часов (1-168ч)
- **Связанные constraints:** C-009

## BR-TXN-006: Void
- **Описание:** Отмена авторизованной, не захваченной транзакции
- **Условие:** POST /api/v1/transactions/{id}/void
- **Действие:**
  1. Проверка: статус AUTHORIZED (не CAPTURED, не VOIDED)
  2. Отправка void/reversal в card scheme
  3. Hold на карте снимается
  4. Статус → VOIDED
  5. Audit log entry
- **Исключения:** После capture — void невозможен, только refund (BR-TXN-007)
- **Связанные constraints:** C-009

## BR-TXN-007: Refund
- **Описание:** Возврат средств после settlement
- **Условие:** POST /api/v1/transactions/{id}/refund
- **Действие:**
  1. Проверка: транзакция SETTLED. Refund amount ≤ original amount - previous refunds
  2. Partial refund allowed
  3. Создание credit транзакции
  4. Проверка: баланс мерчанта достаточен для refund
  5. Если недостаточно → hold refund + alert Finance
  6. Статус оригинала → REFUNDED / PARTIALLY_REFUNDED
  7. Refund включается в settlement
- **Исключения:** Refund window: 180 дней от original transaction (Visa). После — decline, suggest chargeback path
- **Связанные constraints:** C-009

## BR-TXN-008: Batch Settlement
- **Описание:** Ежедневная пакетная обработка для расчётов
- **Условие:** Scheduled job, ежедневно 23:00 UTC
- **Действие:**
  1. Сбор всех CAPTURED транзакций за период
  2. Группировка по card scheme (Visa batch, MC batch)
  3. Netting: captures - refunds per MID
  4. Формирование clearing file (TC05 для Visa, IPM для MC)
  5. Отправка в card scheme
  6. Settlement: T+1 (LOW risk), T+3 (MEDIUM), T+7 (HIGH)
  7. Перечисление на IBAN мерчанта за вычетом MDR
  8. Settlement report для мерчанта (API + webhook)
- **Исключения:** Мерчанты в статусе SUSPENDED → hold settlement до resolution. Public holidays → shift на следующий рабочий день
- **Связанные constraints:** C-008, C-009
