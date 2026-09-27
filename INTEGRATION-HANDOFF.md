# Pasteur Meet → Pasteur Plus — تحویل

**تاریخ deploy:** *(پس از اجرای `install-vps.sh` روی VPS پر کنید)*  
**مسئول:**  
**Public URL:** https://meet.pasteur.plus  

---

## متغیرهای env برای Runflare (`pasteur.plus`)

این مقادیر را در **Secrets / Environment** سرویس Next روی Runflare بگذارید.  
**`JITSI_APP_SECRET` را در git یا چت عمومی نفرستید.**

| متغیر | مقدار |
|--------|--------|
| `JITSI_DOMAIN` | `meet.pasteur.plus` |
| `JITSI_APP_ID` | `pasteur_plus` |
| `JITSI_APP_SECRET` | *(همان `JWT_APP_SECRET` در `/opt/jitsi/.env` یا `/root/pasteur-meet-jwt-secret.txt` روی VPS)* |

---

## Jitsi stack

| مورد | مقدار |
|------|--------|
| docker-jitsi-meet git tag / commit | `stable-9646` (پیش‌فرض اسکریپت — پس از deploy commit واقعی را بنویسید) |
| `PUBLIC_URL` | `https://meet.pasteur.plus` |
| JWT issuer / audience | `pasteur_plus` |
| پورت UDP JVB | معمولاً `10000` — از `.env` سرور |
| TURN تست از موبایل ایران | بله / خیر |
| embed از `https://pasteur.plus` | بله / خیر |

---

## تست انجام‌شده

- [ ] Join بدون JWT رد شد
- [ ] Join با JWT تست موفق (`node mint-test-jwt.js`)
- [ ] تماس ۱:۱ دو مرورگر (moderator true/false)
- [ ] OPERATIONS.md روی سرور Jitsi (کپی از repo: `OPERATIONS.md`)

---

## تماس

برای فاز integrate در `pasteurmed10tir`: پرامپت بخش ۱۰ در `PASTEUR-MEET-DEPLOY-SPEC.md`.
