# =====================================================================
# Sesi Push Relay — AVTOMATIK QURULUM
# =====================================================================
# Bu skript hər şeyi sənin əvəzinə edir:
#   - wrangler CLI-ni yoxlayır/quraşdırır
#   - Firebase service account JSON-undan lazımi dəyərləri özü oxuyur
#   - Təsadüfi WORKER_AUTH_SECRET yaradır
#   - Bütün secret-ları Cloudflare-ə avtomatik yükləyir (dashboard-da
#     əl ilə klikləməyə ehtiyac YOXDUR)
#   - Worker-i deploy edir
#   - Sonda Flutter tərəfə lazım olan 2 dəyəri (URL + secret) çap edir
#
# SƏNDƏN TƏLƏB OLUNAN YEGANƏ ŞEY:
#   1) Firebase-dən endirdiyin .json açar faylını bu skriptlə EYNİ
#      qovluğa qoy
#   2) Bu skripti işə sal: powershell -ExecutionPolicy Bypass -File deploy.ps1
#   3) Brauzer açılanda Cloudflare hesabınla 1 dəfə təsdiqlə (bunu mən
#      sənin əvəzinə edə bilmirəm — Cloudflare-in öz təhlükəsizlik
#      tələbidir)
# =====================================================================

$ErrorActionPreference = "Continue"

Write-Host "`n=== Sesi Push Relay Avtomatik Qurulum ===" -ForegroundColor Cyan

# ── 1. wrangler CLI yoxla/quraşdır ──────────────────────────────────
Write-Host "`n[1/6] wrangler CLI yoxlanılır..." -ForegroundColor Yellow
$wranglerExists = Get-Command wrangler -ErrorAction SilentlyContinue
if (-not $wranglerExists) {
    Write-Host "wrangler tapılmadı, quraşdırılır (npm install -g wrangler)..."
    npm install -g wrangler
} else {
    Write-Host "wrangler artıq quraşdırılıb ✓"
}

# ── 2. Firebase JSON faylını tap ────────────────────────────────────
Write-Host "`n[2/6] Firebase açar faylı axtarılır..." -ForegroundColor Yellow
$jsonFile = Get-ChildItem -Path $PSScriptRoot -Filter "*firebase-adminsdk*.json" | Select-Object -First 1
if (-not $jsonFile) {
    Write-Host "XƏTA: Bu qovluqda 'firebase-adminsdk...json' adlı fayl tapılmadı." -ForegroundColor Red
    Write-Host "Firebase Console-dan endirdiyin JSON faylını bu skriptlə eyni qovluğa qoy və yenidən sına."
    exit 1
}
Write-Host "Tapıldı: $($jsonFile.Name) ✓"

$creds = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
$projectId    = $creds.project_id
$clientEmail  = $creds.client_email
$privateKey   = $creds.private_key

# ── 3. Təsadüfi WORKER_AUTH_SECRET yarat ────────────────────────────
Write-Host "`n[3/6] Təhlükəsizlik açarı yaradılır..." -ForegroundColor Yellow
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$authSecret = [Convert]::ToBase64String($bytes) -replace '[+/=]', '' 
Write-Host "Yaradıldı ✓"

# ── 4. Cloudflare-ə giriş (YALNIZ BURADA BRAUZER AÇILACAQ) ──────────
Write-Host "`n[4/6] Cloudflare girişi — brauzer açılacaq, 1 dəfə təsdiqlə..." -ForegroundColor Yellow
wrangler login

# ── 5. Secret-ları avtomatik yüklə ──────────────────────────────────
Write-Host "`n[5/6] Secret-lar Cloudflare-ə yüklənir..." -ForegroundColor Yellow

function Set-WranglerSecret {
    param([string]$Name, [string]$Value)
    Write-Host "  -> $Name yüklənir..."
    $Value | wrangler secret put $Name
}

Set-WranglerSecret -Name "FIREBASE_PROJECT_ID"   -Value $projectId
Set-WranglerSecret -Name "FIREBASE_CLIENT_EMAIL" -Value $clientEmail
Set-WranglerSecret -Name "FIREBASE_PRIVATE_KEY"  -Value $privateKey
Set-WranglerSecret -Name "WORKER_AUTH_SECRET"    -Value $authSecret

# ── 6. Deploy et ─────────────────────────────────────────────────────
Write-Host "`n[6/6] Worker deploy edilir..." -ForegroundColor Yellow
$deployLog = wrangler deploy 2>&1 | Out-String
Write-Host $deployLog
$workerUrl = ($deployLog | Select-String -Pattern "https://[a-zA-Z0-9\-\.]+\.workers\.dev" -AllMatches).Matches.Value | Select-Object -First 1

# ── Nəticə ───────────────────────────────────────────────────────────
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "  HAZIRDIR! 🎉" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Worker URL:    $workerUrl"
Write-Host "Auth Secret:   $authSecret"
Write-Host ""
Write-Host "Bu 2 dəyəri kopyala — Flutter tərəfə lazım olacaq." -ForegroundColor Cyan
Write-Host "Nəticəni Claude-a göndər, o, Flutter kodunu avtomatik quracaq." -ForegroundColor Cyan
Write-Host ""

# Nəticəni fayla da yaz ki, itməsin
@"
WORKER_URL=$workerUrl
WORKER_AUTH_SECRET=$authSecret
"@ | Out-File -FilePath "$PSScriptRoot\DEPLOY_RESULT.txt" -Encoding utf8

Write-Host "Bu məlumat həm də 'DEPLOY_RESULT.txt' faylına yazıldı." -ForegroundColor Gray
