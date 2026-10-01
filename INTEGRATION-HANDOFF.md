# Pasteur Meet → Pasteur Plus — تحویل

**تاریخ deploy:** 2026-10-01  
**Public URL:** https://meet.pasteur-plus.com  
**راهنمای کامل integrate در اپ:** [`PASTEUR-PLUS-INTEGRATION.md`](PASTEUR-PLUS-INTEGRATION.md) ← این فایل را ببرید به repo پاستور پلاس

---

## متغیرهای env برای Runflare (`pasteur.plus`)

این مقادیر را در **Secrets / Environment** سرویس Next روی Runflare بگذارید.  
**`JITSI_APP_SECRET` را در git یا چت عمومی نفرستید.**

| متغیر | مقدار |
|--------|--------|
| `JITSI_DOMAIN` | `meet.pasteur-plus.com` |
| `JITSI_APP_ID` | `pasteur_plus` |
| `JITSI_APP_SECRET` | از VPS: `cat /root/pasteur-meet-jwt-secret.txt` |

---

## Jitsi stack

| مورد | مقدار |
|------|--------|
| docker-jitsi-meet git tag | `stable-9646` |
| `PUBLIC_URL` | `https://meet.pasteur-plus.com` |
| JWT issuer / audience | `pasteur_plus` |
| پورت HTTP/HTTPS | `80` / `443` |
| پورت UDP JVB | `10000` |
| HTTPS زنده | بله (در صورت fail بودن acme داخل کانتینر: `scripts/issue-cert-certbot.sh`) |
| Join بدون JWT | رد می‌شود |
| embed از `https://pasteur.plus` | هنوز در اپ — فاز integrate |

---

## تست انجام‌شده

- [x] Stack بالا (web/prosody/jicofo/jvb)
- [x] `https://meet.pasteur-plus.com` باز می‌شود
- [x] Join بدون JWT → احراز هویت لازم / رد
- [ ] Join با JWT ساخته‌شده از `mint-test-jwt.js` (نه خود secret)
- [ ] تماس ۱:۱ دو مرورگر
- [ ] TURN از موبایل ایران

---

## فاز بعد

کپی [`PASTEUR-PLUS-INTEGRATION.md`](PASTEUR-PLUS-INTEGRATION.md) به پروژه اپ و اجرای پرامپت Agent داخل آن.
