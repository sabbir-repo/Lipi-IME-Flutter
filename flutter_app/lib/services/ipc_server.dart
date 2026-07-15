import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class IpcServer {
  static const String pipeName = r'\\.\pipe\LipiImeIpcPipe';
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  
  Stream<String> get onMessage => _messageController.stream;
  Isolate? _isolate;
  ReceivePort? _receivePort;

  Future<void> start() async {
    if (_isolate != null) return;

    _receivePort = ReceivePort();
    _receivePort!.listen((message) {
      if (message is String) {
        _messageController.add(message);
      }
    });

    try {
      _isolate = await Isolate.spawn(_pipeServerLoop, _receivePort!.sendPort);
      print('IPC Server Isolate started');
    } catch (e) {
      print('Failed to start IPC server isolate: $e');
    }
  }

  void stop() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
  }

  // Runs in a background isolate to perform blocking Named Pipe operations
  static void _pipeServerLoop(SendPort sendPort) {
    final pipeNamePtr = pipeName.toNativeUtf16();

    while (true) {
      // 1. Create the named pipe
      final hPipe = CreateNamedPipe(
        pipeNamePtr,
        PIPE_ACCESS_DUPLEX,
        PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
        PIPE_UNLIMITED_INSTANCES,
        1024,
        1024,
        0,
        nullptr,
      );

      if (hPipe == INVALID_HANDLE_VALUE) {
        print('Failed to create named pipe.');
        // Wait a bit and try again
        sleep(const Duration(seconds: 1));
        continue;
      }

      // 2. Wait for the client (C++ TSF) to connect (BLOCKING)
      final connected = ConnectNamedPipe(hPipe, nullptr) == TRUE ? true : (GetLastError() == ERROR_PIPE_CONNECTED);

      if (connected) {
        // 3. Read messages in a loop
        final buffer = calloc<Uint8>(1024);
        final bytesRead = calloc<DWORD>();

        while (true) {
          final success = ReadFile(
            hPipe,
            buffer,
            1024 - 2, // reserve space for null terminator
            bytesRead,
            nullptr,
          );

          if (success == TRUE && bytesRead.value > 0) {
            // Process the received UTF-16LE bytes
            final count = bytesRead.value;
            // Decode manually
            final codeUnits = <int>[];
            for (int i = 0; i < count; i += 2) {
              final c = buffer[i] | (buffer[i + 1] << 8);
              if (c == 0) break;
              codeUnits.add(c);
            }
            
            final msg = String.fromCharCodes(codeUnits);
            if (msg.isNotEmpty) {
              sendPort.send(msg);
            }
          } else {
            // Client disconnected or error
            break;
          }
        }

        free(buffer);
        free(bytesRead);
      }

      // 4. Client disconnected, close the pipe handle and recreate it to accept the next connection
      DisconnectNamedPipe(hPipe);
      CloseHandle(hPipe);
    }
  }
}
