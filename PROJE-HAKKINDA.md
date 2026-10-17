- Varsayılan admin / admin123 profili ile admin olarak giriş yapılabilir. Aşağıda belirtilen yoldan ilk yönetici hesabı değiştirilebilir ve panel üzerinden yeni yöneticiler oluşturulanilmektedir.
- Çalışan bilgisayarına kurmak için "Karsi-PC-Paketi-Olustur.bat" dosyasını çalıştırıp oluşan dist klasörünü zipleyip karşı bilgisayara atıp içindeki dosyayı kurmak gerekir.
- Giriş **kullanıcı adı + parola** ile yapılır (parolalar PBKDF2 ile hash'lenir).
- İlk açılışta varsayılan yönetici oluşturulur: **`admin` / `admin123`**.
- Olaylar/oturumlar Windows kullanıcı adıyla saklanır. Normal kullanıcı hesabının adı
  Windows kullanıcı adıyla eşleşir → giriş yapınca kendi verisini görür. Yönetici tümünü görür.

### Hesap yönetimi (panelden)

Yönetici, panelde **Kullanıcılar** ekranından:
- **Yeni Kullanıcı Ekle** formuyla hesap oluşturur (kullanıcı adı, görünen ad, parola, yönetici mi),
- her kullanıcı kartındaki **Sil** ile hesabı kaldırır (onay sorulur).

Güvenlik için yönetici **kendi hesabını** ve **son yönetici** hesabını silemez
(bu durumlarda Sil gizlenir / sunucu reddeder). Loglar silinmez; yalnızca giriş hesabı kalkar.

### Parola değiştirme / hesap oluşturma (Backend komutları)

Panel dışında, Backend'i komutla çalıştırarak (sunucuyu başlatmadan) da yönetebilirsiniz:

```bash
# Admin (veya herhangi bir hesabın) parolasını değiştir
ActivityTracker.Backend.exe set-password admin <yeni-parola>

# Yeni hesap oluştur (rol: admin | user, varsayılan user)
ActivityTracker.Backend.exe add-user ahmet <parola> user "Ahmet Yılmaz"
```

Not: Normal kullanıcının hesabı, **izlenen Windows kullanıcı adıyla aynı** olmalıdır
(kendi loglarını görebilmesi için).

---

## Çalıştırma

Gereksinim: .NET SDK (net46 reference assembly'leri ile) veya Visual Studio.

```bash
# 1) Derleme
dotnet build HetabilActivityTracker.sln

# 2) Backend (önce bu çalışmalı)
dotnet run --project src/ActivityTracker.Backend
#   Varsayılan adres: http://localhost:5005

# 3) Agent (arka planda, tepsiye yerleşir)
dotnet run --project src/ActivityTracker.Agent.Host

# 4) Panel (giriş ekranı açılır)
dotnet run --project src/ActivityTracker.UI
```

Panelde `admin / admin123` ile giriş yaparak yönetici görünümünü, kendi Windows
kullanıcınızla (hesap oluşturulduysa) kullanıcı görünümünü görebilirsiniz.

### Yapılandırma

| Uygulama | Dosya | Anahtarlar |
|---|---|---|
| Backend | exe yanında `backend.ini` (ops.) | `Url`, `AgentApiKey`, `DataDirectory`, `TokenHours` |
| Agent | `%AppData%\HetabilAgent\agent.ini` | `BackendUrl`, `AgentApiKey`, `IdleThresholdSeconds` |
| Panel | `%AppData%\HetabilPanel\panel.ini` | `BackendUrl` (giriş ekranı "Gelişmiş") |

Backend `Url` argüman olarak da verilebilir: `ActivityTracker.Backend.exe http://localhost:5005`.

### Ağ (birden fazla PC)

Varsayılan `http://localhost:5005` tek makinede sorunsuz çalışır (yönetici gerektirmez).
Agent'lar **başka** makinelerden bağlanacaksa Backend'i LAN'a açmak gerekir:

```powershell
# Yönetici PowerShell:
netsh http add urlacl url=http://+:5005/ user=Everyone
New-NetFirewallRule -DisplayName "Hetabil Backend" -Direction Inbound -LocalPort 5005 -Protocol TCP -Action Allow
```

Backend'i `http://+:5005` ile başlatın, agent/panel `agent.ini`/`panel.ini` içindeki
`BackendUrl`'yi sunucu IP'sine ayarlasın.

---

## Örnek Senaryo

```
09:00         → Giriş (Login)
09:00–12:00   → Aktif çalışma
12:00–12:30   → Ekran kilitli
12:30         → Tekrar aktif
18:00         → Kapanma
```

Gün sonu raporu: **Toplam 9 sa**, **Aktif 8 sa 30 dk**, **Pasif 0**, **Kilitli 30 dk**.
Bu hesaplama `WorkTimeCalculator` ile doğrulanmıştır (Backend tarafında çalışır).

---

## Veritabanı (Backend)

Konum: Backend exe yanında `data\activity.db`

| Tablo | Açıklama |
|---|---|
| `ActivityEvents` | Tekil olaylar (tip, zaman, açıklama, makine) |
| `UserSessions` | Oturum giriş/çıkış kayıtları |
| `Users` | Panel giriş hesapları (kullanıcı adı, parola hash'i, rol) |
| `AppUsage` | (Opsiyonel) uygulama kullanım süreleri |

---

