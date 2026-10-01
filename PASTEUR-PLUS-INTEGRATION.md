# Pasteur Plus ← Pasteur Meet — راهنمای integrate

این فایل را در repo اپ **pasteur.plus** (مثلاً `pasteurmed10tir`) باز کنید / به Agent بدهید.  
هدف: کاربر از داخل [pasteur.plus](https://pasteur.plus/) روی دکمه بزند و مستقیم وارد اتاق ویدیو روی **https://meet.pasteur-plus.com** شود.

---

## وضعیت زیرساخت (الان آماده است)

| مورد | مقدار |
|------|--------|
| اپ اصلی | https://pasteur.plus (Runflare / این repo) |
| سرور ویدیو | VPS جدا — **نه** همان پاد Runflare |
| دامنه meet | https://meet.pasteur-plus.com |
| Stack | docker-jitsi-meet `stable-9646` |
| Auth | فقط **JWT** (`AUTH_TYPE=jwt`, مهمان خاموش) |
| بدون JWT | join رد می‌شود (دیالوگ پسورد / «احراز هویت ناموفق») — رفتار درست است |

**Secret مشترک** روی VPS Jitsi:

```bash
cat /root/pasteur-meet-jwt-secret.txt
# یا از /opt/jitsi/.env → JWT_APP_SECRET
```

همان مقدار را در Runflare به‌عنوان `JITSI_APP_SECRET` بگذارید. **هرگز در git یا کلاینت نگذارید.**  
اگر secret قبلاً در چت لو رفته، روی VPS عوض کنید و همان را در Runflare به‌روز کنید.

---

## Env سرور (Runflare Secrets)

```env
JITSI_DOMAIN=meet.pasteur-plus.com
JITSI_APP_ID=pasteur_plus
JITSI_APP_SECRET=<از VPS — فقط Secrets>
```

| Jitsi VPS | Pasteur Plus (Runflare) |
|-----------|-------------------------|
| `JWT_APP_ID=pasteur_plus` | `JITSI_APP_ID=pasteur_plus` |
| `JWT_APP_SECRET=...` | `JITSI_APP_SECRET=...` (همان) |
| `PUBLIC_URL=https://meet.pasteur-plus.com` | `JITSI_DOMAIN=meet.pasteur-plus.com` |

---

## قرارداد JWT (اجباری)

- الگوریتم: **HS256**
- توکن واقعی شکل `header.payload.signature` دارد (سه بخش با `.`)
- **هرگز** مقدار خام `JITSI_APP_SECRET` را در `?jwt=` نگذارید

Payload نمونه:

```json
{
  "iss": "pasteur_plus",
  "aud": "pasteur_plus",
  "sub": "user-or-patient-id",
  "room": "opaque-uuid-or-hash",
  "moderator": false,
  "exp": 1730000000,
  "context": {
    "user": { "name": "نام نمایشی" }
  }
}
```

| نقش | `moderator` |
|-----|-------------|
| بیمار | `false` |
| پزشک / اپراتور | `true` |

- `room`: غیرقابل حدس (UUID یا hash از `consultationId`)
- `exp`: الان + ۱ تا ۴ ساعت (ثانیه Unix)
- URL ورود:

```text
https://meet.pasteur-plus.com/{room}?jwt={token}
```

Smoke روی لپتاپ / VPS (از repo meet):

```bash
JITSI_APP_SECRET='...' JITSI_DOMAIN=meet.pasteur-plus.com ROOM=test-room-pasteur \
  node mint-test-jwt.js
```

لینک چاپ‌شده را باز کنید (نه secret خام).

---

## معماری جریان کاربر

```
کاربر در pasteur.plus
  → دکمه «ورود به ویزیت تصویری»
  → API سرور (احراز هویت‌شده) JWT می‌سازد
  → redirect به https://meet.pasteur-plus.com/{room}?jwt=...
  → Jitsi امضا را با همان SECRET چک می‌کند → ورود به اتاق
```

فاز ۱ پیشنهادی: **redirect** (ساده‌تر).  
بعداً اختیاری: iframe داخل صفحه مشاوره + CSP `frame-src https://meet.pasteur-plus.com`.

---

## کارهای پیاده‌سازی در این repo (pasteur.plus)

### فاز ۱ — mint API (سرور)
- Helper امضای JWT با `JITSI_APP_SECRET` (فقط سرور؛ jose / jsonwebtoken / مطابق استک موجود)
- Route احراز هویت‌شده مثلاً:  
  `POST /api/consultations/[id]/video-token`
- فقط کاربر مجاز همان مشاوره (بیمار / پزشک تخصیص‌یافته / ادمین)
- فیلد opaque برای نام اتاق روی Consultation (مثلاً `videoRoomName`) — اگر نبود اضافه شود
- پاسخ: `{ room, jwt, url, expiresAt }` — **هرگز secret برنگردد**
- `moderator` بر اساس نقش

### فاز ۲ — دکمه Join
- در صفحه مشاوره (web و در صورت وجود `/app`): دکمه «ورود به ویزیت تصویری»
- فراخوانی API → `window.location` / redirect به `url`
- لاگین یوزرنیم/پسورد Jitsi نشان داده نشود؛ اگر آمد یعنی JWT غلط/غایب است

### فاز ۳ — وضعیت جلسه (حداقلی)
- وضعیت ویدیو متناسب مدل موجود: مثلاً `scheduled` / `in_call` / `completed`
- ادمین/پزشک بتواند برای ویزیت تأییدشده session ویدیو باز کند
- بیمار فقط وقتی مجاز است دکمه را ببیند

### فاز ۴ — اثبات
- Secrets روی Runflare (ترجیحاً staging اول)
- با session واقعی mint → باز کردن URL → join موفق
- کاربر غیرمجاز نتواند توکن بگیرد
- تست ۱:۱: پزشک `moderator:true` + بیمار `false`، همان `room`

### خارج از scope
- نصب/تغییر Docker Jitsi روی VPS از داخل این repo
- گذاشتن Jitsi داخل همان پاد Runflare
- ضبط جلسه (Jibri)

---

## Acceptance

1. کلیک در pasteur.plus → ورود به اتاق درست روی meet بدون پسورد دستی  
2. کاربر/ویزیت غیرمجاز توکن نمی‌گیرد  
3. `JITSI_APP_SECRET` در network کلاینت یا کد فرانت نیست  

---

## پرامپت Agent (کپی در پروژه pasteur.plus)

```text
# Task: Integrate Pasteur Meet (Jitsi JWT) into pasteur.plus

## Context
- Main app: pasteur.plus (this Next.js repo on Runflare). Do NOT install Jitsi on this host.
- Video infra already deployed separately:
  - Public URL: https://meet.pasteur-plus.com
  - docker-jitsi-meet stable-9646
  - AUTH: JWT only (ENABLE_AUTH=1, ENABLE_GUESTS=0, AUTH_TYPE=jwt)
- Users must join video ONLY via short-lived HS256 JWT minted on the Next.js server.
- Never expose JITSI_APP_SECRET to the browser, client bundles, or public git.
- Full contract: see PASTEUR-PLUS-INTEGRATION.md copied from repo jitsi-pasteur-plus-05mehr.

## Runflare / server env (Secrets only)
JITSI_DOMAIN=meet.pasteur-plus.com
JITSI_APP_ID=pasteur_plus
JITSI_APP_SECRET=<same value as /root/pasteur-meet-jwt-secret.txt on the Jitsi VPS>

## JWT contract (must match Jitsi exactly)
- Algorithm: HS256
- Claims: iss=pasteur_plus, aud=pasteur_plus, sub=userId, room=opaque, moderator bool, exp, context.user.name
- Join URL: https://meet.pasteur-plus.com/{room}?jwt={token}
- Token = three base64url parts. Never put raw APP_SECRET in jwt= query.

## Implement (one phase at a time; follow this repo AGENTS.md)
1) Server mint API for allowed consultation participants; return {room,jwt,url,expiresAt}
2) Join button → call API → redirect to url (iframe optional later + CSP frame-src)
3) Minimal video lifecycle fields/status; admin/doctor can open session for approved consults
4) Prove with curl/session on staging/production; secret never in client responses

## Out of scope
Redeploy Jitsi VPS; Jibri recording; putting Jitsi in Runflare pod.
```

---

## CSP / iframe (اگر بعداً embed کردید)

در اپ Next:

- `frame-src` / CSP اجازهٔ `https://meet.pasteur-plus.com`

روی سرور Jitsi (در صورت نیاز): `config/nginx-frame-ancestors.txt` در repo meet — ancestor برای `https://pasteur.plus`.
