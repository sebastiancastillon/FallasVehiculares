# 🛠️ Sistema de Reporte de Fallas Vehiculares
Aplicación móvil diseñada para la gestión técnica de flotas y talleres. Permite digitalizar el levantamiento de reportes de fallas mediante el escaneo de computadoras vehiculares, geolocalización automática y firma digital.

Los reportes son enviados en tiempo real a un Panel de Administración alojado en Vercel, donde se visualizan detalladamente sobre un mapa interactivo.

🚀 Características Principales
🔍 Escaneo QR de Diagnóstico: Obtención inmediata de datos del vehículo (Placa, Modelo, Año) al escanear el código de la computadora del carro.

📝 Registro Técnico: Espacio dedicado para la descripción detallada de la falla detectada.

📍 Geolocalización Automática: Captura mediante GPS de la ubicación exacta donde se genera el reporte.

✍️ Firma Digital: Validación del reporte mediante la firma del conductor responsable directamente en la pantalla.

📊 Panel Administrativo (Vercel): Centralización de datos para el administrador con visualización de mapas y estatus de los reportes.

🧠 Flujo de Trabajo
El proceso de reporte consta de 4 pasos clave:

Sincronización: El usuario escanea el código QR del vehículo. La app procesa la información y autorrellena los campos de identificación.

Diagnóstico: El técnico o conductor ingresa la descripción de la falla mecánica o eléctrica.

Validación: El sistema obtiene las coordenadas GPS actuales y solicita la firma autógrafa del responsable.

Envío: El reporte se empaqueta y se envía a la base de datos vinculada al Dashboard.

🛠️ Tecnologías Utilizadas
Mobile App: Flutter / Dart (o la tecnología que estés usando).

Geolocalización: Google Maps API / Geolocator.

Backend/Hosting: Vercel (Panel Administrativo).

Base de Datos: [Insertar base de datos, ej: Firebase / Supabase].
