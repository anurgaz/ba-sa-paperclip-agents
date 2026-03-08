# SLA Metrics

> Целевые показатели уровня обслуживания платформы.

---

## Доступность (Availability)

| Метрика | Target | Measurement | Reporting |
|---------|--------|-------------|-----------|
| Authorization Service Uptime | ≥99.95% | (total_minutes - downtime_minutes) / total_minutes | Monthly |
| API Gateway Uptime | ≥99.9% | Health check endpoint, 30s interval | Monthly |
| Dashboard Uptime | ≥99.5% | Synthetic monitoring | Monthly |
| Settlement Service Uptime | ≥99.9% | Job completion rate | Monthly |

## Latency

| Метрика | Target p50 | Target p95 | Target p99 | Measurement |
|---------|-----------|-----------|-----------|-------------|
| Authorization Response | ≤50ms | ≤200ms | ≤500ms | Time from request receipt to response sent |
| 3DS Challenge Init | ≤100ms | ≤300ms | ≤800ms | Time to redirect/SDK callback |
| API Response (non-auth) | ≤100ms | ≤500ms | ≤1000ms | All non-authorization endpoints |
| Webhook Delivery | ≤500ms | ≤2000ms | ≤5000ms | Time from event to first delivery attempt |
| Batch Settlement Processing | ≤30min | ≤60min | ≤120min | Full batch processing time |

## Онбординг

| Метрика | Target | Condition | Measurement |
|---------|--------|-----------|-------------|
| Merchant Onboarding (auto) | ≤48 часов | KYB pass, risk LOW/MEDIUM | From application to ACTIVE status |
| Merchant Onboarding (manual) | ≤5 рабочих дней | KYB manual review or HIGH risk | From application to ACTIVE status |
| KYB Check Duration | ≤4 часа | Automated check | From initiation to result |
| UBO KYC Check Duration | ≤24 часа | Per UBO | From initiation to result |
| Sanctions Screening | ≤30 секунд | Single entity | Response time from provider |

## Disputes

| Метрика | Target | Measurement |
|---------|--------|-------------|
| Chargeback Notification | ≤1 час | From receipt to merchant notification |
| Representment Submission | ≤24 часа до дедлайна | All represented disputes submitted with buffer |
| Dispute Resolution Time | ≤45 дней | Average from RECEIVED to RESOLVED |

## Data & Reporting

| Метрика | Target | Measurement |
|---------|--------|-------------|
| Settlement Report Availability | T+1 by 09:00 UTC | Report available in dashboard and API |
| Transaction Data Freshness | ≤5 секунд | Delay from transaction to dashboard visibility |
| Audit Log Write | ≤10ms | Time to persist audit entry |
| Sanctions List Update | ≤6 часов | From list publication to system update |

---

> **Связанные constraints:** C-008 (SLA по доступности), C-005 (дедлайны чарджбэков), C-009 (audit trail)
