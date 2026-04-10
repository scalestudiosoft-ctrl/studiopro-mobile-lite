@echo off
setlocal

echo [1/5] Verificando Flutter
call flutter --version || goto :error

echo [2/5] Descargando dependencias
call flutter pub get || goto :error

echo [3/5] Analizando proyecto
call flutter analyze || goto :error

echo [4/5] Ejecutando prueba rapida
call flutter test || goto :error

echo [5/5] Generando APK release
call flutter build apk --release || goto :error

echo APK generado en build\app\outputs\flutter-apk\
goto :eof

:error
echo Error en el proceso de build Android.
exit /b 1
