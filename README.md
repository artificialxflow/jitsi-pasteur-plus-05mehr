# pasteur-meet (زیرساخت Jitsi)

ویدیوی ۱:۱ برای [Pasteur Plus](https://pasteur.plus) روی دامنهٔ جدا: **https://meet.pasteur.plus**

- مشخصات: [`jitsi/PASTEUR-MEET-DEPLOY-SPEC.md`](jitsi/PASTEUR-MEET-DEPLOY-SPEC.md)
- چک‌لیست: [`todo.md`](todo.md)
- عملیات: [`OPERATIONS.md`](OPERATIONS.md)

## آنچه در این repo آماده است

| فایل | کاربرد |
|------|--------|
| `scripts/install-vps.sh` | نصب خودکار روی Ubuntu VPS |
| `env.pasteur.example` | کلیدهای `.env` Pasteur |
| `mint-test-jwt.js` | ساخت JWT تست |
| `config/*` | UI فارسی، embed nginx |

## deploy روی VPS (خلاصه)

1. VPS (≥ 4 vCPU, 8 GB RAM) + DNS `A` → `meet.pasteur.plus`
2. فایروال: `443/tcp`, `10000/udp`, Coturn
3. روی سرور:

```bash
git clone <این-repo> /opt/pasteur-meet-repo
cd /opt/pasteur-meet-repo
export LETSENCRYPT_EMAIL=you@pasteur.plus
sudo -E bash scripts/install-vps.sh
```

4. Secret را از `/root/pasteur-meet-jwt-secret.txt` در Runflare به‌عنوان `JITSI_APP_SECRET` بگذارید.
5. تست: `JITSI_APP_SECRET=... node mint-test-jwt.js`
6. `INTEGRATION-HANDOFF.md` را تکمیل کنید.

**کد Next.js اینجا نیست** — integrate در repo `pasteurmed10tir`.

**پوشه `jitsi/`** فقط مستندات مرجع (spec، handoff template) است.
