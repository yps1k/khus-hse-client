# HSE App X API — проверено вживую

Эндпоинты и форматы ответов подтверждены живыми запросами с реальным токеном
(рутуемый эмулятор + mitmproxy, вход настоящим аккаунтом ВШЭ). Личные данные в
примерах заменены плейсхолдерами.

## Базовое

```
Хост:            https://api.hseapp.ru
Версии:          /v3/ , /v2/ , и без префикса (зависит от эндпоинта — см. ниже)
Заголовки:       Authorization: Bearer <access_token>
                 Accept-Language: ru
                 User-Agent: hse-<versionName>#<manufacturer>#<model>#<sdk>
Авторизация:     OAuth2 + PKCE, Keycloak https://saml.hse.ru/realms/hse/protocol/openid-connect
                 client_id = app-x-android  (публичный, без секрета)
                 token-эндпоинт: .../openid-connect/token
```

Проверено: токен из приложения работает для прямых запросов к `api.hseapp.ru` с мака.
`access_token` живёт ~3 ч; обновляется `grant_type=refresh_token`.

---

## Проверенные эндпоинты

### Профиль — `GET /v3/dump/me`  ✅
```json
{
  "id": "lk3111874",
  "full_name": "<ФИО>",
  "birth_date": "2008-03-07",
  "email": "<...>@edu.hse.ru",
  "avatar_url": "https://elk.obs.ru-moscow-1.hc.sbercloud.ru/img/user/...jpeg",
  "description": "Бакалавриат <группа>",
  "type": "STUDENT",
  "lk_roles": ["LK_ROLE_STUDENT"],
  "names": {"last_name":"...","first_name":"...","middle_name":"..."},
  "education": [{
    "university_title": "Москва",
    "start_year": "2025",
    "degree_level": "DEGREE_BACHELOR",
    "program_title": "Программная инженерия",
    "faculty_title": "Факультет компьютерных наук",
    "campus": "CAMPUS_MOS"
  }],
  "is_timetable_available": true
}
```

### Расписание — `GET /v3/ruz/lessons?start=YYYY-MM-DD&end=YYYY-MM-DD`  ✅
Возвращает массив занятий:
```json
[{
  "id": "1654924",
  "discipline": "Научно-исследовательский семинар ...",
  "type": "Научно-исследовательский семинар",
  "building": "Покровский б-р, д.11",
  "auditorium": "R608",
  "auditorium_id": 1040,
  "date_start": "2026-11-09T11:40:00Z",
  "date_end":   "2026-11-09T13:00:00Z",
  "time_zone": "Europe/Moscow",
  "location": {"type":"Point","coordinates":[37.648605,55.7545571]},
  "stream": "...", "discipline_id": "...", "group_id": "...",
  "lesson_number_start": ...
}]
```
> Персональное расписание (по токену). Для чужого/публичного — открытый
> `https://ruz.hse.ru/api` без авторизации.

### iCal-подписки на расписание — `GET /v3/ruz/subscriptions`  ✅
```json
[{
  "id": "...",
  "name": "Вышка",
  "token": "2da1e8b9-...",
  "url":    "https://api.hseapp.ru/v3/ruz/cal/2da1e8b9-...",
  "webcalUrl": "webcal://...",
  "createdAt": "...", "updatedAt": "..."
}]
```
> **Бонус:** `url` — это готовый iCal-фид расписания, работает **без токена**
> (можно подключать в любой календарь). Создание подписки: `POST /v3/ruz/subscriptions`.

### Оценки — `GET /v2/grades`  ✅
```json
{
  "items": [{
    "id": "11288285",
    "discipline": "История России",
    "type_raw": "Экзамен",
    "module_name": "4 модуль", "module_num": "4",
    "academic_year": "2026/2027",
    "credits": 3, "period_credits": 3,
    "entire_hours": 114, "aud_hours": 48,
    "repass_count": 0
  }],
  "selected_academic_year": "2026/2027",
  "available_academic_years": [...],
  "selected_program": {...},
  "available_programs": [...],
  "current_academic_year": "2026/2027"
}
```
> Старый вариант `GET /grades` (без версии) существует, но отдаёт пустой каркас —
> используй **`/v2/grades`** (в toggles это `grades_v2`).

### Дедлайны — `POST /v2/deadlines`  ✅
Тело: `{"is_completed": false}` (активные) или `true` (выполненные). Пагинация курсором.
```json
{
  "next_cursor": null,
  "items": [{
    "id": "6aa16daa67628149a478a9d4",
    "title": "Выбор НИСов",
    "expires_at": "2026-09-10T06:00:00.000Z",
    "emails": ["<...>@edu.hse.ru"],
    "groups": ["..."],
    "preview_groups": [{"id":"...","title":"<группа> (Академическая группа)"}],
    "created_by": {"email":"...","full_name":"...","avatar_url":"..."}
  }]
}
```

### Лента уведомлений — `GET /v2/notifications/feed`  ✅
```json
{ "next_cursor": "6ae8826e...", "items": [{ "email":"...", "content":"ср 18 ноя, 11:10 ...", ... }] }
```

### Истории — `GET /v2/stories`  ✅
Массив сторис с `pages` (id, duration, date_published, action).

### Столовые — `GET /food/cafes`  ✅ (без версии)
```json
[{ "cafes": [{ "cafe_id":"64ed04c9...", "cafe_name":"Столовая на Мясницкой 20", "opening_hours": ... }] }]
```
Меню: `GET /food/v2/cafes/{cafe_id}/menu`.

### Фиче-флаги — `GET /toggles`  ✅ (без версии)
```json
{ "ratings":{"enabled":true}, "grades":{"enabled":false}, "grades_v2":{"enabled":true},
  "deadlines":{"enabled":false}, "free_rooms":{"enabled":true}, "stories":{"enabled":true}, ... }
```
> Показывает, какие разделы включены для аккаунта. Удобно для скрытия выключенных экранов.

---

## Уточнения по версиям (из живых проверок)

| Эндпоинт | Рабочий путь | Примечание |
|---|---|---|
| Профиль | `/v3/dump/me` | `/v3/me` и `/me` → 404 |
| Расписание | `/v3/ruz/lessons`, `/v3/ruz/subscriptions` | параметры `start`/`end` = `YYYY-MM-DD` |
| Оценки | `/v2/grades` | `/grades` (root) — пустой каркас |
| Дедлайны | `POST /v2/deadlines` | `{is_completed}`, курсор `next_cursor` |
| Уведомления | `/v2/notifications/feed` | курсор |
| Истории | `/v2/stories` | |
| Столовые | `/food/cafes`, `/food/v2/cafes/{id}/menu` | без версии |
| Флаги | `/toggles` | без версии |
| Рейтинги | `/education/ratings` | у этого аккаунта пусто (404 `RatingsNotFound`) |
| `config`, `search` | путь/метод не подтвердились | `/v3/config`, `/v3/search` → 404 |

Полная карта всех ~180 эндпоинтов — в [hseappx-api.md](hseappx-api.md).

---

## Что это даёт для сайта/macOS-приложения

Минимальное рабочее ядро подтверждено и готово к использованию:
- **Вход:** OAuth PKCE на `saml.hse.ru` (на macOS — `ASWebAuthenticationSession`, токен в Keychain).
- **Профиль:** `/v3/dump/me`
- **Расписание:** `/v3/ruz/lessons` (или бесплатный iCal `/v3/ruz/cal/<token>`)
- **Оценки:** `/v2/grades`
- **Дедлайны:** `POST /v2/deadlines`
- **Флаги разделов:** `/toggles`

> Это приватный API вуза. Для личного использования со своим токеном — ок.
> Для публичного сервиса использование `client_id=app-x-android` — серая зона;
> стоит запросить доступ у команды HSE App X.
