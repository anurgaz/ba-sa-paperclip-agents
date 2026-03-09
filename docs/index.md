# Flowlix Docs — B2B Processing Platform

AI-native инфраструктура документации для BA/SA агентов платёжной B2B процессинговой платформы.

## Структура

```
flowlix-docs/
├── docs/               # Документация и контекст
│   ├── context/        # Глоссарий, ограничения, decision matrix
│   ├── adr/            # Architecture Decision Records
│   ├── business-rules/ # Бизнес-правила процессинга
│   ├── data/           # Data dictionary, SLA, KPI
│   ├── integrations/   # Интеграции (Visa/MC, KYC, TMS)
│   ├── templates/      # Шаблоны артефактов
│   └── examples/       # Эталонные примеры (few-shot)
├── agents/             # Профили и промпты агентов
│   ├── ba-agent/       # Business Analyst агент
│   └── sa-agent/       # System Analyst агент
├── validation/         # Скрипты валидации артефактов
├── pipeline/           # Pipeline для запуска агентов
└── .github/workflows/  # CI/CD (GitHub Pages deploy)
```

## Быстрый старт

### Запуск BA агента

```bash
./pipeline/run-agent.sh \
  --agent ba \
  --task "Создай user story для онбординга нового мерчанта через API" \
  --context docs/business-rules/onboarding-rules.md docs/integrations/kyc-provider.md
```

### Запуск SA агента

```bash
./pipeline/run-agent.sh \
  --agent sa \
  --task "Создай API спецификацию для POST /api/v1/merchants" \
  --context docs/integrations/kyc-provider.md docs/data/data-dictionary.md
```

### Валидация артефакта

```bash
./validation/validate.sh output/ba-20260308-120000.md
```

## Pipeline

1. **Сбор контекста:** glossary + constraints + decision-matrix + дополнительные файлы
2. **Вызов Claude API:** системный промпт агента + контекст + задача
3. **Валидация:** 4 проверки (constraints, completeness, glossary, consistency)
4. **Retry:** при FAIL — повтор с ошибками как фидбэк (макс 3 попытки)
5. **Результат:** PASSED → Ready for human review | FAILED → manual review

## Decision Matrix

| Действие | Уровень | Апрувер |
|----------|---------|---------|
| User Story | suggest+approve | PO |
| API Spec | suggest+approve | Tech Lead |
| Test Cases | auto | — |
| Business Rules | manual only | PO + Compliance |
| AML/Compliance | manual only | MLRO |

## Constraints

Все артефакты проверяются на соответствие 12 ограничениям: PSD2, PCI DSS, AML/CTF, GDPR, SLA.
Подробности: [Ограничения](context/constraints.md)
