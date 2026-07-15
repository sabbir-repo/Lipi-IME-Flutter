import 'dart:async';
import 'dart:convert';
import 'dart:io';

class IpcServer {
  static const String pipeName = r'\\.\pipe\LipiImeIpcPipe';
  ServerSocket? _server;
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  
  Stream<String> get onMessage => _messageController.stream;

  Future<void> start() async {
    if (_server != null) return;

    try {
      // In Dart, Windows named pipes are supported via InternetAddress with type unix,
      // but only on very recent Dart versions (Dart 2.17+ with experimental flags).
      // Wait, standard dart:io ServerSocket might not support Named Pipes on Windows directly.
      // Actually, Dart 2.17+ supports Named Pipes on Windows using InternetAddress(pipeName, type: InternetAddressType.unix).
      
      final address = InternetAddress(pipeName, type: InternetAddressType.unix);
      _server = await ServerSocket.bind(address, 0);
      print('IPC Server listening on $pipeName');

      _server!.listen((Socket client) {
        print('Client connected to IPC');
        
        client.listen(
          (List<int> data) {
            // Data is received as UTF-16LE bytes (wchar_t string) from C++
            // We need to decode it.
            // But Dart doesn't have a built-in UTF-16LE decoder in 'dart:convert' standard.
            // Let's assume we change C++ to send UTF-8, or we decode UTF-16 manually.
            // For now, let's treat it as UTF-16LE.
            final msg = _decodeUtf16LE(data);
            if (msg.isNotEmpty) {
              _messageController.add(msg);
            }
          },
          onError: (error) {
            print('Client error: $error');
          },
          onDone: () {
            print('Client disconnected');
          },
        );
      });
    } catch (e) {
      print('Failed to start IPC server: $e');
    }
  }

  void stop() {
    _server?.close();
    _server = null;
  }

  String _decodeUtf16LE(List<int> bytes) {
    if (bytes.length % 2 != 0) return '';
    final codeUnits = <int>[];
    for (int i = 0; i < bytes.length; i += 2) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);
      if (codeUnit == 0) break; // null terminator
      codeUnits.add(codeUnit);
    }
    return String.fromCharCodes(codeUnits);
  }
}
