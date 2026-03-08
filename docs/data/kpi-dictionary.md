# KPI Dictionary

> Ключевые бизнес-метрики платформы. Используются агентами при генерации отчётов и dashboard спецификаций.

---

## Транзакционные KPI

| KPI | Формула | Target | Frequency | Owner |
|-----|---------|--------|-----------|-------|
| Approval Rate | (approved_txn / total_txn) × 100% | ≥92% | Daily | Operations |
| Decline Rate | (declined_txn / total_txn) × 100% | ≤8% | Daily | Operations |
| Authorization Error Rate | (error_txn / total_txn) × 100% | ≤0.1% | Daily | Engineering |
| 3DS Challenge Rate | (challenged_txn / 3ds_txn) × 100% | ≤30% (frictionless preferred) | Weekly | Product |
| 3DS Conversion Rate | (authenticated_txn / challenged_txn) × 100% | ≥85% | Weekly | Product |
| Average Transaction Value (ATV) | total_volume / total_txn | Depends on MCC mix | Monthly | Finance |

## Объёмные KPI

| KPI | Формула | Target | Frequency | Owner |
|-----|---------|--------|-----------|-------|
| Total Payment Volume (TPV) | SUM(settled_amount) per period | Growth target (confidential) | Monthly | Finance |
| Transaction Count | COUNT(transactions) per period | Growth target | Monthly | Finance |
| Active Merchants | COUNT(merchants WHERE status=ACTIVE) | Growth target | Monthly | Sales |
| New Merchants | COUNT(merchants WHERE onboarded_at in period) | Growth target | Monthly | Sales |

## Risk KPI

| KPI | Формула | Target | Frequency | Owner |
|-----|---------|--------|-----------|-------|
| Chargeback Ratio | (chargeback_count / txn_count) × 100% per MID | <0.5% (GREEN) | Monthly | Risk |
| Chargeback Amount Ratio | (chargeback_amount / txn_amount) × 100% | <0.3% | Monthly | Risk |
| Fraud Rate (basis points) | (fraud_amount / txn_amount) × 10,000 | <9 bps (Visa VFMP threshold) | Monthly | Risk |
| Representment Win Rate | (won_disputes / represented_disputes) × 100% | ≥45% | Monthly | Disputes |
| Dispute Response Rate | (represented / total_chargebacks) × 100% | ≥90% | Monthly | Disputes |
| Average Dispute Resolution Time | AVG(resolved_at - filing_date) | ≤30 дней | Monthly | Disputes |

## Операционные KPI

| KPI | Формула | Target | Frequency | Owner |
|-----|---------|--------|-----------|-------|
| Onboarding Conversion Rate | (activated / applied) × 100% | ≥70% | Monthly | Operations |
| Onboarding Time (auto) | AVG(activated_at - applied_at) WHERE auto_approved | ≤48 часов | Weekly | Operations |
| Onboarding Time (manual) | AVG(activated_at - applied_at) WHERE manual_review | ≤5 дней | Weekly | Operations |
| Merchant Churn Rate | (offboarded / active_start) × 100% | <2% | Monthly | Account Management |
| Settlement Accuracy | (correct_settlements / total_settlements) × 100% | 100% | Monthly | Finance |
| Settlement On-Time Rate | (on_time_settlements / total_settlements) × 100% | ≥99.5% | Monthly | Finance |

## AML/Compliance KPI

| KPI | Формула | Target | Frequency | Owner |
|-----|---------|--------|-----------|-------|
| Sanctions Screening Coverage | (screened_entities / total_entities) × 100% | 100% | Daily | Compliance |
| False Positive Rate (Sanctions) | (false_positives / total_matches) × 100% | Reporting only | Monthly | Compliance |
| SAR Filing Time | AVG(filed_at - alert_created_at) | ≤1 рабочий день | Monthly | MLRO |
| Alert Review Time | AVG(reviewed_at - alert_created_at) | ≤4 часа | Weekly | Compliance |
| KYB Auto-Approval Rate | (auto_approved / total_kyb) × 100% | ≥60% | Monthly | Compliance |

---

> **Для агентов:** при генерации dashboard/reporting артефактов используйте KPI из этого словаря. Формулы и targets — источник правды. Не придумывайте новые метрики без согласования.
