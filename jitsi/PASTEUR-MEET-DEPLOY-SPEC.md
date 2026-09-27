# Pasteur Meet — مشخصات deploy و اتصال به Pasteur Plus

**نام پروژه زیرساخت ویدیو:** `pasteur-meet`  
**اپ اصلی (بدون Jitsi روی همان پاد):** `pasteurmed10tir` → https://pasteur.plus (Runflare)  
**دامنه پیشنهادی Jitsi:** `https://meet.pasteur.plus` (یا دامنه اختصاصی دیگر — در `.env` یکسان باشد)

این سند برای **repo/سرور جدا** است: فقط Docker Jitsi. کد Next.js اینجا deploy **نمی‌شود**.

مرجع مفهومی: `updates/jitsi/New Text Document.txt` (معماری JWT، TURN، جداسازی سرور).

---

## ۱. معماری

```
┌─────────────────────────────┐         ┌──────────────────────────────┐
│  pasteur.plus (Runflare)    │         │  meet.pasteur.plus (VPS)     │
│  Next.js + Prisma           │         │  docker-jitsi-meet           │
│  • login / consultation     │         │  • Prosody + Jicofo + JVB    │
│  • API: mint JWT (HS256)    │         │  • Coturn (TURN)             │
│  • صفحه join + iframe       │         │  • verify JWT (همان SECRET)  │
└──────────────┬──────────────┘         └──────────────▲───────────────┘
               │  secret مشترک (یک بار)                  │
               │  roomName قرارداد                        │
               └──────────────────────────────────────────┘
                        مرورگر بیمار / پزشک
```

- **دیتابیس مشترک نداریم.** Jitsi به Prisma وصل نمی‌شود.
- **JWT هر بار** روی سرور `pasteur.plus` ساخته می‌شود؛ Jitsi فقط امضا را با `JWT_APP_SECRET` چک می‌کند.

---

## ۲. JWT — چه چیزی کجا قرار می‌گیرد؟

| مورد | سرور Jitsi (`.env` docker-jitsi-meet) | سرور اپ Runflare (env — **فقط سرور**) |
|------|----------------------------------------|----------------------------------------|
| شناسه اپ | `JWT_APP_ID=pasteur_plus` | `JITSI_APP_ID=pasteur_plus` |
| راز مشترک | `JWT_APP_SECRET=<random>` | `JITSI_APP_SECRET=<همان مقدار>` |
| آدرس عمومی meet | `PUBLIC_URL=https://meet.pasteur.plus` | `JITSI_DOMAIN=meet.pasteur.plus` |
| Issuer / Audience | `JWT_ACCEPTED_ISSUERS=pasteur_plus` | در payload JWT: `"iss"`, `"aud"` |
| | `JWT_ACCEPTED_AUDIENCES=pasteur_plus` | |

**تولید secret (یک بار روی VPS Jitsi):**

```bash
openssl rand -hex 32
```

مقدار را در password manager نگه دارید؛ همان را در Runflare برای `JITSI_APP_SECRET` بگذارید. **هرگز در git commit نکنید.**

**الگوریتم:** HS256 (پیش‌فرض Jitsi JWT).

**Payload نمونه (اپ pasteur.plus می‌سازد):**

```json
{
  "iss": "pasteur_plus",
  "aud": "pasteur_plus",
  "sub": "patient-phone-or-user-id",
  "room": "opaque-room-id-from-consultation",
  "moderator": false,
  "exp": 1730000000,
  "context": {
    "user": {
      "name": "نام نمایشی"
    }
  }
}
```

- **بیمار:** `moderator: false`
- **پزشک / اپراتور:** `moderator: true`
- **room:** غیرقابل حدس (UUID/hash از `consultationId`)
- **exp:** ۱–۴ ساعت پس از زمان join

Jitsi بدون JWT معتبر نباید اتاق خصوصی پزشکی را باز کند (`ENABLE_AUTH=1`, `ENABLE_GUESTS=0`).

---

## ۳. پیش‌نیاز سرور `pasteur-meet`

| مورد | پیشنهاد |
|------|---------|
| نوع | **VPS** با Docker (ترجیحاً **نه** همان پاد Runflare اپ) |
| CPU / RAM | حداقل **4 vCPU**, **8 GB RAM** (چند تماس ۱:۱ هم‌زمان) |
| Disk | 40 GB+ SSD |
| شبکه | پهنای باند بالا؛ **UDP** برای JVB (اغلب **10000**) |
| TURN | Coturn داخل `docker-jitsi-meet` — برای موبایل/ایران حیاتی |
| DNS | `A` (یا `AAAA`) → `meet.pasteur.plus` → IP VPS |
| TLS | HTTPS اجباری (Let's Encrypt) |

قبل از خرید هاست: از پشتیبانی بپرسید **UDP و Docker compose Jitsi** پشتیبانی می‌شود یا نه.

---

## ۴. مراحل deploy روی VPS (docker-jitsi-meet)

### ۴.۱ نصب پایه

```bash
sudo apt update && sudo apt install -y git docker.io docker-compose-plugin
sudo usermod -aG docker $USER
# logout/login
```

### ۴.۲ Clone و env

```bash
git clone https://github.com/jitsi/docker-jitsi-meet.git /opt/jitsi
cd /opt/jitsi
git checkout stable-9646   # یا آخرین tag stable — قبل از deploy doc رسمی را ببینید
cp env.example .env
```

### ۴.۳ تنظیمات `.env` (حداقل)

```env
PUBLIC_URL=https://meet.pasteur.plus

ENABLE_AUTH=1
ENABLE_GUESTS=0
AUTH_TYPE=jwt

JWT_APP_ID=pasteur_plus
JWT_APP_SECRET=<paste-from-openssl-rand-hex-32>
JWT_ACCEPTED_ISSUERS=pasteur_plus
JWT_ACCEPTED_AUDIENCES=pasteur_plus

TZ=Asia/Tehran

# TLS — طبق doc همان repo (LETSENCRYPT_* یا proxy بیرون)
# TURN — معمولاً در gen-passwords / coturn فعال بماند
```

```bash
./gen-passwords.sh   # اگر در repo موجود است
docker compose up -d
```

### ۴.۴ فایروال (نمونه)

- `443/tcp` — HTTPS
- `10000/udp` — JVB (مقدار دقیق را از `.env` همان نسخه بخوانید)
- پورت‌های Coturn طبق doc (مثلاً `3478` udp/tcp, `5349` tcp)

### ۴.۵ Embed از pasteur.plus

- در `pasteur.plus`: CSP / `frame-src` اجازهٔ `https://meet.pasteur.plus`
- در Jitsi: محدودیت iframe ancestor برای `https://pasteur.plus` (و staging) طبق [مستندات Jitsi](https://jitsi.github.io/handbook/) برای نسخه نصب‌شده
- UI فارسی: `config.js` سفارشی در volume مربوط به web

---

## ۵. تست پذیرش (Acceptance)

1. باز کردن `https://meet.pasteur.plus` **بدون** JWT → نباید بتوان اتاق پزشکی را آزاد ساخت/join کرد.
2. ساخت JWT تست با همان `JWT_APP_SECRET` (اسکریپت Node زیر) → join در مرورگر موفق.
3. دو مرورگر: یکی `moderator: true`، یکی `false` — همان `room` — صدا/تصویر.
4. تست از **موبایل** (4G) — اگر fail → TURN را بررسی کنید.
5. iframe از `https://pasteur.plus` (یا staging) بدون خطای CSP.

**اسکریپت smoke test JWT (روی لپتاپ، secret را env بگذارید):**

```javascript
// mint-test-jwt.js — node mint-test-jwt.js
const crypto = require('crypto');

const secret = process.env.JITSI_APP_SECRET;
const appId = process.env.JITSI_APP_ID || 'pasteur_plus';
const room = process.env.ROOM || 'test-room-pasteur';
const exp = Math.floor(Date.now() / 1000) + 3600;

const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
const payload = Buffer.from(
  JSON.stringify({
    iss: appId,
    aud: appId,
    sub: 'smoke-test',
    room,
    moderator: true,
    exp,
  }),
).toString('base64url');
const sig = crypto
  .createHmac('sha256', secret)
  .update(`${header}.${payload}`)
  .digest('base64url');
console.log(`${header}.${payload}.${sig}`);
console.error(`Open: https://meet.pasteur.plus/${room}?jwt=...`);
```

---

## ۶. تحویل به تیم Pasteur Plus (Runflare)

فایل **`INTEGRATION-HANDOFF.md`** (پس از deploy پر کنید):

```markdown
## Pasteur Meet → pasteur.plus env

JITSI_DOMAIN=meet.pasteur.plus
JITSI_APP_ID=pasteur_plus
JITSI_APP_SECRET=<REDACTED — set in Runflare secrets only>

Deployed at: YYYY-MM-DD
Jitsi version / git tag: ...
Public URL tested: yes/no
TURN tested from mobile IR: yes/no
```

روی **pasteurmed10tir** (فاز بعد — جدا از این repo):

- API سرور: mint JWT فقط برای consultation مجاز
- صفحه join بیمار/پزشک با External API یا iframe
- فیلدهای Prisma: `videoRoomName`, وضعیت session (scheduled / in_call / completed)

---

## ۷. خارج از scope پروژه pasteur-meet

- PostgreSQL اپ، Prisma migrate
- درگاه پرداخت، OTP، ادمین پاستور
- ضبط جلسه (Jibri) مگر درخواست جدا
- کد Next.js

---

## ۸. نگهداری (OPERATIONS خلاصه)

| کار | دستور |
|-----|--------|
| وضعیت | `cd /opt/jitsi && docker compose ps` |
| لاگ | `docker compose logs -f web prosody jvb` |
| به‌روزرسانی | backup `.env` → pull tag جدید → `docker compose up -d` |
| backup | فقط `.env` و custom config — نه کل ویدیو |

---

## ۹. پرامپت Agent — پروژه pasteur-meet (این VPS / repo جدا)

```
Project: pasteur-meet
Domain: meet.pasteur.plus

Deploy official docker-jitsi-meet on this machine only. No Next.js, no app database.
Follow updates/jitsi/PASTEUR-MEET-DEPLOY-SPEC.md sections 3–5.

Enable JWT (AUTH_TYPE=jwt, ENABLE_AUTH=1, ENABLE_GUESTS=0).
Generate JWT_APP_SECRET; write INTEGRATION-HANDOFF.md with JITSI_APP_ID and instructions for Runflare (secret not in git).
Configure Coturn/TURN; document firewall ports in OPERATIONS.md.
Allow iframe from https://pasteur.plus (and staging URL if provided).
Run smoke test JWT join in browser.
Deliver: OPERATIONS.md, INTEGRATION-HANDOFF.md, optional mint-test-jwt.js.
Do not implement pasteur.plus application code.
```

---

## ۱۰. پرامپت Agent — pasteurmed10tir (بعد از آماده شدن meet)

```
Read updates/jitsi/PASTEUR-MEET-DEPLOY-SPEC.md and INTEGRATION-HANDOFF from pasteur-meet deploy.

Integrate Jitsi on pasteur.plus using server env:
JITSI_DOMAIN, JITSI_APP_ID, JITSI_APP_SECRET (never client-side).

Add API to mint HS256 JWT for Consultation video sessions (room opaque, moderator patient vs doctor, short exp).
Add join pages (web + /app) embedding meet.pasteur.plus with token from authenticated API.
Extend Consultation model/status for video lifecycle.
Admin: open/assign video session for approved consultations.
Prove with curl on deployed pasteur.plus staging. One phase at a time per AGENTS.md.
```

---

## ۱۱. چک‌لیست سریع

- [ ] VPS + DNS + TLS
- [ ] docker-jitsi-meet با JWT
- [ ] SECRET کپی شده به Runflare (امن)
- [ ] TURN تست موبایل
- [ ] embed pasteur.plus
- [ ] INTEGRATION-HANDOFF به تیم اپ
- [ ] فاز integrate در pasteurmed10tir
