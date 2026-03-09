---
title: "Document — api specification post api v1 merchants"
agent: sa
type: document
date: 2026-03-09 11:17 UTC
validation: 4/4 PASS
---

# API Specification: POST /api/v1/merchants
# Онбординг мерчанта
# Status: [DRAFT]
# Constraints: C-003, C-004, C-007, C-009, C-012
# Version: 1.0
# Last Updated: 2024-01-XX

openapi: 3.1.0
info:
  title: Flowlix Merchant Onboarding API
  version: 1.0.0
  description: API для онбординга мерчантов в B2B карточный процессинг

servers:
  - url: https://api.flowlix.com/v1
    description: Production
  - url: https://api-staging.flowlix.com/v1
    description: Staging

paths:
  /merchants:
    post:
      summary: Онбординг нового мерчанта
      description: |
        Создаёт нового мерчанта в системе с полным KYB процессом.
        
        **Constraints применяются:**
        - C-003: Обязательная идентификация всех UBO ≥25%
        - C-004: Sanctions screening при онбординге
        - C-007: GDPR минимизация данных
        - C-009: Полное логирование операции
        - C-012: Rate limiting 5 req/min per IP
        
        **SLA:** 48 часов на завершение онбординга при прохождении KYB (C-008)
      
      operationId: createMerchant
      
      security:
        - BearerAuth: []
      
      parameters:
        - name: Idempotency-Key
          in: header
          required: true
          schema:
            type: string
            format: uuid
          description: UUID для обеспечения идемпотентности операции
      
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateMerchantRequest'
            example:
              company:
                legal_name: "Tech Solutions Ltd"
                trading_name: "TechShop"
                registration_number: "12345678"
                tax_id: "GB123456789"
                incorporation_date: "2020-01-15"
                registration_country: "GB"
                registered_address:
                  street: "123 Business Ave"
                  city: "London"
                  postal_code: "SW1A 1AA"
                  country: "GB"
                trading_address:
                  street: "456 Commerce St"
                  city: "London"
                  postal_code: "E1 6AN"
                  country: "GB"
                website_url: "https://techshop.com"
                business_description: "Online electronics retailer"
                mcc: "5732"
              ubos:
                - first_name: "John"
                  last_name: "Smith"
                  date_of_birth: "1980-05-15"
                  nationality: "GB"
                  ownership_percentage: 60.5
                  is_pep: false
                  address:
                    street: "789 Residential Rd"
                    city: "London"
                    postal_code: "N1 2AB"
                    country: "GB"
                  document:
                    type: "passport"
                    number: "987654321"
                    expiry_date: "2030-12-31"
                    issuing_country: "GB"
              contact_person:
                first_name: "Jane"
                last_name: "Doe"
                email: "jane.doe@techshop.com"
                phone: "+44 20 1234 5678"
                position: "CFO"
              processing_details:
                monthly_volume_estimate: 100000
                average_ticket_size: 75.50
                processing_countries: ["GB", "FR", "DE"]
                currencies: ["GBP", "EUR"]
                settlement_account:
                  account_number: "12345678"
                  sort_code: "12-34-56"
                  bank_name: "Example Bank"

      responses:
        '201':
          description: Мерчант успешно создан и отправлен на KYB верификацию
          headers:
            X-Request-ID:
              schema:
                type: string
                format: uuid
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CreateMerchantResponse'
              example:
                merchant_id: "mrc_123e4567-e89b-12d3-a456-426614174000"
                status: "kyb_pending"
                created_at: "2024-01-15T10:30:00Z"
                estimated_approval_date: "2024-01-17T10:30:00Z"
                kyb_reference: "kyb_456789"
                next_steps: [
                  "Document verification in progress",
                  "Sanctions screening initiated",
                  "UBO verification pending"
                ]
                
        '400':
          description: Неверный запрос - ошибки валидации
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              examples:
                validation_error:
                  summary: Ошибка валидации
                  value:
                    error:
                      code: "VALIDATION_ERROR"
                      message: "Validation failed"
                      details:
                        - field: "ubos[0].ownership_percentage"
                          code: "INVALID_VALUE"
                          message: "UBO ownership must be ≥25%"
                        - field: "company.mcc"
                          code: "RESTRICTED_MCC"
                          message: "MCC 7995 (Gambling) not supported"
                    request_id: "req_123e4567"
                    timestamp: "2024-01-15T10:30:00Z"
                    
        '401':
          description: Не авторизован
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              example:
                error:
                  code: "UNAUTHORIZED"
                  message: "Invalid or expired access token"
                request_id: "req_123e4567"
                timestamp: "2024-01-15T10:30:00Z"
                
        '403':
          description: Доступ запрещён
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              example:
                error:
                  code: "FORBIDDEN"
                  message: "Insufficient permissions to create merchant"
                request_id: "req_123e4567"
                timestamp: "2024-01-15T10:30:00Z"
                
        '409':
          description: Конфликт - мерчант с такими данными уже существует
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              example:
                error:
                  code: "MERCHANT_EXISTS"
                  message: "Merchant with this registration number already exists"
                  details:
                    existing_merchant_id: "mrc_987e4567-e89b-12d3-a456-426614174999"
                request_id: "req_123e4567"
                timestamp: "2024-01-15T10:30:00Z"
                
        '422':
          description: Бизнес-правила не выполнены
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              examples:
                sanctions_hit:
                  summary: Попадание в санкционные списки
                  value:
                    error:
                      code: "SANCTIONS_HIT"
                      message: "Entity appears on sanctions list"
                      details:
                        list: "OFAC SDN"
                        match_score: 0.95
                    request_id: "req_123e4567"
                    timestamp: "2024-01-15T10:30:00Z"
                insufficient_ubos:
                  summary: UBO ownership < 100%
                  value:
                    error:
                      code: "INSUFFICIENT_UBO_COVERAGE"
                      message: "Total UBO ownership must equal ≥75%"
                      details:
                        total_coverage: 65.5
                        minimum_required: 75.0
                    request_id: "req_123e4567"
                    timestamp: "2024-01-15T10:30:00Z"
                
        '429':
          description: Rate limit превышен
          headers:
            Retry-After:
              schema:
                type: integer
                example: 60
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              example:
                error:
                  code: "RATE_LIMIT_EXCEEDED"
                  message: "Rate limit exceeded: 5 requests per minute"
                  details:
                    limit: 5
                    window: "1 minute"
                    retry_after: 60
                request_id: "req_123e4567"
                timestamp: "2024-01-15T10:30:00Z"
                
        '500':
          description: Внутренняя ошибка сервера
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              example:
                error:
                  code: "INTERNAL_SERVER_ERROR"
                  message: "An unexpected error occurred"
                request_id: "req_123e4567"
                timestamp: "2024-01-15T10:30:00Z"

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: OAuth 2.0 Bearer token

  schemas:
    CreateMerchantRequest:
      type: object
      required: [company, ubos, contact_person, processing_details]
      properties:
        company:
          $ref: '#/components/schemas/CompanyInfo'
        ubos:
          type: array
          description: "Ultimate Beneficial Owners (≥25% ownership each) - обязательно по C-003"
          minItems: 1
          items:
            $ref: '#/components/schemas/UBOInfo'
        contact_person:
          $ref: '#/components/schemas/ContactPerson'
        processing_details:
          $ref: '#/components/schemas/ProcessingDetails'

    CompanyInfo:
      type: object
      required: [legal_name, registration_number, tax_id, incorporation_date, registration_country, registered_address, mcc]
      properties:
        legal_name:
          type: string
          maxLength: 255
          example: "Tech Solutions Ltd"
        trading_name:
          type: string
          maxLength: 255
          example: "TechShop"
        registration_number:
          type: string
          maxLength: 50
          example: "12345678"
        tax_id:
          type: string
          maxLength: 50
          example: "GB123456789"
        incorporation_date:
          type: string
          format: date
          example: "2020-01-15"
        registration_country:
          type: string
          pattern: "^[A-Z]{2}$"
          example: "GB"
        registered_address:
          $ref: '#/components/schemas/Address'
        trading_address:
          $ref: '#/components/schemas/Address'
        website_url:
          type: string
          format: uri
          maxLength: 500
          example: "https://techshop.com"
        business_description:
          type: string
          maxLength: 1000
          example: "Online electronics retailer"
        mcc:
          type: string
          pattern: "^[0-9]{4}$"
          description: "Merchant Category Code - 4 digits"
          example: "5732"

    UBOInfo:
      type: object
      required: [first_name, last_name, date_of_birth, nationality, ownership_percentage, address, document]
      properties:
        first_name:
          type: string
          maxLength: 100
          example: "John"
        last_name:
          type: string
          maxLength: 100
          example: "Smith"
        date_of_birth:
          type: string
          format: date
          example: "1980-05-15"
        nationality:
          type: string
          pattern: "^[A-Z]{2}$"
          example: "GB"
        ownership_percentage:
          type: number
          minimum: 25.0
          maximum: 100.0
          description: "Минимум 25% по C-003"
          example: 60.5
        is_pep:
          type: boolean
          description: "Politically Exposed Person status"
          example: false
        address:
          $ref: '#/components/schemas/Address'
        document:
          $ref: '#/components/schemas/IdentityDocument'

    ContactPerson:
      type: object
      required: [first_name, last_name, email, phone, position]
      properties:
        first_name:
          type: string
          maxLength: 100
          example: "Jane"
        last_name:
          type: string
          maxLength: 100
          example: "Doe"
        email:
          type: string
          format: email
          maxLength: 255
          example: "jane.doe@techshop.com"
        phone:
          type: string
          pattern: "^\\+[1-9]\\d{1,14}$"
          example: "+44 20 1234 5678"
        position:
          type: string
          maxLength: 100
          example: "CFO"

    ProcessingDetails:
      type: object
      required: [monthly_volume_estimate, average_ticket_size, processing_countries, currencies, settlement_account]
      properties:
        monthly_volume_estimate:
          type: number
          minimum: 0
          description: "Estimated monthly volume in EUR"
          example: 100000
        average_ticket_size:
          type: number
          minimum: 0
          description: "Average transaction size in EUR"
          example: 75.50
        processing_countries:
          type: array
          minItems: 1
          maxItems: 50
          items:
            type: string
            pattern: "^[A-Z]{2}$"
          example: ["GB", "FR", "DE"]
        currencies:
          type: array
          minItems: 1
          maxItems: 10
          items:
            type: string
            pattern: "^[A-Z]{3}$"
          example: ["GBP", "EUR"]
        settlement_account:
          $ref: '#/components/schemas/SettlementAccount'

    Address:
      type: object
      required: [street, city, postal_code, country]
      properties:
        street:
          type: string
          maxLength: 200
          example: "123 Business Ave"
        city:
          type: string
          maxLength: 100
          example: "London"
        postal_code:
          type: string
          maxLength: 20
          example: "SW1A 1AA"
        country:
          type: string
          pattern: "^[A-Z]{2}$"
          example: "GB"

    IdentityDocument:
      type: object
      required: [type, number, expiry_date, issuing_country]
      properties:
        type:
          type: string
          enum: [passport, national_id, driving_license]
          example: "passport"
        number:
          type: string
          maxLength: 50
          description: "Хранится в зашифрованном виде (GDPR C-007)"
          example: "987654321"
        expiry_date:
          type: string
          format: date
          example: "2030-12-31"
        issuing_country:
          type: string
          pattern: "^[A-Z]{2}$"
          example: "GB"

    SettlementAccount:
      type: object
      required: [account_number, bank_name]
      properties:
        account_number:
          type: string
          maxLength: 50
          description: "Зашифровано при хранении"
          example: "12345678"
        sort_code:
          type: string
          pattern: "^[0-9]{2}-[0-9]{2}-[0-9]{2}$"
          example: "12-34-56"
        iban:
          type: string
          pattern: "^[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]?){0,16}$"
          example: "GB29 NWBK 6016 1331 9268 19"
        bank_name:
          type: string
          maxLength: 200
          example: "Example Bank"
        swift_code:
          type: string
          pattern: "^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$"
          example: "NWBKGB2L"

    CreateMerchantResponse:
      type: object
      properties:
        merchant_id:
          type: string
          format: uuid
          description: "Уникальный идентификатор мерчанта"
          example: "mrc_123e4567-e89b-12d3-a456-426614174000"
        status:
          type: string
          enum: [kyb_pending, kyb_approved, kyb_rejected, active, suspended]
          example: "kyb_pending"
        created_at:
          type: string
          format: date-time
          example: "2024-01-15T10:30:00Z"
        estimated_approval_date:
          type: string
          format: date-time
          description: "SLA 48 часов (C-008)"
          example: "2024-01-17T10:30:00Z"
        kyb_reference:
          type: string
          description: "Референс KYB провайдера"
          example: "kyb_456789"
        next_steps:
          type: array
          items:
            type: string
          example: [
            "Document verification in progress",
            "Sanctions screening initiated",
            "UBO verification pending"
          ]

    ErrorResponse:
      type: object
      required: [error, request_id, timestamp]
      properties:
        error:
          type: object
          required: [code, message]
          properties:
            code:
              type: string
              example: "VALIDATION_ERROR"
            message:
              type: string
              example: "Validation failed"
            details:
              type: object
              description: "Дополнительные детали ошибки"
        request_id:
          type: string
          format: uuid
          example: "req_123e4567"
        timestamp:
          type: string
          format: date-time
          example: "2024-01-15T10:30:00Z"

# Rate Limits
x-rate-limits:
  - scope: "per IP"
    limit: 5
    window: "1 minute"
    description: "Защита от bruteforce при онбординге (C-012)"

# Audit Log
x-audit-log:
  event_type: "merchant.onboarding.initiated"
  description: "Записывает инициацию онбординга мерчанта с маскированными PII (C-009)"
  fields_logged: [
    "merchant_id",
    "company.legal_name",
    "company.registration_number",
    "company.mcc",
    "ubos[].masked_name", # John S. вместо полного имени
    "ubos[].ownership_percentage",
    "processing_details.monthly_volume_estimate",
    "created_by_user_id",
    "ip_address",
    "user_agent"
  ]
  retention: "5 years (AML requirement)"

# Webhook Events
x-webhook-events:
  - event: "merchant.kyb.completed"
    description: "KYB верификация завершена (approved/rejected)"
    payload:
      merchant_id: "mrc_123..."
      status: "kyb_approved"
      kyb_reference: "kyb_456789"
      completed_at: "2024-01-17T08:30:00Z"
  
  - event: "merchant.sanctions.hit"
    description: "Обнаружено попадание в санкционные списки (C-004)"
    payload:
      merchant_id: "mrc_123..."
      sanctions_list: "OFAC SDN"
      match_score: 0.95
      blocked_at: "2024-01-15T10:35:00Z"

# Dependencies
x-dependencies:
  internal_services:
    - name: "KYB Service"
      endpoint: "POST /kyb/verifications"
      timeout: "30s"
    - name: "Sanctions Screening Service"  
      endpoint: "POST /sanctions/screen"
      timeout: "10s"
    - name: "Audit Log Service"
      endpoint: "POST /audit/events"
      timeout: "5s"
  
  external_services:
    - name: "KYC/KYB Provider"  # TBD: конкретный провайдер
      sla: "95% uptime"
    - name: "Sanctions Data Provider"  # TBD: конкретный провайдер
      sla: "99% uptime"
```

**Ключевые особенности API:**

1. **Constraint Compliance:**
   - C-003: Обязательная верификация всех UBO ≥25%
   - C-004: Автоматический sanctions screening
   - C-007: GDPR-минимизация данных, retention policies
   - C-009: Полное audit logging с маскированием PII
   - C-012: Rate limiting 5 req/min per IP

2. **Security:**
   - OAuth 2.0 Bearer authentication
   - Idempotency-Key для предотвращения дублей
   - Все чувствительные данные зашифровываются при хранении

3. **Business Logic:**
   - UBO ownership validation (минимум 25% каждый)
   - MCC restrictions (запрещённые категории)
   - Sanctions screening integration
   - SLA 48 часов на онбординг

4. **Error Handling:**
   - Полный набор HTTP error codes
   - Детализированные error responses
   - Специфичные бизнес-ошибки (sanctions hit, insufficient UBO coverage)

Статус: **[DRAFT]** - требует ревью PO + Compliance Officer согласно decision-matrix.md
