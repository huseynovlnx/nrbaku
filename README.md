# Sesi Push Relay — Avtomatik Qurulum

## Sənin ediləcəyin (3 addım, 5 dəqiqə)

1. **Firebase-dən endirdiyin `.json` açar faylını** bu qovluğa (`cloudflare-worker/`) köçür
   (fayl adı təxminən `flutter-ai-playground-a0afa-firebase-adminsdk-....json` kimidir)

2. PowerShell-də bu qovluğa keç, skripti işə sal:
   ```powershell
   cd cloudflare-worker
   powershell -ExecutionPolicy Bypass -File deploy.ps1
   ```

3. Brauzer açılanda Cloudflare hesabınla **1 dəfə** təsdiqlə (bu, Cloudflare-in
   təhlükəsizlik tələbidir — mən bunu sənin əvəzinə edə bilmirəm, hər hansı
   bir tərəf sənin adından giriş edə bilməməlidir).

Skript qalan **hər şeyi özü edəcək**: secret-ları yükləyəcək, Worker-i
deploy edəcək, sonda 2 dəyər çap edəcək (Worker URL + Auth Secret) və
`DEPLOY_RESULT.txt` faylına yazacaq.

---

## Bitdikdən sonra

Terminaldakı (və ya `DEPLOY_RESULT.txt` faylındakı) 2 sətri mənə göndər:
```
WORKER_URL=https://sesi-push-relay.xxxxx.workers.dev
WORKER_AUTH_SECRET=xxxxxxxxxxxxxxxxxxxx
```

Bunları göndərəndə, mən Flutter tərəfini (chat, təcili çağırış, xatırladıcı
bildirişlər) avtomatik bu Worker-ə bağlayıb, sənə tam hazır APK-yə gedən
kodu verəcəyəm — bu hissədə artıq heç bir əlavə iş görməyəcəksən.

---

## Əgər skript xəta versə

- **"wrangler tapılmadı, quraşdırılır" uzun çəkir/xəta verir** → əl ilə
  `npm install -g wrangler` işlət, sonra skripti yenidən başlat
- **"JSON faylı tapılmadı"** → faylın adının `firebase-adminsdk` sözünü
  daxil etdiyini və eyni qovluqda olduğunu yoxla
- **Digər xəta** → tam terminal nəticəsini mənə göndər, düzəldərəm
