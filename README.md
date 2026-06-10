# oaYoutubeLive - Canlı Yayın İnteraktif Bilgi Yarışması Yönetim Sistemi

[![License](https://img.shields.io/badge/license-V8_Bytecode_Encrypted-blueviolet.svg)](#)
[![Docker](https://img.shields.io/badge/Docker-Enabled-blue.svg)](#)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows%20VDS-orange.svg)](#)
[![Licensing](https://img.shields.io/badge/Licensing-HWID_%26_IP_Collision-red.svg)](#)

**oaYoutubeLive**, YouTube Live (Canlı Yayın) platformunda dikey formatta interaktif bilgi yarışması akışları düzenlemenizi sağlayan, chat tabanlı puanlama ve yönetim paneline sahip profesyonel bir yayın otomasyon yazılımıdır. 

R10 gibi pazar yerlerinde satış yapmaya uygun, warez ve izinsiz kopyalamaya karşı tam donanımlı kriptografik lisanslama motoruyla güçlendirilmiştir.

---

## ⚡ Temel Özellikler

- **V8 Bytecode Şifreleme**: Tüm backend mantığı Node V8 motorunun anlayacağı bytecode (`.jsc`) formatında derlenmiştir. Tersine mühendislik ile kodun açılması/kırılması imkansızdır.
- **Donanım Kimliği (HWID) Kilidi**: IP adresi değişken olan VDS veya ev interneti ortamlarında sorunsuz çalışan, host cihazın anakart UUID ve MAC adresini temel alan otomatik HWID kilitlemesi.
- **IP Çakışma Koruması (Collision Detection)**: Lisans dosyası ve yapılandırmanın başka bir sunucuya kopyalanıp çalıştırılması durumunda, lisans sunucusu eşzamanlı IP ping çakışmalarını yakalar ve lisansı anında bloke eder.
- **Tek Satır Komutla Kurulum**: Linux ve Windows sunucularda tüm Docker, paket indirme, lisans doğrulama ve başlatma işlemlerini otomatize eden kurulum betikleri.
- **YouTube Canlı Chat Scraper**: Gecikmesiz, anlık oy toplama ve superchat etkileşim sistemleri.
- **Gelişmiş Yönetim Paneli**: Ses seviyesi ayarları, soru ekleme/düzenleme/silme, anlık duyuru bandı yönetimi ve çalma listesi (playlist) kontrolü.

---

## 🚀 Hızlı Kurulum Betikleri (Tek Satır Kurulum)

Sistemi VDS veya yerel bilgisayarınızda kurmak için Docker'ın kurulu olduğundan emin olun ve aşağıdaki komutlardan işletim sisteminize uygun olanı çalıştırın.

### 🐧 Linux Sunucular (VDS) İçin:
```bash
curl -fsSL https://oaonuraksoy.github.io/oaYoutubeLive/install.sh | bash
```

### 🪟 Windows VDS / Bilgisayar İçin:
Terminali Yönetici olarak başlatın ve aşağıdaki komutu girin:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ([System.Text.Encoding]::UTF8.GetString((iwr 'https://oaonuraksoy.github.io/oaYoutubeLive/install.ps1' -UseBasicParsing).Content))
```

*Komut çalıştırıldıktan sonra sizden lisans anahtarınızı isteyecek, donanım kimliğinizi sunucu ile eşleştirecek ve Docker container'larını otomatik olarak ayağa kaldıracaktır.*

---

## 🔑 Lisans Sunucusu Entegrasyonu (Cloudflare Workers + D1)

Lisans kontrollerinin ve veri tabanının ölçeklenebilir, DDoS korumalı ve maliyetsiz çalışabilmesi için altyapı **Cloudflare Workers** ve **D1 SQLite** üzerine tasarlanmıştır.

Lisans sunucunuzu deploy etmek, yeni lisans kodları üretmek veya API şemalarını incelemek için lütfen projenizdeki `licensing-server` dizinine ve **[licensing_guide.md](licensing_guide.md)** belgesine göz atın.

---

## 📜 Lisans & Telif

Bu yazılım V8 bytecode derlemesiyle korunmaktadır. Yazılımın izinsiz çoğaltılması, kopyalanması veya satılması durumunda donanım kilidi ve IP çakışma algoritmaları devreye girerek lisansı otomatik askıya alacaktır. 

Destek talepleri veya lisans alımları için **dev@onuraksoy.com.tr** veya R10 PM üzerinden iletişime geçebilirsiniz.
