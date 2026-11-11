# HSE Client (macOS) — каркас

Неофициальный нативный клиент HSE App X на SwiftUI. Собирается и запускается в Xcode.
API вытащен из приложения (см. `../hseappx-api.md`, `../hseappx-api-verified.md`).

## Запуск

```bash
open HSEClient.xcodeproj
```
В Xcode: выбери схему **HSEClient**, таргет **My Mac**, при необходимости укажи свою
команду подписи (Signing & Capabilities → Team), нажми **Run** (⌘R).

Либо из терминала (без подписи):
```bash
xcodebuild -scheme HSEClient -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## Что внутри

```
Sources/
  App/HSEClientApp.swift        — точка входа
  Auth/
    PKCE.swift                  — генерация PKCE (S256) через CryptoKit
    Keychain.swift              — хранение токенов в Keychain
    AuthService.swift           — OAuth2+PKCE через ASWebAuthenticationSession,
                                  обмен кода, авто-refresh, logout
  Networking/APIClient.swift    — клиент к api.hseapp.ru (версии v2/v3/root,
                                  Bearer, retry на 401, ISO-8601 даты)
  Models/Models.swift           — модели под реальные ответы
  Views/
    ContentView.swift           — навигация (sidebar) + гейт авторизации
    LoginView.swift             — экран входа
    ScheduleView.swift          — расписание по неделям
    GradesView.swift            — оценки
    DeadlinesView.swift         — дедлайны
    ProfileView.swift           — профиль
```

## Авторизация

OAuth2 + PKCE против Keycloak ВШЭ (всё в `AuthService.swift`):
- `client_id = app-x-android` (публичный), `redirect = ru.hse.hseappx://...`
- `ASWebAuthenticationSession` ловит callback по схеме `ru.hse.hseappx`
  (регистрация URL-схемы в Info.plist не нужна)
- access-токен (~3 ч) + refresh (21 дн.) в Keychain; refresh — автоматически

## Реализованные экраны и эндпоинты

| Экран | Эндпоинт |
|---|---|
| Профиль | `GET /v3/dump/me` |
| Расписание | `GET /v3/ruz/lessons?start=&end=` |
| Оценки | `GET /v2/grades` |
| Дедлайны | `POST /v2/deadlines {is_completed}` |

## Дальше можно добавить

- Поиск людей/аудиторий, бронь, библиотека, столовые — эндпоинты в `../hseappx-api.md`.
- Фиче-флаги `GET /toggles` — чтобы скрывать выключенные разделы.
- iCal-экспорт расписания `/v3/ruz/cal/<token>` (работает без токена).

## Статус / правовое

Каркас для личного использования со своим аккаунтом. Это приватный API вуза;
для публичного сервиса использование `client_id=app-x-android` — серая зона,
стоит запросить доступ у команды HSE App X.
