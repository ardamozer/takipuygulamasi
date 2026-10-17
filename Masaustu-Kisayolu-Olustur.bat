@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Hetabil - Masaustu Kisayollari Olustur

rem Bu dosyaya cift tiklayin: masaustune Hetabil kisayollarini olusturur.
rem Kisayollar tek "HetabilBaslat.exe" launcher'ini farkli argumanlarla calistirir.

echo Baslatici derleniyor (HetabilBaslat.exe olusturuluyor)...
dotnet build HetabilActivityTracker.sln -v quiet
if errorlevel 1 ( echo Derleme hatasi! & pause & exit /b 1 )

echo Masaustu kisayollari olusturuluyor...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ws = New-Object -ComObject WScript.Shell;" ^
  "$dir = '%~dp0';" ^
  "$exe = (Join-Path $dir 'HetabilBaslat.exe');" ^
  "$desk = [Environment]::GetFolderPath('Desktop');" ^
  "function Kisayol($ad, $arg, $aciklama) {" ^
  "  $s = $ws.CreateShortcut((Join-Path $desk $ad));" ^
  "  $s.TargetPath = $exe;" ^
  "  $s.Arguments = $arg;" ^
  "  $s.WorkingDirectory = $dir;" ^
  "  $s.IconLocation = $exe;" ^
  "  $s.Description = $aciklama;" ^
  "  $s.Save();" ^
  "}" ^
  "Kisayol 'Hetabil Baslatici.lnk'       ''              'Hetabil Aktivite Takip - Kontrol paneli (tum islemler)';" ^
  "Kisayol 'Hetabil Backend.lnk'         'backend'       'Hetabil Aktivite Takip - Backend baslat ve aga ac';" ^
  "Kisayol 'Hetabil Backend Durdur.lnk'  'durdur'        'Hetabil Aktivite Takip - Backend durdur ve agi kapat';" ^
  "Kisayol 'Hetabil Agent.lnk'           'agent'         'Hetabil Aktivite Takip - Agent';" ^
  "Kisayol 'Hetabil Panel.lnk'           'panel'         'Hetabil Aktivite Takip - Panel';" ^
  "Kisayol 'Hetabil Hepsini Baslat.lnk'  'all'           'Hetabil Aktivite Takip - Backend + Agent + Panel';" ^
  "Kisayol 'Hetabil Otomatik Kur.lnk'    'sched-install' 'Hetabil Aktivite Takip - Oturum acilista otomatik baslat (kur)';" ^
  "Kisayol 'Hetabil Otomatik Kaldir.lnk' 'sched-remove'  'Hetabil Aktivite Takip - Otomatik baslatmayi kaldir'"

if errorlevel 1 (
    echo HATA: Kisayollar olusturulamadi.
    pause
    exit /b 1
)

echo.
echo Tamam! Masaustunde su kisayollar olustu:
echo   - Hetabil Baslatici        (kontrol paneli: tum islemler tek pencerede)
echo   - Hetabil Backend          (backend'i baslatir + aga acar; yonetici sorar)
echo   - Hetabil Backend Durdur   (backend'i durdurur + agi kapatir; yonetici sorar)
echo   - Hetabil Agent            (agent'i sistem tepsisinde baslatir)
echo   - Hetabil Panel            (yonetim panelini acar: admin / admin123)
echo   - Hetabil Hepsini Baslat   (backend + agent + panel sirayla)
echo   - Hetabil Otomatik Kur     (oturum acilista otomatik baslatmayi kurar)
echo   - Hetabil Otomatik Kaldir  (otomatik baslatmayi kaldirir)
pause
