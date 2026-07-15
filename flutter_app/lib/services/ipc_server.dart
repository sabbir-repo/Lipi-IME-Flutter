import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

// Windows API Constants
const int PIPE_ACCESS_DUPLEX = 0x00000003;
const int PIPE_TYPE_MESSAGE = 0x00000004;
const int PIPE_READMODE_MESSAGE = 0x00000002;
const int PIPE_WAIT = 0x00000000;
const int PIPE_UNLIMITED_INSTANCES = 255;
const int INVALID_HANDLE_VALUE = -1;
const int ERROR_PIPE_CONNECTED = 535;

// FFI Signatures
typedef CreateNamedPipeC = IntPtr Function(Pointer<Utf16>, Uint32, Uint32, Uint32, Uint32, Uint32, Uint32, Pointer<Void>);
typedef CreateNamedPipeDart = int Function(Pointer<Utf16>, int, int, int, int, int, int, Pointer<Void>);

typedef ConnectNamedPipeC = Int32 Function(IntPtr, Pointer<Void>);
typedef ConnectNamedPipeDart = int Function(int, Pointer<Void>);

typedef ReadFileC = Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>, Pointer<Void>);
typedef ReadFileDart = int Function(int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Void>);

typedef DisconnectNamedPipeC = Int32 Function(IntPtr);
typedef DisconnectNamedPipeDart = int Function(int);

typedef CloseHandleC = Int32 Function(IntPtr);
typedef CloseHandleDart = int Function(int);

typedef GetLastErrorC = Uint32 Function();
typedef GetLastErrorDart = int Function();

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
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final createNamedPipe = kernel32.lookupFunction<CreateNamedPipeC, CreateNamedPipeDart>('CreateNamedPipeW');
    final connectNamedPipe = kernel32.lookupFunction<ConnectNamedPipeC, ConnectNamedPipeDart>('ConnectNamedPipe');
    final readPipeFile = kernel32.lookupFunction<ReadFileC, ReadFileDart>('ReadFile');
    final disconnectNamedPipe = kernel32.lookupFunction<DisconnectNamedPipeC, DisconnectNamedPipeDart>('DisconnectNamedPipe');
    final closeHandle = kernel32.lookupFunction<CloseHandleC, CloseHandleDart>('CloseHandle');
    final getLastError = kernel32.lookupFunction<GetLastErrorC, GetLastErrorDart>('GetLastError');

    final pipeNamePtr = pipeName.toNativeUtf16();

    while (true) {
      // 1. Create the named pipe
      final hPipe = createNamedPipe(
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
      final connected = connectNamedPipe(hPipe, nullptr) != 0 ? true : (getLastError() == ERROR_PIPE_CONNECTED);

      if (connected) {
        // 3. Read messages in a loop
        final buffer = calloc<Uint8>(1024);
        final bytesRead = calloc<Uint32>();

        while (true) {
          final success = readPipeFile(
            hPipe,
            buffer,
            1024 - 2, // reserve space for null terminator
            bytesRead,
            nullptr,
          );

          if (success != 0 && bytesRead.value > 0) {
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
      disconnectNamedPipe(hPipe);
      closeHandle(hPipe);
    }
  }
}
