# Fyne Client (Desktop + Android)

This is a cross-platform Go client based on Fyne.

## What it does now

- Connects to backend API
- Health check
- Loads and displays question list

## Run

```bash
cd apps/fyne-client
go mod tidy
go run ./cmd/client
```

## Build desktop executable

Windows:
```bash
cd apps/fyne-client
go build -o ../../dist/self-study-client-windows-amd64.exe ./cmd/client
```

Linux:
```bash
cd apps/fyne-client
go build -o ../../dist/self-study-client-linux-amd64 ./cmd/client
```

## Package Android app

Requires Android SDK/NDK and fyne CLI:

```bash
go install fyne.io/tools/cmd/fyne@latest
cd apps/fyne-client
fyne package -os android -appID com.selfstudy.tool.client -name SelfStudyTool
```

Generated APK can be installed on Android devices.
