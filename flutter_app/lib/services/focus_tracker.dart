import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'win32_ffi.dart';
import 'win32_caret.dart' as caret_lib;
import 'ime_controller.dart';
import 'win32_hook.dart';

// --- Windows API Constants ---
const int EVENT_SYSTEM_FOREGROUND = 0x0003;
const int EVENT_OBJECT_FOCUS = 0x8005;
const int WINEVENT_OUTOFCONTEXT = 0x0000;
const int WINEVENT_SKIPOWNPROCESS = 0x0002;

// --- Custom FFI Bindings for WinEventHook ---
typedef SetWinEventHookC = IntPtr Function(
  Uint32 eventMin,
  Uint32 eventMax,
  IntPtr hmodWinEventProc,
  Pointer<NativeFunction<Void Function(IntPtr, Uint32, IntPtr, Int32, Int32, Uint32, Uint32)>> pfnWinEventProc,
  Uint32 idProcess,
  Uint32 idThread,
  Uint32 dwFlags
);
typedef SetWinEventHookDart = int Function(
  int eventMin,
  int eventMax,
  int hmodWinEventProc,
  Pointer<NativeFunction<Void Function(IntPtr, Uint32, IntPtr, Int32, Int32, Uint32, Uint32)>> pfnWinEventProc,
  int idProcess,
  int idThread,
  int dwFlags
);

typedef UnhookWinEventC = Int32 Function(IntPtr hWinEventHook);
typedef UnhookWinEventDart = int Function(int hWinEventHook);

final user32 = DynamicLibrary.open('user32.dll');
final mySetWinEventHook = user32.lookupFunction<SetWinEventHookC, SetWinEventHookDart>('SetWinEventHook');
final myUnhookWinEvent = user32.lookupFunction<UnhookWinEventC, UnhookWinEventDart>('UnhookWinEvent');

class FocusTracker {
  static final FocusTracker _instance = FocusTracker._internal();
  factory FocusTracker() => _instance;
  FocusTracker._internal();

  int _hWinEventHook = 0;
  int _hWinEventHookFocus = 0;
  NativeCallable<Void Function(IntPtr, Uint32, IntPtr, Int32, Int32, Uint32, Uint32)>? _winEventCallback;

  void start() {
    if (_hWinEventHook != 0) return;

    // 🟢 বাগ ফিক্স: Void ফাংশনের ক্ষেত্রে exceptionalReturn দেওয়া যায় না
    _winEventCallback = NativeCallable<Void Function(IntPtr, Uint32, IntPtr, Int32, Int32, Uint32, Uint32)>.isolateLocal(
      _winEventProc
    );

    // 🟢 নেটিভ উইন্ডোজ ইভেন্ট হুক বসানো হলো
    _hWinEventHook = mySetWinEventHook(
      EVENT_SYSTEM_FOREGROUND,
      EVENT_SYSTEM_FOREGROUND,
      0,
      _winEventCallback!.nativeFunction,
      0,
      0,
      WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS
    );

    _hWinEventHookFocus = mySetWinEventHook(
      EVENT_OBJECT_FOCUS,
      EVENT_OBJECT_FOCUS,
      0,
      _winEventCallback!.nativeFunction,
      0,
      0,
      WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS
    );
  }

  void stop() {
    if (_hWinEventHook != 0) {
      myUnhookWinEvent(_hWinEventHook);
      _hWinEventHook = 0;
    }
    if (_hWinEventHookFocus != 0) {
      myUnhookWinEvent(_hWinEventHookFocus);
      _hWinEventHookFocus = 0;
    }
    if (_winEventCallback != null) {
      _winEventCallback?.close();
      _winEventCallback = null;
    }
  }

  static void _winEventProc(int hWinEventHook, int event, int hwnd, int idObject, int idChild, int idEventThread, int dwmsEventTime) {
    if (hwnd != 0) {
      if (event == EVENT_SYSTEM_FOREGROUND) {
        _updateActiveProcess(hwnd);
      }
      if (event == EVENT_SYSTEM_FOREGROUND || event == EVENT_OBJECT_FOCUS) {
        Win32Hook.hasTextFocus = Win32Hook.checkTextFocus(hwnd);
        
        // Focus পরিবর্তনের সময় (যেমন address bar → web page বা vice versa)
        // isBrowserFocused পুনরায় চেক করতে হবে, নইলে address bar block হয়ে যাবে
        final hwndFg = caret_lib.myGetForegroundWindow();
        if (hwndFg != 0) {
          Win32Hook.isBrowserFocused = Win32Hook.checkIsCompositionInWebsite(hwndFg);
        }
      }
    }
  }

  static void _updateActiveProcess(int hwnd) {
    Pointer<Uint32>? pPid;
    Pointer<Uint16>? buffer;
    Pointer<Uint32>? size;
    int hProcess = 0;

    try {
      pPid = calloc<Uint32>();
      caret_lib.myGetWindowThreadProcessId(hwnd, pPid);
      final pidVal = pPid.value;

      if (pidVal == 0) return;

      hProcess = myOpenProcess(0x1000, 0, pidVal); // PROCESS_QUERY_LIMITED_INFORMATION
      if (hProcess == 0) {
        hProcess = myOpenProcess(0x0400, 0, pidVal); // PROCESS_QUERY_INFORMATION
      }

      String processName = "";
      if (hProcess != 0) {
        buffer = calloc<Uint16>(512);
        size = calloc<Uint32>()..value = 512;
        final ok = myQueryFullProcessImageName(hProcess, 0, buffer.cast<Utf16>(), size);
        if (ok != 0) {
          final path = buffer.cast<Utf16>().toDartString();
          processName = path.split('\\').last.toLowerCase();
        }
      }

      if (processName.isNotEmpty && ImeController().currentActiveExe != processName) {
        ImeController().currentActiveExe = processName;
        Future.microtask(() => ImeController().notifyListeners());
      }
      
      Win32Hook.isBrowserFocused = Win32Hook.checkIsCompositionInWebsite(hwnd);

    } catch (_) {
    } finally {
      if (pPid != null) calloc.free(pPid);
      if (buffer != null) calloc.free(buffer);
      if (size != null) calloc.free(size);
      if (hProcess != 0) myCloseHandle(hProcess);
    }
  }
}