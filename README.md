# Telegram MTProto Proxy on Railway (Free Tier)

پروکسی خودمیزبان (self-hosted) MTProto سازگار با پروتکل رسمی تلگرام،
بسته‌بندی‌شده در Docker، آماده‌ی Deploy روی Railway از طریق GitHub —
بدون نیاز به VPS.

موتور پروکسی: [`mtg`](https://github.com/9seconds/mtg) — پیاده‌سازی Go
از پروتکل MTProto تلگرام (شامل حالت FakeTLS، دقیقاً همان چیزی که
پروکسی رسمی تلگرام هم استفاده می‌کند).

---

## ⚠️ قبل از شروع: دو محدودیت واقعی Railway که باید بدانید

1. **"رایگان" یعنی اعتبار محدود، نه دائمی.** Railway یک اعتبار Trial
   یک‌بارمصرف (معمولاً ۵ دلار، حدود ۳۰ روز) می‌دهد و بعد از آن پلن
   Free با سقف ماهانه کوچک ادامه پیدا می‌کند. این پروکسی مصرف
   منابع بسیار پایینی دارد (چند مگابایت RAM) پس معمولاً در همین سقف
   جا می‌شود، اما مسئولیت پیگیری مصرف با شماست — اگر اعتبار تمام شود
   Railway خودش سرویس را متوقف می‌کند.
2. **پورت خروجی، پورت دلخواه شما نیست.** Railway برای ترافیک خام TCP
   (که MTProto به آن نیاز دارد) یک دامنه و **پورت تصادفی** اختصاص
   می‌دهد (مثل `xyz.proxy.rlwy.net:15423`). نمی‌توان از طریق Dockerfile
   یا کد این را به ۴۴۳ ثابت کرد — این یک تصمیم زیرساختی Railway است.
   خبر خوب: پروتکل MTProto به پورت ۴۴۳ نیازی ندارد؛ کلاینت تلگرام هر
   پورتی که در لینک `t.me/proxy` باشد را قبول می‌کند.

---

## معماری

```
GitHub repo  ──push──▶  Railway Build (Dockerfile)
                              │
                              ▼
                    ┌───────────────────┐
                    │  Alpine container  │
                    │  ┌──────────────┐  │
                    │  │  start.sh    │  │   ENV: APP_PORT, SECRET,
                    │  │  (entrypoint)│──┼─▶ FAKE_TLS_DOMAIN, SERVER,
                    │  └──────┬───────┘  │   DISPLAY_PORT, WORKERS
                    │         ▼          │
                    │  ┌──────────────┐  │
                    │  │  mtg binary  │◀─┼── binds 0.0.0.0:APP_PORT
                    │  └──────────────┘  │
                    └─────────┬──────────┘
                              │  Railway TCP Proxy
                              ▼  (manual one-time setup)
                   xyz.proxy.rlwy.net : <random-port>
                              │
                              ▼
                     Telegram client
              (via t.me/proxy?server=...&port=...&secret=...)
```

---

## ساختار فایل‌ها

```
mtproto-railway-proxy/
├── Dockerfile          # بیلد چندمرحله‌ای، باینری رسمی mtg + Alpine
├── start.sh            # تولید secret، ساخت config، چاپ لینک، اجرای mtg
├── railway.json         # به Railway می‌گوید از همین Dockerfile بیلد کند
├── .env.example         # فهرست Environment Variables با توضیح
├── .dockerignore
└── README.md
```

---

## دیپلوی روی Railway (مرحله به مرحله)

### ۱. پوش کردن روی GitHub
```bash
git init
git add .
git commit -m "Telegram MTProto proxy for Railway"
git branch -M main
git remote add origin https://github.com/<username>/<repo>.git
git push -u origin main
```

### ۲. ساخت پروژه در Railway
1. وارد [railway.app](https://railway.app) شو → **New Project** →
   **Deploy from GitHub repo** → ریپازیتوری بالا را انتخاب کن.
2. Railway به‌طور خودکار `railway.json` را می‌بیند و از `Dockerfile`
   بیلد می‌کند — کار دیگری لازم نیست.

### ۳. تنظیم Variables (بخش Variables سرویس)
مطابق `.env.example`:
| متغیر | مقدار پیشنهادی |
|---|---|
| `APP_PORT` | `443` |
| `SECRET` | خالی بگذار، بعد از اولین دیپلوی از لاگ کپی کن |
| `FAKE_TLS_DOMAIN` | یک دامنه HTTPS معتبر و غیرمسدود، مثل `www.cloudflare.com` |
| `SERVER` | Reference → `${{RAILWAY_TCP_PROXY_DOMAIN}}` |
| `DISPLAY_PORT` | Reference → `${{RAILWAY_TCP_PROXY_PORT}}` |
| `WORKERS` | `1` (کافی برای بار سبک) |

### ۴. تنها قدم دستی غیرقابل‌حذف: فعال‌سازی TCP Proxy
در تب **Settings → Networking** سرویس:
- روی **TCP Proxy → Add** بزن.
- Application Port را همان مقدار `APP_PORT` (پیش‌فرض `443`) بده.
- Railway یک دامنه و پورت عمومی به تو می‌دهد و متغیرهای
  `RAILWAY_TCP_PROXY_DOMAIN` / `RAILWAY_TCP_PROXY_PORT` را خودکار پر می‌کند
  — همان‌هایی که در مرحله‌ی ۳ به `SERVER` / `DISPLAY_PORT` رفرنس دادی.

این تنها کلیکی است که پلتفرم Railway (نه پروژه‌ی شما) به آن نیاز دارد؛
هیچ SSH یا تنظیم دستی داخل سرور لازم نیست.

### ۵. Redeploy
بعد از افزودن TCP Proxy، یک **Redeploy** بزن تا Variableهای جدید
(`RAILWAY_TCP_PROXY_*`) در کانتینر تزریق شوند.

---

## تست سالم بودن Proxy

### الف) از طریق لاگ‌ها
در تب **Deployments → Logs** باید خط‌هایی شبیه این ببینی:
```
[mtproto-proxy] starting up...
[mtproto-proxy] using SECRET from environment
[mtproto-proxy] config written to /app/config.toml (internal bind: 0.0.0.0:443)
[mtproto-proxy] MTProto Proxy connect link:
[mtproto-proxy] https://t.me/proxy?server=xyz.proxy.rlwy.net&port=15423&secret=ee...
[mtproto-proxy] launching mtg...
```
اگر این خط‌ها ظاهر شدند و کانتینر Restart Loop نشد، پروکسی بالا است.

### ب) تست باز بودن پورت از بیرون
```bash
nc -vz xyz.proxy.rlwy.net 15423
# یا
openssl s_client -connect xyz.proxy.rlwy.net:15423 -tls1_2 </dev/null
```
باتوجه به FakeTLS، اتصال TLS برقرار می‌شود ولی handshake واقعی رد
می‌شود مگر با secret درست — همین یعنی سرویس به‌درستی گوش می‌دهد.

### ج) تست واقعی با کلاینت تلگرام
ساده‌ترین و مطمئن‌ترین روش: لینک تولیدشده را در کلاینت تلگرام
(دسکتاپ/موبایل) باز کن و روی **Connect** بزن.

---

## ساخت لینک نهایی Telegram Proxy

لینک به‌طور خودکار در لاگ‌های start.sh چاپ می‌شود. فرمول آن:
```
https://t.me/proxy?server=<RAILWAY_TCP_PROXY_DOMAIN>&port=<RAILWAY_TCP_PROXY_PORT>&secret=<SECRET>
```
یا معادل اسکیم داخل‌اپلیکیشنی:
```
tg://proxy?server=<...>&port=<...>&secret=<...>
```

---

## مشکلات رایج Railway Free و راه‌حل

| مشکل | علت | راه‌حل |
|---|---|---|
| سرویس بعد از چند روز خاموش می‌شود | اعتبار Trial تمام شده | حساب را ارتقا بده به Free ($1/ماه) یا Hobby؛ یا اعتبار Trial جدید با ایمیل/حساب دیگر (فقط برای تست) |
| لینک اتصال هر بار عوض می‌شود | `SECRET` ثابت نشده و هر ری‌استارت مقدار تصادفی جدید تولید می‌شود | مقدار چاپ‌شده در لاگ را در Variable ثابت `SECRET` کپی کن |
| کلاینت وصل نمی‌شود ولی لاگ سالم است | فایروال مقصد فقط پورت ۴۴۳ خروجی را باز می‌گذارد و پورت تصادفی Railway مسدود است | راهی برای گرفتن ۴۴۳ ثابت روی Railway وجود ندارد؛ اگر این مسئله جدی است، به یک ارائه‌دهنده که Custom Port/443 واقعی می‌دهد (مثل یک VPS ارزان یا Fly.io با `[[services]] internal_port=443`) مهاجرت کن |
| کانتینر مدام Restart می‌شود | `APP_PORT` تنظیم‌شده در Variables با Application Port انتخاب‌شده در TCP Proxy یکی نیست | هر دو را برابر بگذار (مثلاً هر دو `443`) |
| مصرف Egress بالا می‌رود | تعداد زیاد کاربر همزمان به پروکسی وصل شده‌اند | پروکسی را فقط برای گروه کوچکی به اشتراک بگذار؛ این توصیه‌ی خود پروژه‌ی mtg هم هست |

---

## اگر Railway Free واقعاً کافی نبود

اگر بعد از اتمام اعتبار Trial، محدودیت هزینه/زمان برایتان جدی شد،
صادقانه‌ترین جایگزین رایگان/ارزان برای همین معماری Docker:
- **Fly.io** — پلن رایگان محدودتر شده ولی امکان `internal_port` دلخواه
  (از جمله ۴۴۳ واقعی) روی `fly.toml` را می‌دهد؛ همین Dockerfile با
  تغییر جزئی startup قابل استفاده است.
- **Oracle Cloud Free Tier (Always Free)** — این عملاً یک VPS رایگان
  دائمی است (نه Railway)، اگر محدودیت "بدون VPS" شما قابل بازبینی
  باشد، پایدارترین گزینه‌ی رایگان بلندمدت برای MTProto proxy همین است.

---

## لایسنس
این پروژه Open Source است و از باینری رسمی و MIT-licensed پروژه‌ی
[9seconds/mtg](https://github.com/9seconds/mtg) استفاده می‌کند.
