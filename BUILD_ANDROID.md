# Preparación Android

## 1. Requisitos
- Flutter estable
- Android Studio con Android SDK
- Un dispositivo Android o emulador

## 2. Preparación del proyecto
Desde la raíz del proyecto:

```bash
flutter doctor
flutter create .
flutter pub get
```

> `flutter create .` solo es necesario si todavía no existen las carpetas de plataforma como `android/`.

## 3. Pruebas rápidas
```bash
flutter analyze
flutter test
flutter run
```

## 4. Generación de APK
```bash
flutter build apk --release
```

Ruta esperada del APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 5. Scripts incluidos
- `scripts/build_android.sh`
- `scripts/build_android.bat`

## 6. Nota importante
Este paquete ya deja lista la lógica móvil y el contrato JSON `sp_mobile_sync_v1`, pero la compilación final del APK debe hacerse en un equipo con Flutter SDK y Android SDK instalados.
