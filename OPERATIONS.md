# Pasteur Meet — عملیات سرور (`meet.pasteur.plus`)

مسیر پیش‌فرض نصب: `/opt/jitsi` (docker-jitsi-meet).

## وضعیت سرویس‌ها

```bash
cd /opt/jitsi && docker compose ps
docker compose logs -f --tail=100 web prosody jicofo jvb
```

## پورت‌ها (فایروال VPS / پنل هاست)

| پورت | پروتکل | کاربرد |
|------|--------|--------|
| 80 | tcp | HTTP (Let's Encrypt challenge / redirect) |
| 443 | tcp | HTTPS (وب Jitsi) |
| 10000 | udp | JVB (مقدار را از `.env` بخوانید: `JVB_PORT`) |
| 3478 | udp/tcp | Coturn |
| 5349 | tcp | Coturn TLS |

## JWT

- Secret در `.env`: `JWT_APP_SECRET`
- همان مقدار در Runflare: `JITSI_APP_SECRET`
- روی سرور پشتیبان: `/root/pasteur-meet-jwt-secret.txt` (اگر با `install-vps.sh` نصب شده)

## Embed از `pasteur.plus`

1. در اپ Next: CSP `frame-src https://meet.pasteur.plus`
2. در Jitsi nginx: `frame-ancestors` — راهنما در `config/nginx-frame-ancestors.txt`
3. پس از ویرایش nginx: `cd /opt/jitsi && docker compose restart web`

## به‌روزرسانی

```bash
cd /opt/jitsi
cp .env .env.backup.$(date +%F)
git fetch --tags
git checkout stable-XXXX   # tag جدید stable
docker compose pull
docker compose up -d
```

## پشتیبان

- `.env` و فایل‌های `$CONFIG/web/custom-*.js`
- ویدیو ذخیره نمی‌شود (بدون Jibri)

## عیب‌یابی تماس موبایل ایران

- تست از 4G با JWT معتبر
- اگر ویدیو نمی‌آید: لاگ `jvb` و تنظیمات TURN/Coturn در `.env`
- `docker compose logs jvb | tail -50`

## Smoke test از لپتاپ

```bash
JITSI_APP_SECRET='...' node mint-test-jwt.js
```
