# HSE App X — карта API

Вытащено из декомпиляции настоящего `base.apk` (`com.hse.app2`, нативный Kotlin, Retrofit).
Источник истины — Retrofit-интерфейсы в `com/hse/data/api/*`. Всего **~180 эндпоинтов**.

---

## Базовые URL

| Что | URL |
|---|---|
| Основной API (prod) | `https://api.hseapp.ru/` |
| Dev | `https://dev.hseapp.ru/` |
| Api2 | `https://api2.hseapp.ru/` |
| Авторизация (Keycloak ВШЭ) | `https://saml.hse.ru/realms/hse/protocol/openid-connect/` |
| Навигация (deep links) | `https://nav.hseapp.ru/` |

Домен выбирается флагами `isApi2Enabled` / `isDevEnabled` (`com/hse/data/common/Const.kt`).
Версия API — это префикс пути на уровне базового URL каждого интерфейса:
- `BASE_URL`   = `https://api.hseapp.ru/`      (без версии)
- `BASE_URL_V2` = `https://api.hseapp.ru/v2/`
- `BASE_URL_V3` = `https://api.hseapp.ru/v3/`

**Полный URL = базовый URL версии + путь из таблиц ниже.**
Пример: `GET me` в интерфейсе на V3 → `https://api.hseapp.ru/v3/me`.

---

## Авторизация — OAuth2 / PKCE через Keycloak

```
client_id      = app-x-android          (публичный, без секрета)
redirect_uri   = ru.hse.hseappx://saml.hse.ru/authorize_callback
scope          = profile email
PKCE           = S256
authorize      = https://saml.hse.ru/realms/hse/protocol/openid-connect/auth
token          = https://saml.hse.ru/realms/hse/protocol/openid-connect/token
```

Поток:
1. `GET .../auth?client_id=app-x-android&redirect_uri=...&response_type=code&scope=profile%20email&state=...&code_challenge=...&code_challenge_method=S256`
   → вход ВШЭ → редирект на `redirect_uri?code=...&state=...`
2. `POST .../token` (`grant_type=authorization_code`, `code`, `redirect_uri`, `code_verifier`, `client_id`)
   → `access_token` (~3 ч) + `refresh_token` (окно 21 день, ротируется)
3. Обновление: `POST .../token` (`grant_type=refresh_token`, `refresh_token`, `client_id`).
   На `400/401` (`invalid_grant`) — сессия умерла, нужен повторный вход.

Все запросы к `api.hseapp.ru` идут с заголовками:
```
Authorization: Bearer <access_token>
Accept-Language: ru
User-Agent: hse-<versionName>#<manufacturer>#<model>#<sdkInt>
```

> `redirect_uri` клиент принимает любой http(s) — поэтому на macOS/iOS удобно
> ловить колбэк системным `ASWebAuthenticationSession` по схеме `ru.hse.hseappx://`.

---

## Эндпоинты по версиям

### Версия V3 — `https://api.hseapp.ru/v3/`

**Профиль, люди, поиск, здания (DumpApi / ApiRequests)**
```
GET    me
GET    dump/me
GET    people
GET    search
GET    config
GET    group/{Id}
GET    auditorium/{Id}
GET    email/{Email}
GET    email/{Email}/link
GET    email/{Email}/subordinates
POST   emails
POST   buildings/near
POST   buildings/groups
GET    favourites/me
POST   favourites/{email}
DELETE favourites/{email}
POST   auth/lk
GET    history
```

**Аватары (AvatarsApi)**
```
GET    avatars
GET    avatars/{email}
POST   avatars
DELETE avatars
```

**Расписание (RuzApi)**
```
GET    ruz/lessons
GET    ruz/lessons/{id}
GET    ruz/subscriptions
POST   ruz/subscriptions
DELETE ruz/subscriptions/{id}
```

**Библиотека (LibraryApi)**
```
GET    library
GET    library/news
GET    library/users/me
GET    library/users/literature
GET    library/users/literature/history
GET    library/passes/google_pay
POST   library/users/literature/prolong/{barcode}
POST   library/users/password
```

**Оплата обучения (PaymentsApi)**
```
GET    payments/contract
GET    payments/contract/{id}
GET    payments/contract/{id}/payments
POST   payments/contract/{id}/reconciliation
GET    payments/payment/{id}
GET    payments/payment/processing
POST   payments/payment/create
```

**Проектная ярмарка / Project Fair (PfApi)**
```
GET    pf/users/me
GET    pf/projects/{Id}
GET    pf/requests
POST   pf/requests
POST   pf/projects
POST   pf/programs
POST   pf/projects/{Id}/favourite
DELETE pf/projects/{Id}/favourite
```

### Версия V2 — `https://api.hseapp.ru/v2/`

**Дедлайны (DeadlinesApi)**
```
GET    deadlines/{Id}
POST   deadlines
PUT    deadlines
PATCH  deadlines/{Id}
DELETE deadlines/{Id}
POST   deadlines/{Id}/complete
DELETE deadlines/{Id}/complete
POST   deadlines/{Id}/pin
DELETE deadlines/{Id}/pin
POST   deadlines/{Id}/share
DELETE deadlines/{Id}/share/{Target}
GET    deadlines/{Id}/members
GET    deadlines/disciplines
GET    deadlines/groups
PUT    deadlines/groups
GET    deadlines/groups/{Id}
PATCH  deadlines/groups/{Id}
DELETE deadlines/groups/{Id}
GET    deadlines/groups/{Id}/people
POST   deadlines/groups/{Id}/deadlines
POST   deadlines/groups/{Id}/invite
POST   deadlines/groups/{Id}/leave
DELETE deadlines/groups/{Id}/users/{Email}
DELETE deadlines/groups/{Id}/invites/{Email}
POST   deadlines/groups/avatar/upload
GET    deadlines/invites
POST   deadlines/invites/{Id}
DELETE deadlines/invites/{Id}
```
> Опрос списка в App X: `POST /v2/deadlines` с телом `{"is_completed": false|true}`,
> пагинация курсором (`next_cursor` в ответе, `?cursor=` в запросе). Поля элемента:
> `id`, `title`, `discipline`, `expires_at` (ISO UTC), `completion_status`
> (`ACTIVE` / `COMPLETED` / `COMPLETED_LATE`).

**Оценки (Grades2Api)**
```
GET    grades
```

**События / бронирование (EventsApi)**
```
GET    events/buildings
GET    events/catalogs
GET    events/reservations
PUT    events/reservations
GET    events/rooms/{Id}
POST   events/rooms
```

**Иностранцы / миграционный учёт (ForeignersApi)**
```
GET    foreigners/catalogs
GET    foreigners/fias
GET    foreigners/form
POST   foreigners/form
POST   foreigners/form/submit
POST   foreigners/form/extend
POST   foreigners/form/migcard
POST   foreigners/form/vhi
POST   foreigners/document
POST   foreigners/medicalcert
POST   foreigners/fingerreg
POST   foreigners/getlocstatus
POST   foreigners/setlocstatus
```

**Уведомления (NotificationsApi)**
```
GET    notifications/feed
POST   notifications/feed/view
GET    notifications/settings
POST   notifications/settings/values/{id}
```

**Оплата общежития (PaymentsDormApi)**
```
GET    payments/dorm/contract
GET    payments/dorm/contract/{Id}/accruals
GET    payments/dorm/contract/{Id}/payments
GET    payments/dorm/contract/{Id}/status/{aId}
POST   payments/dorm/contract/{Id}/accruals/{aId}/pay/prepare
POST   payments/dorm/contract/{Id}/accruals/{aId}/pay/proceed
```

**Истории / Stories (StoriesApi)**
```
GET    stories
POST   stories/events
```

### Без версии — `https://api.hseapp.ru/`

**Оценки, старый интерфейс (GradesApi)** · `GET grades`
**Баннеры (BannersApi)** · `GET banners` · `POST banners/dismiss`
**Карьера (CareerApi)**
```
GET    career/catalog
GET    career/catalog/{Name}
GET    career/companies/{Id}
GET    career/companies/{Id}/similar
GET    career/vacancies/{Id}
POST   career/vacancies
PUT    career/vacancies/{Id}/favourite
DELETE career/vacancies/{Id}/favourite
GET/POST/PUT career/requests
```
**Курсы (CoursesApi)** · `GET courses/{Id}` · `POST courses/{Id}`
**CV / резюме (CvApi)** · `GET cv` · `GET cv/user` · `POST cv` · `PUT cv/{Id}` · `DELETE cv/{Id}`
**Сертификаты (OrderCertificateApi)** · `GET certificates/catalogs` · `POST certificates`
**Рейтинги (RatingsApi)**
```
GET    ratings
GET    ratings/me
GET    ratings/list
GET    education/ratings
GET    education/ratings/leaderboard
```
**Питание (FoodApi)** · `GET food/cafes` · `GET food/cafes/{cafe_id}` · `GET food/v2/cafes/{cafe_id}/menu`
**Аудитории (RoomsApi)** · `GET rooms/grid` · `POST rooms/free`
**Задачи / сервисы (TasksApi)** · `GET tasks` · `GET tasks/claims` · `GET tasks/services`
**СЭД / документы (SedApi)**
```
GET    sed/tasks
GET    sed/tasks/{id}
GET    sed/tasks/{id}/doc/{docid}
GET    sed/tasks/{id}/sign/status
POST   sed/tasks/action/{id}
```
**Covid (CovidApi / CovidHelpdeskApi)** · `GET/PUT covid/form` · `GET covid/lesson/{ruz_id}/{risk}` · `GET covidHelpdesk/requestTypes` · `POST covidHelpdesk/createRequest`
**Push-токены (FcmApi)** · `POST fcm/devices` · `DELETE fcm/devices/{Device}`
**Плюс / промокоды (PlusApi)** · `GET plus/code`
**Фиче-флаги (TogglesApi)** · `GET toggles`

---

## Открытое расписание (без авторизации)

Для расписания токен не нужен — есть публичный RUZ API ВШЭ:
```
https://ruz.hse.ru/api/search?term=<...>&type=group|person|auditorium
https://ruz.hse.ru/api/schedule/<type>/<id>?start=YYYY.MM.DD&finish=YYYY.MM.DD
```

---

## Замечания

- **Платёжный SDK** (`sdk-gateway/v1..v3/...`) — отдельный модуль платёжного провайдера
  (привязка карт, OTP, оплата), не ядро HSE API; у него свой хост. Для сайта он не нужен.
- Реально полезное ядро для клиента: `me`, `search`, `people`, `ruz/*`, `grades`,
  `deadlines/*`, `notifications/*`, `ratings/*`, `config`, `toggles`.
- Это приватный API вуза. Авторизацию делай честным OAuth-редиректом на `saml.hse.ru`
  (без сбора чужих паролей). `client_id=app-x-android` публичный, но использование
  чужого клиента на своём сайте — серая зона; для публичного сервиса стоит запросить
  доступ у команды HSE App X.
