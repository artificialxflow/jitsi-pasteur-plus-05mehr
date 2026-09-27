# Pasteur Meet → Pasteur Plus — قالب تحویل (پس از deploy پر کنید)

**تاریخ deploy:**  
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
| `JITSI_APP_SECRET` | *(همان `JWT_APP_SECRET` در `.env` Jitsi)* |

---

## Jitsi stack

| مورد | مقدار |
|------|--------|
| docker-jitsi-meet git tag / commit | |
| `PUBLIC_URL` | |
| JWT issuer / audience | `pasteur_plus` |
| پورت UDP JVB | |
| TURN تست از موبایل ایران | بله / خیر |
| embed از `https://pasteur.plus` | بله / خیر |

---

## تست انجام‌شده

- [ ] Join بدون JWT رد شد
- [ ] Join با JWT تست موفق
- [ ] تماس ۱:۱ دو مرورگر (moderator true/false)
- [ ] OPERATIONS.md روی سرور Jitsi نوشته شد

---

## تماس

برای فاز integrate در `pasteurmed10tir`: پرامپت بخش ۱۰ در `PASTEUR-MEET-DEPLOY-SPEC.md`.
