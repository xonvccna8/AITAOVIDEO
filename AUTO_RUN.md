# Auto run

Du an da co cac script tu dong nap `.env.local`, vi vay khong can go tay
`--dart-define` khi chay Flutter.

## Chay web React/Vite

```powershell
.\RUN_WEB_NOW.ps1 -OpenBrowser
```

Hoac bam file:

```bat
RUN_WEB_NOW.bat
```

Mac dinh web chay tai:

```text
http://127.0.0.1:5173/
```

## Chay app Flutter voi API that

```powershell
.\RUN_APP_NOW.ps1
```

Hoac bam file:

```bat
RUN_APP_NOW.bat
```

Neu muon xem script da nap nhung bien nao ma khong hien gia tri key:

```powershell
.\RUN_APP_NOW.ps1 -DryRun
```

Neu can chon device cu the:

```powershell
.\RUN_APP_NOW.ps1 -DeviceId <android-device-id>
```

## Build APK

```powershell
.\BUILD_APK_NOW.ps1 -Mode debug
```

Hoac build release:

```powershell
.\BUILD_APK_NOW.ps1 -Mode release
```

Hoac bam file:

```bat
BUILD_APK_NOW.bat
```

## Cau hinh API

File `.env.local` chi nam tren may local va da duoc ignore khoi Git. Neu may khac
clone repo, tao file nay tu mau:

```powershell
Copy-Item .env.example .env.local
```

Sau do dien cac key that vao `.env.local`.
