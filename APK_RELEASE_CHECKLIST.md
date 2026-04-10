# Checklist de salida APK

## Antes de compilar
- Tener Flutter SDK instalado y visible en PATH
- Tener Android SDK instalado desde Android Studio
- Ejecutar `flutter doctor` y corregir pendientes
- Confirmar `business_id`, nombre del negocio y ciudad en la app
- Crear al menos un profesional, un cliente y un servicio de prueba

## Validaciones mínimas
- Registro de servicio con caja abierta
- Movimiento de caja y cierre del día
- Exportación JSON del cierre
- Compartir archivo por Android
- Reimportar el JSON en Studio Pro escritorio

## Comando de release
- Linux / macOS: `sh scripts/build_android.sh`
- Windows: `scripts\\build_android.bat`

## Salida esperada
- `build/app/outputs/flutter-apk/app-release.apk`
