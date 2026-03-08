# Бизнес-правила: AML/CTF

> Пороги мониторинга, сценарии подозрительной активности, эскалация на MLRO.

---

## BR-AML-001: Порог единичной транзакции
- **Описание:** Enhanced мониторинг для крупных транзакций
- **Условие:** Сумма транзакции ≥ €15,000 (или эквивалент по курсу ECB)
- **Действие:**
  1. Автоматический флаг: HIGH_VALUE_TRANSACTION
  2. Enhanced logging: полные детали плательщика, получателя, назначение
  3. Alert в TMS (Transaction Monitoring System)
  4. Если первая транзакция мерчанта > €15,000 → дополнительный alert
  5. Report в daily summary для MLRO review
- **Исключения:** Нет. Порог регуляторный (AMLD5), не может быть изменён
- **Связанные constraints:** C-006

## BR-AML-002: Кумулятивный порог (structuring detection)
- **Описание:** Обнаружение попыток дробления транзакций (structuring/smurfing)
- **Условие:** Агрегация по: merchant + payer (card BIN + last 4) за 24 часа
- **Действие:**
  1. Если сумма транзакций от одного плательщика к одному мерчанту за 24ч ≥ €15,000:
     - Alert: POSSIBLE_STRUCTURING
     - TMS notification
     - Включение в MLRO daily report
  2. Если ≥3 транзакций от одного плательщика к разным мерчантам за 24ч, суммарно ≥ €10,000:
     - Alert: CROSS_MERCHANT_STRUCTURING
     - Приоритетный review
  3. Паттерн: транзакции just below threshold (€14,500-€14,999) → JUST_BELOW_THRESHOLD alert
- **Исключения:** Recurring payments с установленным mandate — исключены из structuring detection (но не из cumulative monitoring)
- **Связанные constraints:** C-006

## BR-AML-003: Velocity anomaly
- **Описание:** Обнаружение аномально высокой частоты транзакций
- **Условие:** Ongoing мониторинг per MID
- **Действие:**
  1. Baseline: средняя частота транзакций за последние 30 дней
  2. Alert если: текущая частота > 3× baseline за 1 час
  3. Alert если: объём за день > 5× среднедневного за 30 дней
  4. Новый мерчант (< 30 дней): использовать baseline по MCC category
  5. Alert → TMS → MLRO daily report
  6. Критичная аномалия (>10× baseline) → немедленная эскалация на MLRO
- **Исключения:** Запланированные промо-акции мерчанта (pre-registered в системе) → повышенный baseline на период акции
- **Связанные constraints:** C-006

## BR-AML-004: Geographic anomaly
- **Описание:** Подозрительные географические паттерны
- **Условие:** Ongoing мониторинг
- **Действие:**
  1. Мерчант зарегистрирован в стране A, >50% транзакций из high-risk стран (FATF Grey/Black list) → GEOGRAPHIC_ANOMALY alert
  2. Карта выпущена в стране A, мерчант в стране B (cross-border), сумма > €5,000 → enhanced logging
  3. >10 разных стран происхождения карт за 1 час для одного MID → GEOGRAPHIC_VELOCITY alert
  4. Sanctioned country (любая транзакция) → BLOCK + немедленная эскалация
- **Исключения:** Travel-related MCC (airlines, hotels) — ожидаемо высокий cross-border, повышенные пороги
- **Связанные constraints:** C-004, C-006

## BR-AML-005: SAR (Suspicious Activity Report)
- **Описание:** Процесс подачи отчёта о подозрительной активности
- **Условие:** MLRO принимает решение о подаче на основе alerts
- **Действие:**
  1. SAR — ТОЛЬКО ручное решение MLRO (агент НЕ автоматизирует подачу)
  2. MLRO анализирует alert, собирает дополнительную информацию
  3. Решение: FILE_SAR / DISMISS (с обоснованием)
  4. FILE_SAR: подготовка отчёта (система помогает собрать данные), подача в FIU в течение рабочего дня
  5. DISMISS: документирование причины в audit log
  6. Tipping-off prohibition: мерчант НЕ уведомляется о SAR
  7. Все SAR решения — в защищённом audit log (доступ: MLRO + Deputy MLRO only)
- **Исключения:** Нет. SAR flow не автоматизируется. Система только агрегирует данные для MLRO
- **Связанные constraints:** C-006, C-009

## BR-AML-006: PEP мониторинг
- **Описание:** Усиленный мониторинг для PEP и связанных лиц
- **Условие:** UBO/директор с PEP статусом
- **Действие:**
  1. При онбординге: EDD обязателен (source of wealth, source of funds)
  2. Senior management approval для онбординга PEP мерчанта
  3. Ongoing: transaction monitoring с пониженными порогами (50% от стандартных)
  4. Quarterly review PEP статуса (всё ещё PEP? family member? close associate?)
  5. Annual EDD refresh
  6. Все решения по PEP мерчантам → MLRO log
- **Исключения:** Former PEP (>12 месяцев с окончания должности) → стандартные пороги, но quarterly PEP re-check остаётся
- **Связанные constraints:** C-003, C-006

## BR-AML-007: Batch sanctions re-screening
- **Описание:** Ежедневная перепроверка всех мерчантов и UBO по обновлённым санкционным спискам
- **Условие:** Daily scheduled job, 06:00 UTC
- **Действие:**
  1. Загрузка обновлённых списков: EU Consolidated, OFAC SDN, UN, UK HMT
  2. Скрининг: все active мерчанты + все UBO
  3. Fuzzy matching: threshold 85% similarity
  4. Potential match → PENDING_REVIEW, alert MLRO
  5. Confirmed match → немедленная SUSPENSION мерчанта (C-004)
  6. False positive → документирование, whitelist entry (с обоснованием)
  7. Report: количество скринингов, matches, false positives → MLRO daily summary
- **Исключения:** Новые мерчанты, прошедшие screening <24ч назад → skip (avoid duplicate)
- **Связанные constraints:** C-004, C-009
