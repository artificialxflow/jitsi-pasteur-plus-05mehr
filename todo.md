# Pasteur Meet — کارهای فازبندی‌شده

**هدف:** ویدیوی ۱:۱ امن داخل `pasteur.plus` با Jitsi روی `meet.pasteur-plus.com` (سرور جدا از Runflare).

**مراجع:** `jitsi/PASTEUR-MEET-DEPLOY-SPEC.md` · `jitsi/INTEGRATION-HANDOFF-TEMPLATE.md` · `README.md`

**وضعیت:** artefactهای deploy در repo آماده است (`bootstrap-vps.sh`). دامنهٔ نهایی: `meet.pasteur-plus.com`.

---

## فاز ۰ — آماده‌سازی و قرارداد

- [x] تأیید دامنه: `meet.pasteur.plus` (یا دامنه نهایی؛ در همهٔ `.env` یکسان باشد)
- [x] تأیید repo اپ: `pasteurmed10tir` → https://pasteur.plus (Runflare) — **بدون** نصب Jitsi روی همان پاد
- [ ] خرید/رزرو VPS (حداقل 4 vCPU، 8 GB RAM، 40 GB SSD، UDP و Docker مجاز)
- [ ] از پشتیبانی هاست: پشتیبانی **UDP** (مثلاً پورت JVB) و **docker compose** تأیید شود
- [x] قرارداد نام اتاق: `room` غیرقابل حدس (UUID/hash از `consultationId`)
- [x] نقش‌ها: بیمار `moderator: false` · پزشک/اپراتور `moderator: true`
- [x] `JWT_APP_ID` / issuer / audience: `pasteur_plus`

---

## فاز ۱ — DNS، TLS و دسترسی سرور

- [ ] رکورد DNS `A` (یا `AAAA`) → `meet.pasteur.plus` → IP VPS
- [ ] SSH و به‌روزرسانی اولیه OS (`apt update` و غیره)
- [ ] نصب Docker + docker compose plugin *(در `scripts/install-vps.sh` خودکار)*
- [ ] کاربر در گروه `docker` (logout/login)
- [ ] TLS برای `https://meet.pasteur.plus` (Let's Encrypt طبق doc `docker-jitsi-meet` یا reverse proxy)

---

## فاز ۲ — Deploy `docker-jitsi-meet` (فقط VPS)

- [ ] Clone: `/opt/jitsi` از https://github.com/jitsi/docker-jitsi-meet *(اسکریپت نصب)*
- [ ] Pin نسخه: tag stable (پیش‌فرض اسکریپت: `stable-9646`)
- [ ] `cp env.example .env` و تنظیم حداقل *(اسکریپت + `env.pasteur.example`)*:
  - [ ] `PUBLIC_URL=https://meet.pasteur.plus`
  - [ ] `ENABLE_AUTH=1`
  - [ ] `ENABLE_GUESTS=0`
  - [ ] `AUTH_TYPE=jwt`
  - [ ] `JWT_APP_ID=pasteur_plus`
  - [ ] `JWT_APP_SECRET` (تولید با `openssl rand -hex 32` — **فقط password manager / secrets**)
  - [ ] `JWT_ACCEPTED_ISSUERS=pasteur_plus`
  - [ ] `JWT_ACCEPTED_AUDIENCES=pasteur_plus`
  - [ ] `TZ=Asia/Tehran`
- [ ] `./gen-passwords.sh` (در صورت وجود در repo)
- [ ] `docker compose up -d`
- [ ] `docker compose ps` — سرویس‌ها healthy

---

## فاز ۳ — فایروال، JVB و TURN (ایران / موبایل)

- [ ] باز کردن `443/tcp` (HTTPS)
- [ ] باز کردن پورت UDP JVB (اغلب `10000` — مقدار دقیق از `.env` همان نسخه)
- [ ] پورت‌های Coturn طبق doc (مثلاً `3478` udp/tcp، `5349` tcp)
- [ ] Coturn/TURN در stack فعال و در `.env` درست
- [ ] تست تماس از **موبایل 4G ایران** — در صورت fail، TURN را عیب‌یابی کنید

---

## فاز ۴ — امنیت اتاق و embed از `pasteur.plus`

- [ ] Join **بدون** JWT → اتاق پزشکی باز نشود / رد شود
- [ ] محدودیت iframe: ancestor فقط `https://pasteur.plus` (+ staging در صورت نیاز) — `config/nginx-frame-ancestors.txt`
- [ ] در اپ آینده: CSP / `frame-src` اجازهٔ `https://meet.pasteur.plus`
- [x] (آماده در repo) UI فارسی: `config/custom-config.js` → کپی روی VPS با اسکریپت نصب

---

## فاز ۵ — تست پذیرش (Acceptance)

- [x] اسکریپت smoke: `mint-test-jwt.js`
- [ ] Join با JWT تست در مرورگر موفق *(بعد از deploy)*
- [ ] دو مرورگر، همان `room`: یکی `moderator: true`، یکی `false` — صدا/تصویر
- [ ] `exp` توکن: رفتار پس از انقضا (۱–۴ ساعت طبق قرارداد)
- [ ] iframe از `pasteur.plus` (یا staging) بدون خطای CSP
- [x] **`OPERATIONS.md`** در repo (روی سرور همان محتوا)

---

## فاز ۶ — تحویل به تیم اپ (Handoff)

- [x] پیش‌نویس `INTEGRATION-HANDOFF.md` (پس از deploy: تاریخ، tag، تست‌ها)
- [ ] ثبت: تاریخ deploy، مسئول، tag/commit `docker-jitsi-meet` واقعی
- [ ] تنظیم در Runflare **Secrets** (نه git):
  - [ ] `JITSI_DOMAIN=meet.pasteur.plus`
  - [ ] `JITSI_APP_ID=pasteur_plus`
  - [ ] `JITSI_APP_SECRET` = همان `JWT_APP_SECRET`
- [x] تأیید: `.gitignore` برای secret؛ secret در git commit نشود

---

## فاز ۷ — یکپارچه‌سازی در `pasteurmed10tir` (بعد از آماده بودن meet)

*خارج از scope deploy VPS؛ طبق spec §۶ و §۱۰.*

- [ ] خواندن `PASTEUR-MEET-DEPLOY-SPEC.md` + handoff پر شده
- [ ] env سرور: `JITSI_DOMAIN`, `JITSI_APP_ID`, `JITSI_APP_SECRET` (**هرگز client-side**)
- [ ] API: mint JWT HS256 فقط برای consultation مجاز (room، moderator، `exp` کوتاه)
- [ ] صفحات join بیمار/پزشک (web + `/app`) — iframe یا External API با token از API احراز هویت‌شده
- [ ] Prisma: `videoRoomName`، وضعیت session (`scheduled` / `in_call` / `completed`)
- [ ] ادمین: باز/اختصاص session ویدیو برای ویزیت‌های تأیید‌شده
- [ ] اثبات با `curl` روی staging/production — یک فاز در هر PR طبق `AGENTS.md` پروژهٔ اپ

---

## فاز ۸ — نگهداری و به‌روزرسانی

- [x] روتین مستند در `OPERATIONS.md`
- [ ] قبل از upgrade: backup `.env` و config سفارشی *(روی سرور، هنگام اولین آپدیت)*
- [ ] pull tag جدید stable → `docker compose up -d`
- [x] خارج از scope مگر درخواست جدا: Jibri (ضبط)، PostgreSQL اپ، درگاه پرداخت — در spec ثبت شده

---

## وضعیت کلی پروژه (این repo)

| مورد | وضعیت |
|------|--------|
| مستندات spec / handoff | موجود |
| اسکریپت نصب + JWT smoke + config | **آماده** |
| Deploy واقعی روی VPS | **منتظر VPS + DNS** |
| integrate در pasteur.plus | انجام نشده (repo دیگر) |

---

## قدم بعدی (شما)

1. این repo را push کنید.  
2. روی VPS: `bash /root/bootstrap-vps.sh` (از `scripts/bootstrap-vps.sh`).  
3. Secret را در Runflare بگذارید و تست‌های فاز ۵–۶ را تیک بزنید.

*آخرین به‌روزرسانی چک‌لیست: artefactهای repo + فاز ۰ قراردادی.*
