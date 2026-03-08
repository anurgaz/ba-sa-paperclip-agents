# Data Dictionary

> Описание ключевых сущностей платформы. Источник правды для агентов при генерации API спеков и data flow диаграмм.

---

## Merchant

Юридическое лицо, подключённое к платформе для приёма карточных платежей.

| Поле | Тип | Обязательное | Описание | PII | Retention | Пример |
|------|-----|-------------|----------|-----|-----------|--------|
| id | UUID | Да | Внутренний идентификатор | Нет | Permanent | 550e8400-e29b-41d4-a716-446655440000 |
| mid | String(15) | Да | Merchant ID (уникальный) | Нет | Permanent | 123456789012345 |
| legal_name | String(255) | Да | Юридическое наименование | Да | 5 лет после offboarding | Acme GmbH |
| trading_name | String(255) | Нет | Торговое наименование | Нет | 5 лет | Acme Shop |
| registration_number | String(50) | Да | Номер регистрации | Да | 5 лет | HRB 123456 |
| country | String(2) | Да | Страна регистрации (ISO 3166-1 alpha-2) | Нет | 5 лет | DE |
| legal_address | Object | Да | Юридический адрес | Да | 5 лет | {street, city, postal_code, country} |
| business_type | String(4) | Да | MCC код | Нет | 5 лет | 5411 |
| website_url | String(500) | Да | URL сайта мерчанта | Нет | 5 лет | https://acme-shop.de |
| contact_email | String(255) | Да | Email для связи | Да | 5 лет | merchant@acme.de |
| contact_phone | String(20) | Да | Телефон | Да | 5 лет | +49301234567 |
| iban | String(34) | Да | IBAN для settlement | Да (financial) | 5 лет | DE89370400440532013000 |
| risk_score | Integer | Да | Risk score (0-100) | Нет | 5 лет | 25 |
| risk_level | Enum | Да | LOW / MEDIUM / HIGH / CRITICAL | Нет | 5 лет | LOW |
| status | Enum | Да | PENDING / ACTIVE / SUSPENDED / OFFBOARDED | Нет | 5 лет | ACTIVE |
| daily_limit | Decimal | Да | Дневной лимит (EUR) | Нет | 5 лет | 100000.00 |
| monthly_limit | Decimal | Да | Месячный лимит (EUR) | Нет | 5 лет | 2000000.00 |
| settlement_schedule | Enum | Да | T+1 / T+3 / T+7 | Нет | 5 лет | T+1 |
| webhook_url | String(500) | Нет | URL для webhook notifications | Нет | 5 лет | https://acme.de/webhooks |
| created_at | DateTime | Да | Дата создания (ISO 8601) | Нет | 5 лет | 2026-03-08T10:00:00Z |
| updated_at | DateTime | Да | Дата последнего обновления | Нет | 5 лет | 2026-03-08T10:00:00Z |
| kyb_status | Enum | Да | PENDING / VERIFIED / FAILED / MANUAL_REVIEW | Нет | 5 лет | VERIFIED |
| onboarded_at | DateTime | Нет | Дата активации | Нет | 5 лет | 2026-03-09T14:00:00Z |

---

## UBO (Ultimate Beneficial Owner)

Физическое лицо — конечный бенефициарный владелец мерчанта.

| Поле | Тип | Обязательное | Описание | PII | Retention | Пример |
|------|-----|-------------|----------|-----|-----------|--------|
| id | UUID | Да | Внутренний идентификатор | Нет | 5 лет | — |
| merchant_id | UUID | Да | FK → Merchant | Нет | 5 лет | — |
| full_name | String(255) | Да | ФИО | Да | 5 лет | Hans Mueller |
| date_of_birth | Date | Да | Дата рождения | Да | 5 лет | 1985-06-15 |
| nationality | String(2) | Да | Гражданство (ISO 3166-1) | Да | 5 лет | DE |
| ownership_percentage | Decimal | Да | Доля владения (%) | Нет | 5 лет | 40.00 |
| document_type | Enum | Да | PASSPORT / ID_CARD / RESIDENCE_PERMIT | Нет | 5 лет | PASSPORT |
| document_number | String(50) | Да | Номер документа | Да | 5 лет | C01X00T47 |
| kyc_status | Enum | Да | PENDING / VERIFIED / FAILED | Нет | 5 лет | VERIFIED |
| pep_status | Enum | Да | CLEAR / PEP / PEP_ASSOCIATE | Нет | 5 лет | CLEAR |
| sanctions_status | Enum | Да | CLEAR / MATCH / PENDING_REVIEW | Нет | 5 лет | CLEAR |

---

## Transaction

Платёжная транзакция.

| Поле | Тип | Обязательное | Описание | PII | Retention | Пример |
|------|-----|-------------|----------|-----|-----------|--------|
| id | UUID | Да | Внутренний идентификатор | Нет | 5 лет | — |
| merchant_id | UUID | Да | FK → Merchant | Нет | 5 лет | — |
| mid | String(15) | Да | MID мерчанта | Нет | 5 лет | 123456789012345 |
| tid | String(8) | Да | TID терминала | Нет | 5 лет | 00000001 |
| amount | Decimal | Да | Сумма (minor units не используем, EUR в decimal) | Нет | 5 лет | 99.99 |
| currency | String(3) | Да | Валюта (ISO 4217) | Нет | 5 лет | EUR |
| status | Enum | Да | AUTHORIZED / CAPTURED / VOIDED / SETTLED / REFUNDED / DECLINED / ERROR | Нет | 5 лет | AUTHORIZED |
| card_token | String(64) | Да | Токен карты (НЕ PAN\!) | Нет | 5 лет | tok_abc123def456 |
| card_masked | String(19) | Да | Маскированный PAN | Нет | 5 лет | 411111******1111 |
| card_brand | Enum | Да | VISA / MASTERCARD | Нет | 5 лет | VISA |
| card_country | String(2) | Да | Страна эмиссии | Нет | 5 лет | DE |
| auth_code | String(6) | Нет | Authorization code от эмитента | Нет | 5 лет | 123456 |
| response_code | String(2) | Да | ISO 8583 response code | Нет | 5 лет | 00 |
| three_ds_status | Enum | Нет | AUTHENTICATED / ATTEMPTED / FAILED / NOT_ENROLLED / EXEMPT | Нет | 5 лет | AUTHENTICATED |
| sca_exemption | Enum | Нет | LOW_VALUE / TRA / RECURRING / MOTO / null | Нет | 5 лет | null |
| route_id | String(50) | Да | ID маршрута обработки | Нет | 5 лет | route_visa_de_01 |
| idempotency_key | String(64) | Да | Ключ идемпотентности | Нет | 5 лет | idem_xyz789 |
| created_at | DateTime | Да | Время создания | Нет | 5 лет | 2026-03-08T14:30:00Z |
| captured_at | DateTime | Нет | Время capture | Нет | 5 лет | — |
| settled_at | DateTime | Нет | Время settlement | Нет | 5 лет | — |
| metadata | JSON | Нет | Мерчант metadata (order_id и т.д.) | Возможно | 5 лет | {"order_id": "ORD-123"} |

> ⚠️ **C-002:** PAN, CVV, PIN никогда не хранятся. Только card_token и card_masked.

---

## Dispute

Спор / чарджбэк.

| Поле | Тип | Обязательное | Описание | PII | Retention | Пример |
|------|-----|-------------|----------|-----|-----------|--------|
| id | UUID | Да | Внутренний идентификатор | Нет | 5 лет | — |
| transaction_id | UUID | Да | FK → Transaction | Нет | 5 лет | — |
| merchant_id | UUID | Да | FK → Merchant | Нет | 5 лет | — |
| type | Enum | Да | CHARGEBACK / PRE_ARBITRATION / ARBITRATION | Нет | 5 лет | CHARGEBACK |
| reason_code | String(10) | Да | Reason code (Visa/MC) | Нет | 5 лет | 13.1 |
| reason_description | String(255) | Да | Описание reason code | Нет | 5 лет | Merchandise Not Received |
| amount | Decimal | Да | Сумма спора | Нет | 5 лет | 99.99 |
| currency | String(3) | Да | Валюта | Нет | 5 лет | EUR |
| status | Enum | Да | RECEIVED / REPRESENTED / PRE_ARBITRATION / ARBITRATION / RESOLVED_MERCHANT / RESOLVED_ISSUER / RESOLVED_FINAL | Нет | 5 лет | RECEIVED |
| filing_date | Date | Да | Дата подачи chargeback | Нет | 5 лет | 2026-03-01 |
| deadline | Date | Да | Дедлайн для representment | Нет | 5 лет | 2026-03-31 |
| evidence_urls | Array[String] | Нет | URLs загруженных доказательств | Нет | 5 лет | — |
| resolved_at | DateTime | Нет | Дата разрешения | Нет | 5 лет | — |

---

## Settlement

Расчёт с мерчантом.

| Поле | Тип | Обязательное | Описание | PII | Retention | Пример |
|------|-----|-------------|----------|-----|-----------|--------|
| id | UUID | Да | Внутренний идентификатор | Нет | 5 лет | — |
| merchant_id | UUID | Да | FK → Merchant | Нет | 5 лет | — |
| period_start | DateTime | Да | Начало периода | Нет | 5 лет | 2026-03-07T00:00:00Z |
| period_end | DateTime | Да | Конец периода | Нет | 5 лет | 2026-03-07T23:59:59Z |
| gross_amount | Decimal | Да | Общая сумма транзакций | Нет | 5 лет | 15000.00 |
| refunds_amount | Decimal | Да | Сумма возвратов | Нет | 5 лет | 200.00 |
| chargebacks_amount | Decimal | Да | Сумма чарджбэков | Нет | 5 лет | 0.00 |
| fees_amount | Decimal | Да | Комиссии (MDR) | Нет | 5 лет | 270.00 |
| net_amount | Decimal | Да | К выплате мерчанту | Нет | 5 лет | 14530.00 |
| currency | String(3) | Да | Валюта | Нет | 5 лет | EUR |
| status | Enum | Да | PENDING / PROCESSING / COMPLETED / FAILED | Нет | 5 лет | COMPLETED |
| payout_reference | String(50) | Нет | Референс банковского перевода | Нет | 5 лет | PAY-20260308-001 |
| transaction_count | Integer | Да | Количество транзакций в batch | Нет | 5 лет | 342 |
| settled_at | DateTime | Нет | Дата фактического перевода | Нет | 5 лет | 2026-03-09T10:00:00Z |
