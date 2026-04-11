# Studio Pro 2.0.0

Versión candidata estable de la app móvil offline de Studio Pro.

## Incluye
- Base Flutter fuente
- Navegación, SQLite local y módulos operativos ya montados
- Validaciones para operación diaria y cierre
- Exportación JSON compatible con el escritorio
- Scripts de apoyo para compilar APK en tu entorno
- Checklist de release Android

## Importante
- Este paquete trae **código fuente**, no APK compilado
- Para generar el APK necesitas Flutter SDK y Android SDK instalados en tu equipo
- Si al abrirlo faltan las carpetas de plataforma, ejecuta `flutter create .` en la raíz del proyecto

## Ruta recomendada
1. Instalar Flutter y Android Studio
2. Abrir la carpeta del proyecto
3. Ejecutar `flutter pub get`
4. Probar con `flutter run`
5. Generar APK con `flutter build apk --release`
