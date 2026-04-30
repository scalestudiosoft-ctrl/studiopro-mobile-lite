# Studio Pro Mobile Lite - flujo funcional esperado

## Flujo operativo correcto
1. Configurar negocio
2. Crear profesionales
3. Crear clientes
4. Crear o revisar catálogo de servicios
5. Abrir caja del día
6. Registrar citas y/o servicios
7. Cada servicio debe crear una venta ligada a:
   - cliente
   - profesional
   - servicio
   - método de pago
   - fecha/hora
8. Caja debe reflejar:
   - apertura
   - ventas del día
   - ingresos manuales
   - gastos/salidas
   - caja esperada
9. Cierre debe consolidar:
   - servicios
   - ventas
   - clientes atendidos
   - totales por método de pago
   - gastos
   - caja esperada
10. Exportar JSON y compartir por WhatsApp
11. Importar en Studio Pro Escritorio

## Fuente de verdad
- Operación: service_records
- Ventas: sales
- Caja manual: cash_movements
- Caja abierta/cerrada: cash_sessions
- Cierre exportado: daily_closings y export_history

## Ajustes aplicados en esta versión
- accesos directos a Profesionales, Clientes y Servicios desde Inicio
- menú superior con atajos globales
- páginas escuchan cambios globales y se refrescan solas
- registro de servicio notifica y refresca Inicio, Caja, Cierre e Historial
- Caja ahora muestra ventas registradas y movimientos manuales por separado
- Agenda y Servicio muestran acciones rápidas para crear faltantes
- Configuración agrega accesos rápidos a maestros y cierres

## Objetivo de la siguiente prueba
Validar que este flujo sí funcione de punta a punta:
crear profesional -> crear cliente -> abrir caja -> registrar servicio -> ver venta en caja -> revisar cierre -> exportar JSON -> compartir por WhatsApp

