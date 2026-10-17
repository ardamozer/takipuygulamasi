@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Hetabil - Karsi PC Kurulum Paketi Olustur

rem ============================================================
rem  Bu script SENIN bilgisayarinda calisir.
rem  Karsi tarafa gonderilecek "Agent + Panel" paketini olusturur.
rem  (Backend bu pakete DAHIL EDILMEZ - backend sende kalir.)
rem ============================================================

set "AGENT_BIN=src\ActivityTracker.Agent.Host\bin\Debug\net46"
set "PANEL_BIN=src\ActivityTracker.UI\bin\Debug\net46"
set "IKON=src\ActivityTracker.UI\Assets\hetabil.ico"
set "PAKET=dist\HetabilAgent-Kurulum"

echo Derleniyor...
dotnet build HetabilActivityTracker.sln -v quiet
if errorlevel 1 ( echo Derleme hatasi! & pause & exit /b 1 )

echo Eski paket temizleniyor...
if exist "%PAKET%" rmdir /s /q "%PAKET%"
mkdir "%PAKET%\Agent"
mkdir "%PAKET%\Panel"

echo Agent dosyalari kopyalaniyor...
xcopy "%AGENT_BIN%\*" "%PAKET%\Agent\" /e /i /y /q >nul
echo Panel dosyalari kopyalaniyor...
xcopy "%PANEL_BIN%\*" "%PAKET%\Panel\" /e /i /y /q >nul

echo Ikon ve kurulum scripti kopyalaniyor...
copy /y "%IKON%" "%PAKET%\hetabil.ico" >nul
copy /y "Paket-Kaynaklari\Kur.bat" "%PAKET%\Kur.bat" >nul
copy /y "Paket-Kaynaklari\Kur-Kilit.ps1" "%PAKET%\Kur-Kilit.ps1" >nul
copy /y "Paket-Kaynaklari\OKU-BENI.txt" "%PAKET%\OKU-BENI.txt" >nul

echo.
echo ============================================================
echo  Paket hazir: %PAKET%
echo  Bu klasoru ziplenip karsi tarafa gonderilebilir.
echo  Karsi taraf icindeki "Kur.bat" dosyasina cift tiklar.
echo ============================================================
pause
