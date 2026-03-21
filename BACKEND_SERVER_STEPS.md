# Шаги на сервере (VoIP + API для MakTime)

Клиент уже шлёт:
- `POST /devices/voip-token` с телом `{"token":"<hex>","platform":"ios"}` и заголовком `Authorization: Bearer <jwt>`.
- VoIP push на iOS должен содержать поля, которые парсит `VoIPPushPayload`: `from` (или `fromUserId`), `callerName`, `conversationId`, опционально `callUUID`.

Ниже — примеры команд. **`your-api.example.com` в документации не существует** — это заглушка. Замените на свой домен из `MakTime/Config.swift` (`AppConfig.apiURL`).

У текущего приложения в коде: **`https://maktime.space/api`** (если не меняли в форке).

---

## 1. Эндпоинт регистрации VoIP-токена

Реализуйте маршрут, совпадающий с клиентом: **`POST /api/devices/voip-token`** — база `AppConfig.apiURL` в приложении.

Пример проверки с VPS или Mac (подставьте **реальный JWT** из ответа `POST /auth/login`):

```bash
export BASE_URL="https://maktime.space/api"
export JWT="СЮДА_ВСТАВЬТЕ_ТОКЕН_ИЗ_ОТВЕТА_ЛОГИНА"

# token — hex строка как у APNs (чётное число символов 0-9a-f), без «...» внутри JSON
curl -sS -X POST "$BASE_URL/devices/voip-token" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT" \
  -d '{"token":"deadbeef00112233445566778899aabbccddeeff","platform":"ios"}' \
  -w "\nHTTP %{http_code}\n"
```

Если видите **`curl: (6) Could not resolve host`** — вы не заменили `BASE_URL` на реальный домен или DNS с этой машины не видит хост.

Если **`HTTP 000`** — соединения не было (нет сети, DNS, TLS, блокировка firewall).

Ожидание: **200/201**, токен сохранён в БД в связке с `userId`.

---

## 2. Хранение VoIP-токенов

- Таблица вроде `user_voip_devices`: `user_id`, `token_hex`, `platform`, `updated_at`.
- При новом логине с того же устройства — обновлять строку; при логауте — удалять.

---

## 3. Отправка VoIP push при входящем звонке

1. В Apple Developer: ключ **APNs** с capability **VoIP** (или отдельный VoIP certificate).
2. На сервере: библиотека для HTTP/2 APNs (например `node-apn`, `apns2` Python, Go `apple_push`).

Пример **payload** (совместимо с клиентом):

```json
{
  "aps": {
    "content-available": 1
  },
  "from": "callerUserId",
  "callerName": "Имя звонящего",
  "conversationId": "conv-id",
  "callUUID": "550e8400-e29b-41d4-a716-446655440000"
}
```

`callUUID` желательно совпадать с тем, что вы потом отдаёте в сигналинге, чтобы не плодить дубликаты.

Команда для **проверки только REST вашего API** (если вы оборачиваете APNs в свой внутренний вызов):

```bash
curl -sS -X POST "$BASE_URL/internal/test-voip-push" \
  -H "Authorization: Bearer $SERVICE_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"userId":"...","payload":{...}}'
```

(Путь вымышленный — замените на свой тестовый эндпоинт.)

---

## 4. Сигналинг звонка (у вас уже Socket.IO)

После доставки VoIP клиент просыпается и подключает сокет; дальше — как сейчас: `call:incoming`, `webrtc:*` и т.д.

Убедитесь, что при **одном** входящем не дублируете и socket-событие, и VoIP без нужды (или коалесцируйте по `callUUID`).

---

## 5. Лента (пагинация)

Клиент вызывает:

`GET /posts?limit=20&offset=N`

Проверка:

```bash
curl -sS "$BASE_URL/posts?limit=20&offset=0" \
  -H "Authorization: Bearer $JWT" | head -c 500
```

---

## 6. Чеклист перед продом

- [ ] `POST /devices/voip-token` отвечает 2xx и пишет токен.
- [ ] VoIP push уходит на зарегистрированный токен при входящем звонке.
- [ ] Payload содержит `from`, `callerName`, `conversationId`.
- [ ] Обычные (не VoIP) пуши не используются как замена VoIP для входящего звонка (требования Apple).
