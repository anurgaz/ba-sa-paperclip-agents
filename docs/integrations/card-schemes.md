# Интеграция с карточными схемами (Visa / Mastercard)

> Спецификация взаимодействия с Visa и Mastercard для авторизации, клиринга и settlement.

---

## Общая архитектура

```
Merchant → Payment Service API → Processing Engine → Card Scheme Network → Issuer
                                    ↕
                              Tokenization Service
                                    ↕
                              Audit Log Service
```

## Visa

### Authorization (VisaNet)
- **Протокол:** ISO 8583:1987 (bitmap-based message format)
- **Endpoint:** VisaNet Authorization Gateway (VPN/leased line)
- **Message Type:** 0100 (Authorization Request), 0110 (Authorization Response)
- **Ключевые поля:**
  - DE2: PAN (из токенизации, в CDE)
  - DE3: Processing Code (00 = purchase, 20 = refund)
  - DE4: Amount (minor units, 12 digits)
  - DE11: STAN (System Trace Audit Number)
  - DE12/13: Date/Time
  - DE22: POS Entry Mode (e-commerce: 81x)
  - DE25: POS Condition Code
  - DE37: RRN (Retrieval Reference Number)
  - DE38: Auth Code (in response)
  - DE39: Response Code (00 = approved, 05 = declined, 51 = insufficient funds)
  - DE41: TID
  - DE42: MID
  - DE43: Merchant Name/Location
  - DE49: Currency Code
  - DE55: EMV/Chip data (for 3DS)
- **Timeout:** 30 секунд (Visa requirement)
- **Rate Limit:** Зависит от контракта, typically unlimited для авторизаций

### Clearing (TC05)
- **Протокол:** TC05 (Transaction Clearing) file-based
- **Формат:** Fixed-length record, batch file
- **Расписание:** Daily, cutoff 23:00 UTC
- **Содержимое:** Все captured транзакции за период
- **Settlement:** T+1 business day после clearing

### 3-D Secure 2.x (Visa Secure)
- **Протокол:** EMV 3DS 2.2
- **Компоненты:** 3DS Server (Payment Service) → Directory Server (Visa) → ACS (Issuer)
- **Flow:**
  1. AReq (Authentication Request) → Visa DS
  2. Visa DS → Issuer ACS
  3. ARes (frictionless / challenge)
  4. If challenge: CReq/CRes через браузер/SDK
  5. RReq/RRes (Results Request)
- **Timeout:** 10 секунд на AReq, 5 минут на challenge

### Dispute (VROL)
- **Система:** Visa Resolve Online (VROL)
- **Notification:** TC40 (fraud), chargeback advice
- **Representment:** Upload через VROL portal / API
- **Дедлайны:** 30 дней representment, 30 дней pre-arb

---

## Mastercard

### Authorization (Banknet)
- **Протокол:** ISO 8583:1993
- **Endpoint:** Mastercard Banknet (VPN/leased line)
- **Message Type:** Аналогично Visa, различия в DE-specific values
- **Ключевые отличия от Visa:**
  - DE48: Additional Data (Mastercard-specific TLV)
  - DE61: POS Data (Card Data Input Capability)
  - Processing Network ID в DE63
- **Timeout:** 30 секунд
- **Rate Limit:** Зависит от контракта

### Clearing (IPM)
- **Протокол:** Integrated Processing Message (IPM) file
- **Формат:** Variable-length, tagged data
- **Расписание:** Daily, multiple cycles
- **Settlement:** T+1 business day

### 3-D Secure 2.x (Mastercard Identity Check)
- **Протокол:** EMV 3DS 2.2 (идентичен Visa на уровне протокола)
- **Компоненты:** 3DS Server → Mastercard DS → Issuer ACS
- **Отличие:** Mastercard SecureCode legacy fallback для 3DS 1.0

### Dispute (Mastercom)
- **Система:** Mastercom (Mastercard Connect)
- **Notification:** First chargeback notification
- **Representment:** через Mastercom portal / API
- **Дедлайны:** 45 дней representment, 45 дней pre-arb

---

## Общие требования к интеграции

| Требование | Описание | Constraint |
|-----------|----------|------------|
| PAN security | PAN передаётся только в CDE, через HSM | C-002, C-010 |
| TLS | Минимум TLS 1.2 для всех соединений | C-002 |
| Audit logging | Каждая авторизация логируется (без PAN) | C-009 |
| Idempotency | STAN + RRN обеспечивают уникальность | Tech stack principle |
| Failover | Dual-link к каждой scheme, automatic failover | C-008 |
| Certification | Ежегодная рекертификация у каждой scheme | Regulatory |

---

> **Для агентов:** при генерации API спеков и sequence диаграмм учитывайте ISO 8583 message flow. PAN появляется ТОЛЬКО внутри CDE компонентов. Все внешние API работают с токенами.
