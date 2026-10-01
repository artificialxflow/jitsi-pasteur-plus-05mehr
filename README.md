# pasteur-meet (زیرساخت Jitsi)

ویدیوی ۱:۱ برای Pasteur Plus روی دامنهٔ جدا: **https://meet.pasteur-plus.com**

- مشخصات: [`jitsi/PASTEUR-MEET-DEPLOY-SPEC.md`](jitsi/PASTEUR-MEET-DEPLOY-SPEC.md)
- **Integrate در اپ:** [`PASTEUR-PLUS-INTEGRATION.md`](PASTEUR-PLUS-INTEGRATION.md) ← ببرید به pasteur.plus
- تحویل: [`INTEGRATION-HANDOFF.md`](INTEGRATION-HANDOFF.md)
- چک‌لیست: [`todo.md`](todo.md)
- عملیات: [`OPERATIONS.md`](OPERATIONS.md)

## آنچه در این repo آماده است

| فایل | کاربرد |
|------|--------|
| `scripts/bootstrap-vps.sh` | نصب یک‌مرحله‌ای روی Ubuntu VPS تازه (توصیه‌شده) |
| `scripts/install-vps.sh` | Docker + docker-jitsi-meet + JWT + پورت 80/443 |
| `scripts/issue-cert-certbot.sh` | اگر SSL داخل کانتینر fail شد (ZeroSSL) |
| `PASTEUR-PLUS-INTEGRATION.md` | راهنما + پرامپت برای repo اپ |
| `env.pasteur.example` | کلیدهای `.env` Pasteur |
| `mint-test-jwt.js` | ساخت JWT تست (نه خود secret) |
| `logo.png` / `config/branding/` | لوگوی Clinique Pasteur |
| `scripts/apply-branding.sh` | اعمال لوگو + متن فارسی روی VPS موجود |
| `config/*` | UI فارسی، برندینگ، embed nginx |

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

1. اگر HTTPS بالا نیامد: `sudo bash scripts/issue-cert-certbot.sh`
2. Secret: `cat /root/pasteur-meet-jwt-secret.txt` → Runflare = `JITSI_APP_SECRET`
3. تست JWT: `JITSI_APP_SECRET=... JITSI_DOMAIN=meet.pasteur-plus.com node mint-test-jwt.js`  
   لینک چاپ‌شده را باز کنید (`jwt=` باید سه بخش با نقطه باشد، نه خود secret)
4. برای اتصال از اپ: فایل [`PASTEUR-PLUS-INTEGRATION.md`](PASTEUR-PLUS-INTEGRATION.md)

**کد Next.js اینجا نیست** — integrate در repo اپ pasteur.plus.

**پوشه `jitsi/`** فقط مستندات مرجع (spec، handoff template) است.
