#!/bin/bash

# oaYoutubeLive Tek Satır Kurulum Betiği (Host Installer)
# Kullanım: curl -fsSL https://licensing.ornek.com/install.sh | sh

set -e

# Yapılandırma
LICENSE_SERVER_URL="https://ytlive-licensing.oasrvcom.workers.dev"
DOWNLOAD_URL="https://github.com/oaonuraksoy/oaYoutubeLive/releases/latest/download/ytlive-dist.zip" # Github releases en son surum indirme linki

echo "===================================================="
echo "      oaYoutubeLive Canlı Yayın Bilgi Yarışması Kurulumu    "
echo "===================================================="

# Bağımlılık Kontrolleri
echo "[1/5] Sistem gereksinimleri kontrol ediliyor..."

if ! command -v docker &> /dev/null; then
    echo "Hata: Docker kurulu değil. Lütfen önce Docker yükleyin."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Hata: Docker Compose kurulu değil. Lütfen önce Docker Compose yükleyin."
    exit 1
fi

if ! command -v unzip &> /dev/null; then
    echo "Hata: 'unzip' aracı sistemde bulunamadı. Lütfen yükleyin: sudo apt install unzip"
    exit 1
fi

# Donanım Kimliği (HWID) Hesaplama
echo "[2/5] Benzersiz donanım kimliği (HWID) hesaplanıyor..."
HWID=""

if [ -f /sys/class/dmi/id/product_uuid ]; then
    HWID=$(cat /sys/class/dmi/id/product_uuid | tr -d ' \t\r\n')
elif command -v dmidecode &> /dev/null; then
    HWID=$(dmidecode -s system-uuid 2>/dev/null | tr -d ' \t\r\n')
fi

# Fallback: Eğer UUID alınamadıysa MAC adreslerini SHA256 ile özetle
if [ -z "$HWID" ] || [ "$HWID" = "00000000-0000-0000-0000-000000000000" ] || [ "$HWID" = "Not Specified" ]; then
    MAC_LIST=$(ip link | grep -o -E 'link/ether [0-9a-f:]{17}' | awk '{print $2}' | sort | tr -d '\n')
    if [ -n "$MAC_LIST" ]; then
        HWID=$(echo -n "$MAC_LIST" | sha256sum | awk '{print $1}')
    else
        HWID=$(hostname | sha256sum | awk '{print $1}')
    fi
else
    # UUID'yi güvenli bir şekilde hash'le
    HWID=$(echo -n "$HWID" | sha256sum | awk '{print $1}')
fi

HWID=$(echo "$HWID" | tr -d ' \t\r\n')
echo "Donanım Kimliğiniz (HWID): $HWID"

# Lisans Girişi & Aktivasyon
echo "[3/5] Lisans aktivasyonu başlatılıyor..."
if [ -t 0 ]; then
    read -p "Lütfen Lisans Anahtarınızı Girin: " LICENSE_KEY
else
    read -p "Lütfen Lisans Anahtarınızı Girin: " LICENSE_KEY < /dev/tty
fi

if [ -z "$LICENSE_KEY" ]; then
    echo "Hata: Lisans anahtarı boş bırakılamaz."
    exit 1
fi

# Cloudflare Worker'a istek gönder
echo "Aktivasyon sunucusu ile el sıkışılıyor..."
set +e
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"licenseKey\":\"$LICENSE_KEY\", \"hwid\":\"$HWID\"}" \
  "$LICENSE_SERVER_URL/api/activate")
CURL_STATUS=$?
set -e

if [ $CURL_STATUS -ne 0 ] || [ -z "$RESPONSE" ]; then
    echo "X Hata: Aktivasyon sunucusuna bağlanılamadı."
    echo "Lütfen internet bağlantınızı veya sunucu adresini kontrol edin."
    exit 1
fi

if echo "$RESPONSE" | grep -q '"success":[[:space:]]*true'; then
    echo "✓ Lisans başarıyla doğrulandı ve bu cihaza kilitlendi!"
else
    ERROR_MSG=$(echo "$RESPONSE" | grep -o -E '"message":"[^"]+"' | cut -d'"' -f4 || echo "Bilinmeyen sunucu hatası.")
    echo "X Hata: Lisans doğrulaması başarısız!"
    echo "Sunucu Yanıtı: $ERROR_MSG"
    exit 1
fi

# Klasör ve Lisans Dosyalarının Hazırlanması
echo "[4/5] Kurulum dizinleri ve lisans anahtarı kaydediliyor..."
mkdir -p data

# Lisans sunucusu yanıtındaki 'license' alt objesini kaydediyoruz
# Python veya sed/grep kullanarak lisans JSON'ını çekip kaydedelim
SIGNED_LICENSE=$(echo "$RESPONSE" | grep -o -E '"license":\{[^}]+\}' | sed 's/"license"://' || echo "")

if [ -z "$SIGNED_LICENSE" ]; then
    # Alternatif json ayrıştırma (basit regex)
    SIGNED_LICENSE=$(echo "$RESPONSE" | sed -n 's/.*"license":\({[^}]*}\).*/\1/p')
fi

echo "$SIGNED_LICENSE" > data/license.json

# .env dosyasını oluştur
cat <<EOT > .env
PORT=3000
FRONTEND_URL=http://localhost:3000
REDIS_HOST=redis
REDIS_PORT=6379
HOST_HWID=$HWID
LICENSE_KEY=$LICENSE_KEY
LICENSE_SERVER_URL=$LICENSE_SERVER_URL
EOT

# Proje Paketinin İndirilmesi
echo "[5/5] Uygulama dosyaları indiriliyor ve başlatılıyor..."

if [ "$DOWNLOAD_URL" = "YOUR_ZIP_DOWNLOAD_URL_HERE" ]; then
    echo "Bilgilendirme: Proje dosyaları yerel kaynaklardan derlenerek başlatılıyor."
    echo "(Üretim ortamında download URL üzerinden güncel sürüm indirilecektir.)"
else
    echo "Güncel derlenmiş sürüm indiriliyor..."
    curl -L -o project.zip "$DOWNLOAD_URL"
    unzip -q -o project.zip -d ./ || true
    rm project.zip
fi

# Docker yetki kontrolü (gerekirse sudo ekle)
SUDO_CMD=""
if ! docker ps &> /dev/null; then
    if command -v sudo &> /dev/null; then
        SUDO_CMD="sudo "
    fi
fi

# Docker konteynerlerini başlat
echo "Docker servisleri başlatılıyor..."
if command -v docker-compose &> /dev/null; then
    ${SUDO_CMD}docker-compose up -d --build
else
    ${SUDO_CMD}docker compose up -d --build
fi

echo "===================================================="
echo "✓ Kurulum Başarıyla Tamamlandı!"
echo "----------------------------------------------------"
echo "Yönetim Paneli: http://localhost:3000/admin"
echo "Yayın Ekranı:   http://localhost:3000"
echo "Lisans Sahibi:  \$(echo '$RESPONSE' | grep -o -E '\"owner\":\"[^\"]+\"' | cut -d'\"' -f4)"
echo "Bitiş Tarihi:   \$(echo '$RESPONSE' | grep -o -E '\"expiresAt\":\"[^\"]+\"' | cut -d'\"' -f4)"
echo "===================================================="
