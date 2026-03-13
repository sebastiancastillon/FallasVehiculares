import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert'; // For Base64 and JSON encoding
import 'package:http/http.dart' as http; // For HTTP requests

void main() => runApp(const FleetApp());

class FleetApp extends StatelessWidget {
  const FleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const RegistroFallaScreen(),
    );
  }
}

class RegistroFallaScreen extends StatefulWidget {
  const RegistroFallaScreen({super.key});

  @override
  State<RegistroFallaScreen> createState() => _RegistroFallaScreenState();
}

class _RegistroFallaScreenState extends State<RegistroFallaScreen> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final TextEditingController _fallaController = TextEditingController();

  String placa = "---";
  String modelo = "Esperando QR...";
  String anio = "---";
  String gpsStatus = "Buscando señal GPS...";

  @override
  void initState() {
    super.initState();
    _obtenerGPS();
  }

  // ¡NUEVO! Liberar recursos para evitar memory leaks
  @override
  void dispose() {
    _signatureController.dispose();
    _fallaController.dispose();
    super.dispose();
  }

  // =====================
  // GPS
  // =====================
  Future<void> _obtenerGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return; // ¡NUEVO! Validar si el widget sigue en pantalla
      setState(() {
        gpsStatus = "GPS desactivado";
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          gpsStatus = "Permiso de GPS denegado";
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        gpsStatus = "Permisos denegados permanentemente";
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (!mounted) return;
    setState(() {
      gpsStatus = "Lat: ${position.latitude} | Long: ${position.longitude}";
    });
  }

  // =====================
  // ABRIR SCANNER
  // =====================
  Future<void> _abrirScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(),
      ),
    );

    if (!mounted) return; // ¡NUEVO! Validar antes de actualizar estado

    if (result != null && result is String) {
      List<String> datos = result.split(",");

      if (datos.length >= 3) {
        setState(() {
          placa = datos[0].trim();
          modelo = datos[1].trim();
          anio = datos[2].trim();
        });
      } else {
        // ¡NUEVO! Notificar si el QR no es válido
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Formato de QR inválido. Se espera: Placa,Modelo,Año"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

 // =====================
  // FINALIZAR REPORTE (CONEXIÓN API)
  // =====================
  Future<void> _finalizarReporte() async {
    // 1. Validaciones básicas de que no falten datos
    if (placa == "---") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor escanee el código QR del vehículo primero")),
      );
      return;
    }
    if (_fallaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor ingrese una descripción de la falla")),
      );
      return;
    }
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor capture la firma del conductor")),
      );
      return;
    }

    // Mostrar un indicador de carga mientras se envía
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Enviando reporte..."),
          ],
        ),
        duration: Duration(days: 1), // Evita que se cierre sola mientras carga
      ),
    );

    try {
      // 2. Recopilar y preparar los datos
      final bytesFirma = await _signatureController.toPngBytes();
      final firmaBase64 = base64Encode(bytesFirma!); // Convierte la imagen a texto Base64

      // Extraer latitud y longitud limpiando el texto del status
      final gpsSplit = gpsStatus.replaceAll("Lat: ", "").replaceAll("Long: ", "").split("|");
      final latitude = gpsSplit[0].trim();
      final longitude = gpsSplit[1].trim();

      // 3. Crear el Cuerpo de la Petición (Payload JSON)
      final Map<String, String> requestBody = {
        'id_vehiculo': placa,
        'fecha': DateTime.now().toIso8601String(),
        'latitud': latitude,
        'longitud': longitude,
        'descripcion_falla': _fallaController.text,
        'firma_conductor_base64': firmaBase64,
      };

      // Imprimimos el JSON en consola para que cumplas el Reto 2 de tu práctica
      print("Payload a enviar: ${jsonEncode(requestBody)}");

      // 4. Enviar la Petición POST
      final url = Uri.parse('https://backend-flotilla.vercel.app/api/reports');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      // Ocultar el indicador de carga
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // 5. Manejar la Respuesta del Servidor
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Éxito
        String mensajeExito = "Reporte enviado exitosamente.";
        try {
          // Intentamos sacar el ID que devuelve el servidor (como pide el PDF)
          final decoded = jsonDecode(response.body);
          if (decoded['id'] != null) mensajeExito += " ID: ${decoded['id']}";
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeExito), backgroundColor: Colors.green),
        );
        _limpiarFormulario(); // Reiniciamos la pantalla
      } else {
        // Error de servidor
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al enviar: ${response.statusCode} - ${response.body}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Error de red (sin internet o URL inválida)
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error de red: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // =====================
  // LIMPIAR FORMULARIO
  // =====================
  void _limpiarFormulario() {
    setState(() {
      placa = "---";
      modelo = "Esperando QR...";
      anio = "---";
      gpsStatus = "Buscando señal GPS...";
    });
    _fallaController.clear();
    _signatureController.clear();
    _obtenerGPS(); // Volvemos a buscar la ubicación para el siguiente reporte
  }

  // =====================
  // UI
  // =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Registro de Falla In-Situ",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Paso 1: Identificación de Unidad",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _abrirScanner,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 50, color: Colors.blue),
                    Text(
                      "Tocar para Escanear QR",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDataRow(Icons.directions_car, "Placa:", placa),
                    _buildDataRow(Icons.info_outline, "Modelo:", modelo),
                    _buildDataRow(Icons.calendar_today, "Año:", anio),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    gpsStatus,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _fallaController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Descripción técnica de la falla",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Firma del Conductor Responsable:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: _signatureController,
                height: 150,
                backgroundColor: Colors.white,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _signatureController.clear(),
                  icon: const Icon(Icons.clear),
                  label: const Text("Limpiar"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _finalizarReporte,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                "FINALIZAR Y ENVIAR REPORTE",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text(value),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////
/// PANTALLA SCANNER
////////////////////////////////////////////////////////

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool scanCompleted = false;
  final MobileScannerController controller = MobileScannerController();

  // ¡NUEVO! Liberar el controlador de la cámara al salir
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escanear QR")),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) async {
          if (scanCompleted) return;

          final Barcode barcode = capture.barcodes.first;
          final String? code = barcode.rawValue;

          if (code != null) {
            scanCompleted = true;
            await controller.stop(); // DETIENE LA CAMARA
            
            if (!mounted) return; // ¡NUEVO! Evitar error si el usuario cerró la pantalla mientras se procesaba
            Navigator.pop(context, code);
          }
        },
      ),
    );
  }
}