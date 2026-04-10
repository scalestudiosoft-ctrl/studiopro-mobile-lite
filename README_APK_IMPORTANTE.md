Este paquete contiene el codigo fuente Flutter y ahora incluye:
- android/.gitkeep
- assets/.gitkeep
- codemagic.yaml

Importante:
- La carpeta android no trae una plataforma Android completa generada.
- Codemagic puede regenerarla automaticamente porque el archivo codemagic.yaml ejecuta:
  flutter create . --platforms=android
- Luego compila una APK debug para descarga.
