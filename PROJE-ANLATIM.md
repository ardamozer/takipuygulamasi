# Hetabil — Kullanıcı Aktivite Takip Sistemi
### Proje Anlatım Dokümanı

> Windows bilgisayarlarda kullanıcının **oturum, ekran kilidi, uyku, kapanma** olaylarını
> ve **klavye/mouse aktifliğine göre çalışma süresini** arka planda izleyen; verileri
> merkezî bir sunucuda toplayıp **rol bazlı** (yönetici / kullanıcı) raporlayan bir
> istemci–sunucu sistemidir.
>
> *Hetabil Yazılım staj projesi · C# / .NET Framework 4.6*

---

## 1. Problem ve Çözüm

**Problem:** Bir işletmede çalışanların bilgisayar başında gerçekten ne kadar aktif
çalıştığını, ne zaman giriş/çıkış yaptığını, molalarını (kilit/uyku) merkezî ve güvenilir
biçimde görmek.

**Çözüm:** Her bilgisayara kurulan sessiz bir **Agent** olayları toplayıp merkezî bir
**Backend**'e gönderir. Yöneticiler ve çalışanlar bir **Panel** üzerinden raporları görür —
ama herkes yalnızca yetkisi kadarını (çalışan kendi verisini, yönetici herkesinkini).

---

## 2. Mimari — Üç Bağımsız Parça

Sistem üç çalışan uygulamadan oluşur. **Agent** ve **Backend** birbirinden bağımsızdır:
Agent yalnızca veri *üretir*, Backend veriyi *saklar ve sunar*, Panel veriyi *gösterir*.

```
 ┌──────────────┐   HTTP / JSON (olaylar)    ┌──────────────────┐   HTTP / JSON (rapor)   ┌──────────────┐
 │    AGENT     │ ─────────────────────────► │     BACKEND      │ ◄────────────────────── │  WPF PANEL   │
 │ (her PC'de)  │   POST /api/ingest/*       │  Web API + rol   │   GET /api/me,/admin    │ (yönetici /  │
 │  tepsi/arka  │   başlık: X-Agent-Key      │  + SQLite (DB)   │   başlık: Bearer token  │  kullanıcı)  │
 └──────────────┘                            └──────────────────┘                         └──────────────┘
       toplar                                   saklar + hesaplar                             gösterir
```

| Parça | Türü | Görevi |
|---|---|---|
| **Agent** | Arka plan (sistem tepsisi) | Windows olaylarını yakalar, Backend'e gönderir. Backend kapalıysa **offline kuyruğa** yazar, bağlantı gelince yeniden gönderir. |
| **Backend** | Self-host Web API | Tüm agent'lardan geleni merkezî SQLite'ta toplar; kimlik/rol doğrular; raporları hesaplar. |
| **Panel** | WPF masaüstü | Backend'e bağlanıp raporları gösterir. Kullanıcı kendi, yönetici tüm verileri görür. |

---

## 3. Çözümün Katmanları (Visual Studio Projeleri)

```
HetabilActivityTracker.sln
└─ src/
   ├─ ActivityTracker.Domain        Modeller, enum'lar, API DTO'ları   (paylaşılan sözleşme)
   ├─ ActivityTracker.Data          Merkezî SQLite erişimi             (yalnız Backend)
   ├─ ActivityTracker.Services      Windows API izleyiciler + çalışma süresi hesabı
   ├─ ActivityTracker.Agent         [dll] Olay toplayıp gönderen çekirdek
   ├─ ActivityTracker.Agent.Host    [exe] Agent'ı tepside çalıştıran uygulama
   ├─ ActivityTracker.Backend       [exe] Web API + kimlik/rol + rapor
   ├─ ActivityTracker.UI            [exe] Rol bazlı WPF yönetim paneli
   └─ ActivityTracker.Launcher      [exe] Tek başlatıcı + kontrol paneli
   └─ Shared/                       İki projenin paylaştığı sabitler (görev adları)
```

Katmanlı ayrım bilinçli: **Domain** ortak sözleşme (kimseye bağımlı değil), **Data** yalnızca
Backend'in iç işi, **Services** Windows'a özgü düşük seviye izleme — böylece her parça tek bir
sorumluluğa sahip ve test edilebilir.

---

## 4. Bir Olayın Yolculuğu (uçtan uca)

Sistemi anlamanın en iyi yolu tek bir olayı takip etmek:

```
1. Kullanıcı bilgisayarı kilitler.
2. Services/SessionMonitor  →  Windows'tan "SessionLock" olayını yakalar.
3. Agent çekirdeği          →  olayı bir ActivityEvent'e çevirir.
4. BackendClient            →  POST /api/ingest/events  (X-Agent-Key ile kimliklenir).
        └─ Backend kapalıysa: olay yerel offline kuyruğa yazılır, sonra yeniden denenir.
5. Backend/IngestController →  doğrular ve SQLite'a (ActivityEvents) kaydeder.
6. Panel rapor isteyince    →  Backend WorkTimeCalculator ile süreleri hesaplar,
                               "kilitli 30 dk" gibi özet döner.
```

İzlenen olaylar: **giriş/çıkış**, **ekran kilidi/açılışı**, **uyku (suspend)**,
**kapanma/yeniden başlatma** ve **boşta/aktif** geçişleri (`GetLastInputInfo` ile son
giriş zamanına bakılarak).

---

## 5. Kimlik Doğrulama ve Roller

İki ayrı güvenlik mekanizması var, çünkü iki farklı istemci tipi var:

| İstemci | Yöntem | Neden |
|---|---|---|
| **Agent → Backend** | `X-Agent-Key` (paylaşılan anahtar) | Agent makinedir, kullanıcı parolası giremez; tüm agent'lar ortak anahtarla veri yazar. |
| **Panel → Backend** | Kullanıcı adı/parola → **Bearer token** | İnsan girişi; parolalar **PBKDF2** ile hash'lenir, token süreli verilir. |

- İlk açılışta varsayılan yönetici tohumlanır: **`admin / admin123`** (sunumda değiştirilir).
- Roller: **Kullanıcı** yalnızca `/api/me/*` (kendi verisi), **Yönetici** ek olarak `/api/admin/*`
  (herkesin verisi + hesap yönetimi).
- Normal kullanıcının panel hesabı, **izlenen Windows kullanıcı adıyla aynıdır** — böylece
  giriş yapınca kendi loglarını görür.

---

## 6. Dağıtım ve Otomatik Başlatma  *(öne çıkan mühendislik kısmı)*

Sistemin “gerçek dünyada kurulması” tarafı ayrı bir özen gerektirdi. Üç başlık:

### 6.1 Tek başlatıcı (Launcher) + Kontrol Paneli
Başta her işlem (Backend başlat, Agent başlat, Panel aç…) için ayrı bir `.exe`
kopyası vardı — aynı 35 KB'lik dosyanın **7 kopyası**. Bu sadeleştirildi:

- Artık tek bir **`HetabilBaslat.exe`** var; ne yapacağını **argümandan** seçer
  (`backend`, `agent`, `panel`, `all`, `sched-install`, …).
- Çift tıklayınca açılan küçük bir **Kontrol Paneli** (WinForms) tüm işlemleri tek pencerede
  butonlarla sunar ve **canlı durum** gösterir (Backend/Agent çalışıyor mu).
- Masaüstü kısayolları aynı exe'yi farklı argümanlarla çağırır.

> *Kazanım:* 7 ikili dosya → 1; kod tekrarı yok; kullanıcı argüman/komut ezberlemiyor.

### 6.2 Windows açılışında otomatik başlama — *Kayıt defteri yerine Görev Zamanlayıcı*
Agent'ın açılışta başlaması için ilk yöntem `HKCU\...\Run` kayıt defteri anahtarıydı.
Bu, **Görev Zamanlayıcı (Task Scheduler)** tabanlı bir çözümle değiştirildi. Sebep:
görev, en yüksek ayrıcalıkla (`/RL HIGHEST`) ve **yönetici sahipliğinde** kurulabilir —
böylece normal kullanıcı onu kaldıramaz. Agent tepsi menüsündeki **“Windows ile başlat”**
seçeneği:
- agent ilk açıldığında **otomatik aktif** olur,
- normal kullanıcıda **devre dışı/gri** görünür (kapatamaz),
- yalnızca **yönetici** değiştirebilir.

### 6.3 Karşı PC'ye kilitli kurulum
Bir başka bilgisayara kurulum paketi (`Kur.bat`) artık:
1. **Yönetici izni (UAC)** ister,
2. Agent'ı **`C:\Program Files\HetabilAgent`** altına kopyalar
   (Program Files izinleri gereği normal kullanıcı dosyaları **silemez**),
3. İzlenen kullanıcıya bağlı, oturum-açılışında çalışan **kilitli bir görev** oluşturur
   (admin'in kurduğu görevi normal kullanıcı **kaldıramaz**).

> **Kilit modeli özeti:** İzlenen kişi **standart (yönetici olmayan)** bir hesap kullandığı
> sürece otomatik başlatmayı kapatamaz ve dosyaları silemez. Çalışan agent'ı o oturumda
> kapatsa bile, bir sonraki açılışta görev onu tekrar başlatır. (Kişi yerel yönetici ise,
> doğası gereği her şeyi kaldırabilir — bu yüzden çalışan hesapları standart olmalıdır.)

---

## 7. Teknolojiler

| Katman | Teknoloji |
|---|---|
| Dil / Çatı | C# · **.NET Framework 4.6** |
| Backend API | **ASP.NET Web API 2** (OWIN self-host, HttpListener) |
| Panel | **WPF** (MVVM deseni) |
| Agent | Sınıf kütüphanesi (dll) + **WinForms** tepsi host'u |
| Veritabanı | **SQLite** (`System.Data.SQLite`) |
| İletişim | HTTP + JSON (Newtonsoft.Json); Bearer token + agent anahtarı |
| Sistem entegrasyonu | Windows API (`SystemEvents`, `GetLastInputInfo`), **Task Scheduler** |

---

## 8. Çalıştırma (geliştirme makinesinde)

```bash
# 1) Derle
dotnet build HetabilActivityTracker.sln

# 2) Backend (önce bu açılmalı)   → http://localhost:5005
dotnet run --project src/ActivityTracker.Backend

# 3) Agent (tepside arka planda çalışır)
dotnet run --project src/ActivityTracker.Agent.Host

# 4) Panel (giriş ekranı açılır)
dotnet run --project src/ActivityTracker.UI
```

Panelde `admin / admin123` ile yönetici görünümü; kendi Windows kullanıcınla (hesap
açıldıysa) kullanıcı görünümü görülür. **Pratik yol:** `HetabilBaslat.exe`'ye çift tıkla →
Kontrol Paneli'nden tek tıkla başlat/durdur.

### Yapılandırma

| Uygulama | Dosya | Anahtarlar |
|---|---|---|
| Backend | exe yanında `backend.ini` (ops.) | `Url`, `AgentApiKey`, `DataDirectory`, `TokenHours` |
| Agent | `%AppData%\HetabilAgent\agent.ini` | `BackendUrl`, `AgentApiKey`, `IdleThresholdSeconds` |
| Panel | `%AppData%\HetabilPanel\panel.ini` | `BackendUrl` |

---

## 9. Veritabanı (Backend, SQLite)

Konum: Backend exe yanında `data\activity.db`

| Tablo | İçerik |
|---|---|
| `ActivityEvents` | Tekil olaylar (tip, zaman, açıklama, makine) |
| `UserSessions` | Oturum giriş/çıkış kayıtları |
| `Users` | Panel giriş hesapları (kullanıcı adı, parola hash'i, rol) |
| `AppUsage` | (Opsiyonel) uygulama kullanım süreleri — 2. faz |

---

## 10. Öne Çıkan Tasarım Kararları (neden böyle yaptık?)

| Karar | Gerekçe |
|---|---|
| Agent ile Backend'i ayırmak | Agent'ın çökmesi/kapanması sunucuyu, sunucunun kapanması veri toplamayı etkilemesin (offline kuyruk). |
| İki ayrı kimlik (agent anahtarı + kullanıcı token'ı) | Makine ile insan farklı şeylerdir; biri parola giremez, diğeri süreli yetki ister. |
| Kayıt defteri yerine Görev Zamanlayıcı | Yöneticinin kurduğu görevi normal kullanıcı kaldıramaz → otomatik başlatma kilitlenebilir. |
| 7 exe → tek exe + argüman | Aynı ikilinin kopyalarını taşımak yerine tek kaynak; bakım ve dağıtım kolaylığı. |
| Program Files'a kurulum | NTFS izinleri sayesinde dosyaların standart kullanıcı tarafından silinmesini engeller. |
| Ortak sabitler `Shared/` | Görev adı gibi değerler iki projede ayrı yazılmasın (tek kaynak, çelişki riski yok). |

---

## 11. Proje Durumu

**Tamamlanan:** giriş/çıkış kaydı, kilit/uyku/kapanma tespiti, aktif/pasif takibi, günlük
çalışma süresi hesabı, merkezî SQLite, arka planda çalışma, rol bazlı raporlama, offline
dayanıklılık, tek-exe başlatıcı + kontrol paneli, Görev Zamanlayıcı ile kilitli otomatik
başlatma, karşı-PC kilitli kurulum paketi.

**Yol haritası (opsiyonel):** açık uygulama sürelerinin takibi (`AppUsage`), Backend'in
Windows Service olarak paketlenmesi, PDF/Excel rapor dışa aktarımı.

---

*Bu doküman sistemin genel mimarisini ve kurulum/güvenlik kararlarını özetler.
Teknik ayrıntı ve API uçları için depo kökündeki `README.md` dosyasına bakılabilir.*
