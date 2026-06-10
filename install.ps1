# oaYoutubeLive Windows Tek Satır Kurulum Betiği (Host Installer)
# Kullanım: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

# Türkçe karakter desteği için konsol çıktı kodlamasını UTF-8 olarak ayarla
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Yapılandırma
$licenseServerUrl = "https://ytlive-licensing.oasrvcom.workers.dev"
$downloadUrl = "https://github.com/oaonuraksoy/oaYoutubeLive/releases/latest/download/ytlive-dist.zip" # Github releases en son surum indirme linki

Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "      oaYoutubeLive Canlı Yayın Bilgi Yarışması Kurulumu    " -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow

# 1. Administrator Yetkisi Kontrolü
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "UYARI: Kurulum betiği yönetici (Administrator) yetkileri olmadan çalışıyor."
    Write-Warning "Kurulum ve servis yapılandırması sırasında hata almamak için yönetici olarak çalıştırılması önerilir."
    Write-Host "Devam etmek istiyor musunuz? (y/N): " -NoNewline
    $ans = Read-Host
    if ($ans -notmatch '^[Yy]$') {
        exit 1
    }
}

# 2. Bağımlılık Kontrolü & Sürüm Teşhisi
Write-Host "[1/5] Sistem gereksinimleri kontrol ediliyor..." -ForegroundColor Cyan

$dockerStatus = "Eksik (Yüklenecek)"
$composeStatus = "Eksik (Yüklenecek)"
$composeCmd = ""

# Docker kontrolü
if (Get-Command "docker" -ErrorAction SilentlyContinue) {
    $dockerVer = (docker --version).Split(' ')[2].Replace(",", "")
    $dockerStatus = "Kurulu ($dockerVer)"
    
    # Docker Daemon çalışıyor mu kontrolü
    try {
        docker ps > $null 2>&1
    } catch {
        Write-Warning "UYARI: Docker yüklü ancak Docker Desktop/Daemon çalışmıyor olabilir."
        Write-Warning "Lütfen Docker Desktop uygulamasını başlatın."
    }
}

# Docker Compose kontrolü (Modern V2 öncelikli)
$hasV2Compose = $false
try {
    docker compose version > $null 2>&1
    $hasV2Compose = $true
} catch {}

if ($hasV2Compose) {
    $composeVer = (docker compose version).Split(' ')[3]
    $composeStatus = "Kurulu (Modern V2 - $composeVer)"
    $composeCmd = "docker compose"
} elseif (Get-Command "docker-compose" -ErrorAction SilentlyContinue) {
    $composeVer = (docker-compose --version).Split(' ')[2]
    $composeStatus = "Kurulu (Eski V1 - $composeVer)"
    $composeCmd = "docker-compose"
}

Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "            Sistem Bağımlılık Teşhis Raporu         " -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "  - Docker:         $dockerStatus"
Write-Host "  - Docker Compose: $composeStatus"
Write-Host "====================================================" -ForegroundColor Yellow

$needInstall = $false
if ($dockerStatus -eq "Eksik (Yüklenecek)" -or [string]::IsNullOrEmpty($composeCmd)) {
    $needInstall = $true
}

if ($needInstall) {
    $choice = Read-Host "Eksik/uyumsuz bileşenlerin otomatik olarak kurulmasını (winget ile) onaylıyor musunuz? (Y/N)"
    if ($choice -notmatch '^[Yy]$') {
        Write-Host "Kurulum kullanıcı tarafından iptal edildi." -ForegroundColor Red
        exit 1
    }

    # winget kontrolü
    if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        Write-Error "Hata: Sisteminizde 'winget' (Windows Package Manager) bulunamadı. Lütfen Docker Desktop'ı manuel kurun: https://www.docker.com/products/docker-desktop/"
        exit 1
    }

    # Docker Desktop Kurulumu (Compose v2 ile birlikte kurulur)
    if ($dockerStatus -eq "Eksik (Yüklenecek)" -or [string]::IsNullOrEmpty($composeCmd)) {
        Write-Host "Docker Desktop winget üzerinden kuruluyor..." -ForegroundColor Yellow
        winget install --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent
        Write-Host "Docker Desktop başarıyla kuruldu. Lütfen bilgisayarınızı yeniden başlatın veya Docker Desktop uygulamasını açıp kurulum betiğini tekrar çalıştırın." -ForegroundColor Green
        exit 0
    }
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
        Write-Host "Hata: Lisans doğrulaması başarısız! Sunucu Yanıtı: $($response.message)" -ForegroundColor Red
        exit 1
    }
} catch {
    # Sunucudan dönen hata detayını yakala (404, 403 vb.)
    $msg = $_.Exception.Message
    $detail = ""
    
    if ($_.Exception.Response) {
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
            $json = ConvertFrom-Json $responseBody
            if ($json -and $json.message) {
                $detail = $json.message
            } else {
                $detail = $responseBody
            }
        } catch {}
    }
    
    if (-not [string]::IsNullOrEmpty($detail)) {
        Write-Host "X Hata: Lisans aktivasyonu başarısız!" -ForegroundColor Red
        Write-Host "Sunucu Yanıtı: $detail" -ForegroundColor Yellow
    } else {
        Write-Host "X Hata: Aktivasyon sunucusuna bağlanılamadı." -ForegroundColor Red
        Write-Host "Lütfen internet bağlantınızı veya sunucu adresini kontrol edin." -ForegroundColor Yellow
        Write-Host "Detay: $msg" -ForegroundColor Gray
    }
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
$envContent = "PORT=3000`r`nFRONTEND_URL=http://localhost:3000`r`nREDIS_HOST=redis`r`nREDIS_PORT=6379`r`nHOST_HWID=$hwid`r`nLICENSE_KEY=$licenseKey`r`nLICENSE_SERVER_URL=$licenseServerUrl"

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
if ([string]::IsNullOrEmpty($composeCmd)) {
    $hasV2Compose = $false
    try {
        docker compose version > $null 2>&1
        $hasV2Compose = $true
    } catch {}
    
    if ($hasV2Compose) {
        $composeCmd = "docker compose"
    } elseif (Get-Command "docker-compose" -ErrorAction SilentlyContinue) {
        $composeCmd = "docker-compose"
    } else {
        Write-Error "Hata: Docker Compose bulunamadı!"
        exit 1
    }
}

if ($composeCmd -eq "docker-compose") {
    docker-compose up -d --build
} else {
    docker compose up -d --build
}

Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "✓ Kurulum Başarıyla Tamamlandı!" -ForegroundColor Green
Write-Host "----------------------------------------------------" -ForegroundColor Gray
Write-Host "Yönetim Paneli: http://localhost:3000/admin" -ForegroundColor Green
Write-Host "Yayın Ekranı:   http://localhost:3000" -ForegroundColor Green
Write-Host "Lisans Sahibi:  $($response.license.owner)" -ForegroundColor Green
Write-Host "Bitiş Tarihi:   $($response.license.expiresAt)" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Yellow
