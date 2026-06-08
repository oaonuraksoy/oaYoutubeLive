# oaYoutubeLive Windows Tek Satır Kurulum Betiği (Host Installer)
# Kullanım: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

# Yapılandırma
$licenseServerUrl = "https://ytlive-licensing.oasrvcom.workers.dev"
$downloadUrl = "https://github.com/oaonuraksoy/oaYoutubeLive/releases/download/v2026.6.9/ytlive-dist.zip" # Google Drive veya Cloudflare R2 indirme linki

Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "      oaYoutubeLive Canlı Yayın Bilgi Yarışması Kurulumu    " -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow

# Bağımlılık Kontrolleri
Write-Host "[1/5] Sistem gereksinimleri kontrol ediliyor..." -ForegroundColor Cyan

if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Error "Hata: Docker kurulu değil. Lütfen önce Docker ve Docker Desktop kurun."
    exit 1
}

if (-not (Get-Command "docker-compose" -ErrorAction SilentlyContinue)) {
    Write-Error "Hata: Docker Compose kurulu değil. Lütfen Docker Compose kurun."
    exit 1
}

# Donanım Kimliği (HWID) Hesaplama
Write-Host "[2/5] Donanım kimliği (HWID) hesaplanıyor..." -ForegroundColor Cyan
$uuid = ""

try {
    $uuid = (Get-CimInstance Win32_ComputerSystemProduct).UUID
} catch {
    # Alternatif sorgu
    try {
        $uuid = (Get-WmiObject Win32_ComputerSystemProduct).UUID
    } catch {
        Write-Host "Bilgi: Sistem UUID okunamadı, MAC adreslerine yönleniliyor..." -ForegroundColor Gray
    }
}

if ([string]::IsNullOrEmpty($uuid) -or $uuid -eq "00000000-0000-0000-0000-000000000000" -or $uuid.ToLower().Contains("not specified")) {
    # MAC Adreslerini tara ve SHA-256 ile özetle
    $macs = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } | Select-Object -ExpandProperty MacAddress
    if ($macs) {
        $macString = ($macs | Sort-Object) -join ""
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($macString))
        $hwid = ([System.BitConverter]::ToString($hashBytes) -replace "-").ToLower()
    } else {
        $hwid = [System.Guid]::NewGuid().ToString("N")
    }
} else {
    # Sistem UUID'sini hash'le
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($uuid))
    $hwid = ([System.BitConverter]::ToString($hashBytes) -replace "-").ToLower()
}

Write-Host "Donanım Kimliğiniz (HWID): $hwid" -ForegroundColor Green

# Lisans Girişi & Aktivasyon
Write-Host "[3/5] Lisans aktivasyonu başlatılıyor..." -ForegroundColor Cyan
$licenseKey = Read-Host "Lütfen Lisans Anahtarınızı Girin"

if ([string]::IsNullOrWhiteSpace($licenseKey)) {
    Write-Error "Hata: Lisans anahtarı boş bırakılamaz."
    exit 1
}

Write-Host "Aktivasyon sunucusu ile el sıkışılıyor..." -ForegroundColor Gray
$body = @{
    licenseKey = $licenseKey
    hwid = $hwid
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$licenseServerUrl/api/activate" -Method Post -Body $body -ContentType "application/json"
    
    if ($response.success -eq $true) {
        Write-Host "✓ Lisans başarıyla doğrulandı ve bu cihaza kilitlendi!" -ForegroundColor Green
    } else {
        Write-Error "Hata: Lisans doğrulaması başarısız! Sunucu Yanıtı: $($response.message)"
        exit 1
    }
} catch {
    Write-Error "Aktivasyon sunucusuna bağlanılamadı. İnternet bağlantınızı veya sunucu adresini kontrol edin.`nHata detayı: $_"
    exit 1
}

# Klasör ve Dosyaların Hazırlanması
Write-Host "[4/5] Kurulum dizinleri ve lisans anahtarı kaydediliyor..." -ForegroundColor Cyan
if (-not (Test-Path "data")) {
    New-Item -ItemType Directory -Path "data" | Out-Null
}

# Lisans bilgisini data/license.json dosyasına yaz
$licenseJson = $response.license | ConvertTo-Json -Depth 5
Set-Content -Path "data\license.json" -Value $licenseJson -Encoding UTF8

# .env dosyasını oluştur
$envContent = @"
PORT=3000
FRONTEND_URL=http://localhost:5173
REDIS_HOST=redis
REDIS_PORT=6379
HOST_HWID=$hwid
LICENSE_KEY=$licenseKey
LICENSE_SERVER_URL=$licenseServerUrl
"@

Set-Content -Path ".env" -Value $envContent -Encoding UTF8

# Proje Paketinin İndirilmesi
Write-Host "[5/5] Uygulama dosyaları indiriliyor ve başlatılıyor..." -ForegroundColor Cyan

if ($downloadUrl -eq "YOUR_ZIP_DOWNLOAD_URL_HERE") {
    Write-Host "Bilgilendirme: Proje dosyaları yerel kaynaklardan derlenerek başlatılıyor." -ForegroundColor Gray
} else {
    Write-Host "Güncel derlenmiş sürüm indiriliyor..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile "project.zip"
    Expand-Archive -Path "project.zip" -DestinationPath "." -Force
    Remove-Item "project.zip" -Force
}

# Docker konteynerlerini başlat
Write-Host "Docker servisleri başlatılıyor..." -ForegroundColor Gray
docker-compose up -d --build

Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "✓ Kurulum Başarıyla Tamamlandı!" -ForegroundColor Green
Write-Host "----------------------------------------------------" -ForegroundColor Gray
Write-Host "Yönetim Paneli: http://localhost:5173" -ForegroundColor Green
Write-Host "Yayın Ekranı:   http://localhost:3000" -ForegroundColor Green
Write-Host "Lisans Sahibi:  $($response.license.owner)" -ForegroundColor Green
Write-Host "Bitiş Tarihi:   $($response.license.expiresAt)" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Yellow
