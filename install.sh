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

# 1. Asıl Kullanıcı ve Grup Tespiti (Sahiplik ve İzin Sorunlarını Önlemek İçin)
REAL_USER=${SUDO_USER:-$(whoami)}
REAL_GROUP=$(id -gn "$REAL_USER")

# 2. Bağımlılık Kontrolü & Sürüm Teşhisi
echo "[1/5] Sistem gereksinimleri kontrol ediliyor..."
CURL_STATUS="Eksik (Kurulacak)"
UNZIP_STATUS="Eksik (Kurulacak)"
DOCKER_STATUS="Eksik (Kurulacak)"
COMPOSE_STATUS="Eksik (Kurulacak)"
COMPOSE_CMD=""

if command -v curl &> /dev/null; then
    CURL_STATUS="Kurulu ($(curl --version | head -n1 | awk '{print $2}'))"
fi

if command -v unzip &> /dev/null; then
    UNZIP_STATUS="Kurulu"
fi

if command -v docker &> /dev/null; then
    DOCKER_STATUS="Kurulu ($(docker --version | awk '{print $3}' | tr -d ','))"
fi

if docker compose version &> /dev/null; then
    COMPOSE_STATUS="Kurulu (Modern V2 - $(docker compose version | awk '{print $4}'))"
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_STATUS="Kurulu (Eski V1 - $(docker-compose --version | awk '{print $3}'))"
    COMPOSE_CMD="docker-compose"
fi

# Raporu Ekrana Yazdır
echo "===================================================="
echo "            Sistem Bağımlılık Teşhis Raporu         "
echo "===================================================="
echo "  - curl:           $CURL_STATUS"
echo "  - unzip:          $UNZIP_STATUS"
echo "  - Docker:         $DOCKER_STATUS"
echo "  - Docker Compose: $COMPOSE_STATUS"
echo "===================================================="

# Kurulum Gerekli mi?
NEED_INSTALL=0
if ! command -v curl &> /dev/null; then NEED_INSTALL=1; fi
if ! command -v unzip &> /dev/null; then NEED_INSTALL=1; fi
if ! command -v docker &> /dev/null; then NEED_INSTALL=1; fi
if [ -z "$COMPOSE_CMD" ]; then NEED_INSTALL=1; fi

SUDO_REQ=""
if [ "$EUID" -ne 0 ]; then
    if command -v sudo &> /dev/null; then
        SUDO_REQ="sudo"
    fi
fi

if [ $NEED_INSTALL -eq 1 ]; then
    if [ -t 0 ]; then
        read -p "Eksik/uyumsuz bileşenlerin otomatik kurulmasını onaylıyor musunuz? (y/N): " CONFIRM
    else
        read -p "Eksik/uyumsuz bileşenlerin otomatik kurulmasını onaylıyor musunuz? (y/N): " CONFIRM < /dev/tty
    fi
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Kurulum kullanıcı tarafından iptal edildi."
        exit 1
    fi

    # Paket yöneticisi tespiti
    PM=""
    if command -v apt &> /dev/null; then PM="apt"; elif command -v dnf &> /dev/null; then PM="dnf"; elif command -v yum &> /dev/null; then PM="yum"; fi

    # Curl Kurulumu
    if ! command -v curl &> /dev/null; then
        echo "-> 'curl' kuruluyor..."
        if [ "$PM" = "apt" ]; then
            $SUDO_REQ apt-get update && $SUDO_REQ apt-get install -y curl
        elif [ "$PM" = "dnf" ] || [ "$PM" = "yum" ]; then
            $SUDO_REQ $PM install -y curl
        else
            echo "Hata: Paket yöneticisi bulunamadı. curl yüklenemedi."
            exit 1
        fi
    fi

    # Unzip Kurulumu
    if ! command -v unzip &> /dev/null; then
        echo "-> 'unzip' kuruluyor..."
        if [ "$PM" = "apt" ]; then
            $SUDO_REQ apt-get update && $SUDO_REQ apt-get install -y unzip
        elif [ "$PM" = "dnf" ] || [ "$PM" = "yum" ]; then
            $SUDO_REQ $PM install -y unzip
        else
            echo "Hata: Paket yöneticisi bulunamadı. unzip yüklenemedi."
            exit 1
        fi
    fi

    # Docker Kurulumu
    if ! command -v docker &> /dev/null; then
        echo "-> Docker bulunamadı. Resmi Docker betiği ile kurulum başlatılıyor..."
        curl -fsSL https://get.docker.com | sh
        if command -v systemctl &> /dev/null; then
            $SUDO_REQ systemctl enable --now docker
        elif command -v service &> /dev/null; then
            $SUDO_REQ service docker start
        fi
    fi

    # Docker Compose Kurulumu
    if [ -z "$COMPOSE_CMD" ]; then
        echo "-> Modern Docker Compose V2 kuruluyor..."
        if [ "$PM" = "apt" ]; then
            $SUDO_REQ apt-get update && $SUDO_REQ apt-get install -y docker-compose-plugin
        elif [ "$PM" = "dnf" ] || [ "$PM" = "yum" ]; then
            $SUDO_REQ $PM install -y docker-compose-plugin
        else
            echo "Hata: Docker Compose otomatik kurulamadı. Lütfen manuel kurun."
            exit 1
        fi
        COMPOSE_CMD="docker compose"
    fi
fi

# Panel ve CSF Güvenlik Duvarı Kontrolleri
echo "Panel ve Özel Güvenlik Duvarı Kontrolleri yapılıyor..."
PANEL_FOUND=""
if [ -d "/usr/local/psa" ]; then PANEL_FOUND="Plesk"; fi
if [ -d "/usr/local/cpanel" ]; then PANEL_FOUND="cPanel"; fi
if [ -d "/etc/cyberpanel" ]; then PANEL_FOUND="CyberPanel"; fi

if [ -n "$PANEL_FOUND" ]; then
    echo "⚠️  UYARI: Sisteminizde '$PANEL_FOUND' kontrol paneli tespit edildi."
    echo "   Port 3000'e dış erişim için panelinizin firewall/port arayüzünü kullanmanız gerekebilir."
fi

if [ -f "/etc/csf/csf.conf" ]; then
    echo "⚠️  UYARI: CSF (ConfigServer Security & Firewall) tespit edildi."
    echo "   Port 3000'e dış erişim için /etc/csf/csf.conf dosyasına TCP_IN ve TCP_OUT listelerine 3000 ekleyip 'csf -r' komutunu çalıştırın."
fi

# Standart Firewall Kontrolleri
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo "-> UFW aktif. Port 3000 açılıyor..."
    $SUDO_REQ ufw allow 3000/tcp
elif command -v systemctl &> /dev/null && systemctl is-active --quiet firewalld &> /dev/null; then
    echo "-> Firewalld aktif. Port 3000 açılıyor..."
    $SUDO_REQ firewall-cmd --zone=public --add-port=3000/tcp --permanent
    $SUDO_REQ firewall-cmd --reload
fi

# Donanım Kimliği (HWID) Hesaplama
echo "[2/5] Benzersiz donanım kimliği (HWID) hesaplanıyor..."
HWID=""

if [ -r /sys/class/dmi/id/product_uuid ]; then
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
if [ -z "$COMPOSE_CMD" ]; then
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        echo "Hata: Docker Compose bulunamadı!"
        exit 1
    fi
fi

${SUDO_CMD}${COMPOSE_CMD} up -d --build

# Dosya izinleri ve sahipliği düzenleniyor
echo "Dosya izinleri ve sahipliği düzenleniyor ($REAL_USER:$REAL_GROUP)..."
if command -v chown &> /dev/null; then
    $SUDO_REQ chown -R "$REAL_USER:$REAL_GROUP" . || true
fi
if command -v chmod &> /dev/null; then
    $SUDO_REQ chmod -R u+rw,g+r . || true
    $SUDO_REQ chmod 755 data || true
    if [ -f data/license.json ]; then
        $SUDO_REQ chmod 644 data/license.json || true
    fi
    if [ -f .env ]; then
        $SUDO_REQ chmod 600 .env || true
    fi
fi

LICENSE_OWNER=$(echo "$RESPONSE" | grep -o -E '"owner":"[^"]+"' | cut -d'"' -f4 || echo "Bilinmiyor")
LICENSE_EXPIRES=$(echo "$RESPONSE" | grep -o -E '"expiresAt":"[^"]+"' | cut -d'"' -f4 || echo "Bilinmiyor")

echo "===================================================="
echo "✓ Kurulum Başarıyla Tamamlandı!"
echo "----------------------------------------------------"
echo "Yönetim Paneli: http://localhost:3000/admin"
echo "Yayın Ekranı:   http://localhost:3000"
echo "Lisans Sahibi:  $LICENSE_OWNER"
echo "Bitiş Tarihi:   $LICENSE_EXPIRES"
echo "===================================================="
