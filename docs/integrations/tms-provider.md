# Интеграция с Transaction Monitoring System (TMS)

> Спецификация взаимодействия с провайдером мониторинга транзакций для AML/CTF.

---

## Provider

| Параметр | Значение |
|----------|---------|
| Провайдер | _TBD_ (placeholder: Generic TMS Provider) |
| Base URL | `https://api.tms-provider.example/v1` |
| Auth | OAuth 2.0 Client Credentials |
| Format | REST JSON + Event Stream |
| Rate Limit | 1000 req/min |
| SLA | 99.95% uptime, p95 <100ms for scoring |

## Real-time Transaction Scoring

### POST /transactions/score

Вызывается для каждой транзакции перед авторизацией.

**Request:**
```json
{
  "transaction_id": "txn_550e8400",
  "merchant": {
    "mid": "123456789012345",
    "mcc": "5411",
    "country": "DE",
    "risk_level": "LOW"
  },
  "transaction": {
    "amount": 150.00,
    "currency": "EUR",
    "type": "PURCHASE",
    "card_token": "tok_abc123",
    "card_country": "DE",
    "card_brand": "VISA",
    "ip_country": "DE",
    "three_ds_result": "AUTHENTICATED"
  },
  "context": {
    "is_recurring": false,
    "velocity_1h": 3,
    "velocity_24h": 12,
    "cumulative_24h": 450.00
  }
}
```

**Response (sync):**
```json
{
  "transaction_id": "txn_550e8400",
  "risk_score": 15,
  "risk_level": "LOW",
  "recommendation": "APPROVE",
  "alerts": [],
  "rules_triggered": [],
  "processing_time_ms": 45
}
```

**Recommendation values:**
| Value | Действие Flowlix |
|-------|-----------------|
| APPROVE | Продолжить авторизацию |
| REVIEW | Авторизовать + создать alert для manual review |
| DECLINE | Отклонить транзакцию (response code 05) |
| BLOCK | Отклонить + заблокировать карту для MID |

## Alert Types

### AML Alerts (async via webhook)

```json
{
  "alert_id": "alert_abc123",
  "type": "AML_THRESHOLD | STRUCTURING | VELOCITY_ANOMALY | GEOGRAPHIC_ANOMALY | PEP_TRANSACTION",
  "severity": "LOW | MEDIUM | HIGH | CRITICAL",
  "merchant_id": "merchant_001",
  "description": "Cumulative transactions from single payer exceeded €15,000 in 24h window",
  "transactions": ["txn_001", "txn_002", "txn_003"],
  "cumulative_amount": 15500.00,
  "created_at": "2026-03-08T16:30:00Z",
  "requires_action": true,
  "action_deadline": "2026-03-09T16:30:00Z"
}
```

### Fraud Alerts

```json
{
  "alert_id": "alert_def456",
  "type": "CARD_TESTING | BIN_ATTACK | RAPID_VELOCITY | AMOUNT_ANOMALY",
  "severity": "HIGH",
  "merchant_id": "merchant_001",
  "description": "50 low-value transactions (<€1) in 10 minutes from different cards — possible card testing",
  "recommendation": "BLOCK_AND_REVIEW",
  "created_at": "2026-03-08T17:00:00Z"
}
```

## Event Stream (async monitoring)

### POST /events (Flowlix → TMS)

Flowlix отправляет поток событий для offline analysis.

**Events:**
- `transaction.authorized` — каждая авторизация
- `transaction.captured` — capture
- `transaction.refunded` — refund
- `merchant.onboarded` — новый мерчант
- `merchant.suspended` — блокировка
- `dispute.received` — входящий chargeback

**Format:** JSON Lines, батчами по 100 events / 5 секунд.

## Reporting API

### GET /reports/merchant/{mid}

Возвращает AML risk profile мерчанта.

```json
{
  "mid": "123456789012345",
  "period": "2026-03",
  "risk_score": 25,
  "alerts_count": {"total": 3, "high": 0, "medium": 1, "low": 2},
  "flags": [],
  "recommendation": "CONTINUE_MONITORING"
}
```

## Error Handling

| HTTP Status | Действие Flowlix |
|------------|-----------------|
| Timeout (>200ms) | Авторизовать (fail-open) + log + async retry scoring | 
| 503 Unavailable | Авторизовать (fail-open) + immediate alert to Operations |
| 4xx | Log error, do not retry, авторизовать с internal scoring |

> **ВАЖНО:** TMS unavailability НЕ блокирует авторизацию (fail-open). Но все транзакции за период недоступности помечаются для retroactive scoring.

---

> **Связанные constraints:** C-006 (AML пороги), C-008 (latency SLA), C-009 (audit log)
