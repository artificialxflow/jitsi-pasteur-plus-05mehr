# pasteur-meet (زیرساخت Jitsi)

ویدیوی ۱:۱ برای Pasteur Plus روی دامنهٔ جدا: **https://meet.pasteur-plus.com**

- مشخصات: [`jitsi/PASTEUR-MEET-DEPLOY-SPEC.md`](jitsi/PASTEUR-MEET-DEPLOY-SPEC.md)
- چک‌لیست: [`todo.md`](todo.md)
- عملیات: [`OPERATIONS.md`](OPERATIONS.md)

## آنچه در این repo آماده است

| فایل | کاربرد |
|------|--------|
| `scripts/bootstrap-vps.sh` | نصب یک‌مرحله‌ای روی Ubuntu VPS تازه (توصیه‌شده) |
| `scripts/install-vps.sh` | Docker + docker-jitsi-meet + JWT + LE |
| `env.pasteur.example` | کلیدهای `.env` Pasteur |
| `mint-test-jwt.js` | ساخت JWT تست |
| `config/*` | UI فارسی، embed nginx |

## deploy روی VPS (یک اسکریپت)

پیش‌نیاز: DNS `A` برای `meet.pasteur-plus.com` → IP سرور (Cloudflare: **DNS only**).  
این repo را به GitHub push کنید، بعد روی VPS به‌عنوان root:

```bash
curl -fsSL https://raw.githubusercontent.com/artificialxflow/jitsi-pasteur-plus-05mehr/main/scripts/bootstrap-vps.sh \
  -o /root/bootstrap-vps.sh
bash /root/bootstrap-vps.sh
```

یا با nano پیست کنید و `bash /root/bootstrap-vps.sh` بزنید.

اختیاری قبل از اجرا:

```bash
export LETSENCRYPT_EMAIL=you@pasteur-plus.com   # پیش‌فرض: admin@pasteur-plus.com
export PUBLIC_URL=https://meet.pasteur-plus.com
```

اسکریپت خودش: apt/git/ufw، clone این repo، Docker، Jitsi، JWT، Let's Encrypt، UI فارسی و لاگ در `/var/log/pasteur-meet/`.

بعد از نصب:

1. Secret: `cat /root/pasteur-meet-jwt-secret.txt` → در Runflare به‌عنوان `JITSI_APP_SECRET`
2. تست: `JITSI_APP_SECRET=... JITSI_DOMAIN=meet.pasteur-plus.com node mint-test-jwt.js`
3. `INTEGRATION-HANDOFF.md` را تکمیل کنید

**کد Next.js اینجا نیست** — integrate در repo `pasteurmed10tir`.

**پوشه `jitsi/`** فقط مستندات مرجع (spec، handoff template) است.
