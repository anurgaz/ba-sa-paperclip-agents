# Бизнес-правила: Споры и чарджбэки

> Дедлайны Visa/Mastercard, representment flow, арбитраж.

---

## BR-DSP-001: Приём чарджбэка
- **Описание:** Обработка входящего chargeback от card scheme
- **Условие:** Получение chargeback notification (Visa TC40 / MC System to Avoid Fraud)
- **Действие:**
  1. Парсинг: reason code, amount, original transaction ID, filing date
  2. Создание Dispute entity: статус RECEIVED
  3. Списание суммы chargeback с баланса мерчанта (provisional debit)
  4. Уведомление мерчанту: email + webhook + dashboard alert
  5. Включение таймера дедлайна:
     - Visa: 30 календарных дней на representment
     - Mastercard: 45 календарных дней
  6. Alert за 5 дней до дедлайна
  7. Audit log entry
- **Исключения:** Fraud chargeback (reason 10.x Visa) → дополнительное уведомление Risk Manager
- **Связанные constraints:** C-005, C-009

## BR-DSP-002: Representment (оспаривание мерчантом)
- **Описание:** Мерчант оспаривает chargeback, предоставляя доказательства
- **Условие:** POST /api/v1/disputes/{id}/represent (до дедлайна)
- **Действие:**
  1. Валидация: dispute в статусе RECEIVED, дедлайн не истёк
  2. Мерчант предоставляет compelling evidence по reason code:
     - 13.1 (Merchandise Not Received): tracking number, delivery confirmation
     - 13.2 (Not as Described): product description, return policy, communication
     - 10.4 (Fraud): 3DS authentication proof, AVS/CVV match, device fingerprint
     - 11.1 (Card Recovery Bulletin): valid authorization code
  3. Формирование representment package
  4. Отправка в card scheme
  5. Статус → REPRESENTED
  6. Ожидание решения scheme (30-45 дней)
  7. Won → credit мерчанту, статус RESOLVED_MERCHANT
  8. Lost → статус PRE_ARBITRATION_ELIGIBLE или RESOLVED_ISSUER
- **Исключения:** Если мерчант не предоставил evidence до дедлайна → auto-accept chargeback, статус RESOLVED_ISSUER. Сумма <€25 → рекомендация accept (cost of representment > amount)
- **Связанные constraints:** C-005, C-009

## BR-DSP-003: Pre-Arbitration
- **Описание:** Второй этап оспаривания после проигранного representment
- **Условие:** Dispute в статусе PRE_ARBITRATION_ELIGIBLE
- **Действие:**
  1. Мерчант решает: принять (accept loss) или продолжить (pre-arb)
  2. Дедлайн: Visa 30 дней, MC 45 дней от получения pre-arb notification
  3. Дополнительные доказательства или новые аргументы
  4. Filing fee: Visa $500, MC $300 (примерно)
  5. Отправка в card scheme
  6. Статус → PRE_ARBITRATION
  7. Решение scheme → final (кроме Arbitration)
- **Исключения:** Auto-decline pre-arb если: сумма < filing fee, или предыдущий win rate для данного reason code < 20%
- **Связанные constraints:** C-005, C-009

## BR-DSP-004: Arbitration
- **Описание:** Финальный этап разрешения спора через card scheme
- **Условие:** Pre-arbitration проигран, мерчант хочет продолжить
- **Действие:**
  1. Filing fee: Visa $500, MC $500 (non-refundable для проигравшей стороны)
  2. Card scheme выступает арбитром
  3. Решение финальное и обязательное
  4. Статус → ARBITRATION → RESOLVED_FINAL
  5. Редко используется (cost > benefit в большинстве случаев)
- **Исключения:** Рекомендация: arbitration только если amount > €5,000 и win probability > 70% (на основе historical data)
- **Связанные constraints:** C-005

## BR-DSP-005: Fraud Monitoring и Early Warning
- **Описание:** Раннее обнаружение fraud patterns для предотвращения chargebacks
- **Условие:** Ongoing мониторинг
- **Действие:**
  1. Visa VFMP (Visa Fraud Monitoring Program): chargeback-to-sales ratio threshold
     - Standard: >0.9% fraud basis points AND >$75,000 fraud volume
     - Excessive: >1.8% basis points AND >$250,000
  2. MC BRAM (Business Risk Assessment and Mitigation):
     - Standard: >1.0% chargeback ratio AND >$50,000
     - Excessive: >1.5% AND >$150,000
  3. При приближении к threshold (80%): alert мерчанту + Risk Manager
  4. При превышении: remediation plan, возможные штрафы от scheme
  5. При повторном нарушении: SUSPENSION мерчанта
- **Исключения:** Seasonal спайки (Black Friday, Cyber Monday) — отдельный baseline
- **Связанные constraints:** C-005, C-006

## BR-DSP-006: Chargeback Ratio KPI
- **Описание:** Отслеживание и реагирование на chargeback ratio
- **Условие:** Monthly расчёт per MID
- **Действие:**
  1. Формула: (количество chargebacks за месяц / количество транзакций за месяц) × 100%
  2. GREEN: <0.5% → нормальный режим
  3. YELLOW: 0.5-0.9% → alert мерчанту, enhanced monitoring
  4. ORANGE: 0.9-1.5% → formal warning, remediation plan required
  5. RED: >1.5% → suspension processing, эскалация на Risk Committee
  6. Тренд: если ratio растёт 3 месяца подряд (даже в GREEN) → proactive alert
- **Исключения:** Новые мерчанты (первые 3 месяца) → minimum 100 транзакций для статистической значимости
- **Связанные constraints:** C-005, C-008
