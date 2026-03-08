# Бизнес-правила: Онбординг мерчантов

> Правила KYB, UBO, sanctions screening и risk scoring при подключении новых мерчантов.

---

## BR-ONB-001: Обязательные данные при регистрации
- **Описание:** При подаче заявки мерчант обязан предоставить минимальный набор данных для инициации KYB
- **Условие:** POST /api/v1/merchants
- **Действие:** Система валидирует наличие обязательных полей: legal_name, registration_number, country, legal_address, business_type (MCC), website_url, contact_email, contact_phone, bank_account (IBAN), expected_monthly_volume, ubo_list (минимум 1 UBO)
- **Исключения:** Нет. Все поля обязательны
- **Связанные constraints:** C-003, C-008

## BR-ONB-002: KYB проверка юридического лица
- **Описание:** Автоматическая верификация юр. лица через KYC/KYB провайдера
- **Условие:** После успешной валидации BR-ONB-001
- **Действие:** 
  1. Запрос к KYB провайдеру: проверка регистрации, статуса компании, адреса
  2. Проверка MCC на blacklist (7995 Gambling, 5967 Direct Marketing — требуют EDD)
  3. Автоматический company_status: VERIFIED / FAILED / MANUAL_REVIEW
  4. FAILED → rejection с reason code
  5. MANUAL_REVIEW → эскалация на Compliance
- **Исключения:** MCC из high-risk категорий → всегда MANUAL_REVIEW независимо от результата KYB
- **Связанные constraints:** C-003, C-004

## BR-ONB-003: Идентификация UBO
- **Описание:** Все UBO с долей ≥25% проходят KYC верификацию
- **Условие:** KYB проверка компании = VERIFIED или MANUAL_REVIEW
- **Действие:**
  1. Для каждого UBO: проверка документа (паспорт/ID), liveness check, proof of address
  2. Sanctions screening по всем спискам (EU, OFAC, UN, UK HMT)
  3. PEP check
  4. Результат: CLEAR / MATCH / PEP_FLAG
  5. MATCH → немедленная блокировка заявки + эскалация на MLRO (C-004)
  6. PEP_FLAG → Enhanced Due Diligence (EDD), эскалация на Compliance
  7. Все UBO CLEAR → продолжение онбординга
- **Исключения:** Если сумма долей идентифицированных UBO < 75%, система запрашивает разъяснение структуры собственности
- **Связанные constraints:** C-003, C-004

## BR-ONB-004: Risk scoring мерчанта
- **Описание:** Автоматический расчёт risk score на основе профиля мерчанта
- **Условие:** KYB VERIFIED + все UBO CLEAR
- **Действие:**
  1. Risk factors: MCC category (weight 30%), country risk (20%), expected volume (15%), business age (15%), UBO PEP status (20%)
  2. Score: 0-100 (0 = low risk, 100 = high risk)
  3. Score 0-30: LOW → auto-approve, standard limits
  4. Score 31-60: MEDIUM → auto-approve, reduced limits, monthly review
  5. Score 61-80: HIGH → manual review by Risk Manager
  6. Score 81-100: CRITICAL → rejection или EDD + senior management approval
- **Исключения:** Мерчант из sanctioned country → автоматический CRITICAL независимо от score
- **Связанные constraints:** C-003, C-004, C-006

## BR-ONB-005: Создание MID и терминала
- **Описание:** После одобрения — создание MID, TID и настройка processing parameters
- **Условие:** Risk scoring пройден (LOW/MEDIUM auto-approve или HIGH/CRITICAL manual approve)
- **Действие:**
  1. Генерация уникального MID (15 цифр)
  2. Создание виртуального TID для e-commerce
  3. Установка начальных лимитов: daily_limit, monthly_limit, single_transaction_limit (на основе risk score и expected volume)
  4. Настройка settlement schedule (T+1 для LOW, T+3 для MEDIUM, T+7 для HIGH)
  5. Активация webhook endpoints мерчанта
  6. Статус мерчанта: ACTIVE
- **Исключения:** Если мерчант не настроил webhook в течение 7 дней → статус PENDING_SETUP, напоминание
- **Связанные constraints:** C-008, C-009

## BR-ONB-006: Ongoing мониторинг после онбординга
- **Описание:** Периодическая переоценка мерчанта
- **Условие:** Мерчант в статусе ACTIVE
- **Действие:**
  1. Daily: sanctions re-screening всей базы мерчантов и UBO (C-004)
  2. Monthly: пересчёт risk score на основе фактических данных (chargeback ratio, volume deviation)
  3. Quarterly: проверка актуальности KYB данных
  4. При срабатывании: alert → Compliance review
  5. Chargeback ratio > 1% → уведомление мерчанту + enhanced monitoring
  6. Chargeback ratio > 1.5% → эскалация на Risk Manager + возможная блокировка
- **Исключения:** Мерчанты в статусе SUSPENDED не проходят ongoing, только sanctions screening
- **Связанные constraints:** C-004, C-005, C-006

## BR-ONB-007: Блокировка и выход мерчанта
- **Описание:** Процедура suspension и offboarding
- **Условие:** Sanctions match / Excessive chargebacks / Fraud / Manual decision
- **Действие:**
  1. SUSPENSION: немедленная остановка processing, hold settlement
  2. Уведомление мерчанту с reason code (кроме sanctions — без раскрытия)
  3. Retention: данные хранятся 5 лет после offboarding (AML retention, C-007)
  4. Open disputes — обрабатываются до завершения
  5. Final settlement — после resolution всех disputes
- **Исключения:** При sanctions match — не уведомлять мерчанта о причине (tipping-off prohibition). Только "regulatory requirements"
- **Связанные constraints:** C-004, C-005, C-006, C-007
