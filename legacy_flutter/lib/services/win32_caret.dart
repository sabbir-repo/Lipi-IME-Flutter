import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Structs
final class POINT extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

final class RECT extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class GUITHREADINFO extends Struct {
  @Uint32()
  external int cbSize;
  @Uint32()
  external int flags;
  @IntPtr()
  external int hwndActive;
  @IntPtr()
  external int hwndFocus;
  @IntPtr()
  external int hwndCapture;
  @IntPtr()
  external int hwndMenuOwner;
  @IntPtr()
  external int hwndMoveSize;
  @IntPtr()
  external int hwndCaret;
  external RECT rcCaret;
}

// User32 Functions
final DynamicLibrary user32 = DynamicLibrary.open('user32.dll');

typedef GetForegroundWindowC = IntPtr Function();
typedef GetForegroundWindowDart = int Function();
final GetForegroundWindowDart myGetForegroundWindow = user32.lookupFunction<GetForegroundWindowC, GetForegroundWindowDart>('GetForegroundWindow');

typedef GetWindowThreadProcessIdC = Uint32 Function(IntPtr hWnd, Pointer<Uint32> lpdwProcessId);
typedef GetWindowThreadProcessIdDart = int Function(int hWnd, Pointer<Uint32> lpdwProcessId);
final GetWindowThreadProcessIdDart myGetWindowThreadProcessId = user32.lookupFunction<GetWindowThreadProcessIdC, GetWindowThreadProcessIdDart>('GetWindowThreadProcessId');

typedef GetGUIThreadInfoC = Int32 Function(Uint32 idThread, Pointer<GUITHREADINFO> pgui);
typedef GetGUIThreadInfoDart = int Function(int idThread, Pointer<GUITHREADINFO> pgui);
final GetGUIThreadInfoDart myGetGUIThreadInfo = user32.lookupFunction<GetGUIThreadInfoC, GetGUIThreadInfoDart>('GetGUIThreadInfo');

typedef ClientToScreenC = Int32 Function(IntPtr hWnd, Pointer<POINT> lpPoint);
typedef ClientToScreenDart = int Function(int hWnd, Pointer<POINT> lpPoint);
final ClientToScreenDart myClientToScreen = user32.lookupFunction<ClientToScreenC, ClientToScreenDart>('ClientToScreen');

typedef GetCursorPosC = Int32 Function(Pointer<POINT> lpPoint);
typedef GetCursorPosDart = int Function(Pointer<POINT> lpPoint);
final GetCursorPosDart myGetCursorPos = user32.lookupFunction<GetCursorPosC, GetCursorPosDart>('GetCursorPos');

typedef GetWindowRectC = Int32 Function(IntPtr hWnd, Pointer<RECT> lpRect);
typedef GetWindowRectDart = int Function(int hWnd, Pointer<RECT> lpRect);
final GetWindowRectDart myGetWindowRect = user32.lookupFunction<GetWindowRectC, GetWindowRectDart>('GetWindowRect');

class CaretPosition {
  final int x;
  final int top;
  final int bottom;
  final bool isMouseFallback;

  CaretPosition(this.x, this.top, this.bottom, {this.isMouseFallback = false});
}

class Win32Caret {
  static CaretPosition? getCaretScreenPos() {
    Pointer<Uint32>? pPid;
    Pointer<GUITHREADINFO>? info;
    Pointer<POINT>? ptTop;
    Pointer<POINT>? ptBottom;
    Pointer<POINT>? pt;

    try {
      final hwndActive = myGetForegroundWindow();
      if (hwndActive == 0) return null;

      pPid = calloc<Uint32>();
      final threadId = myGetWindowThreadProcessId(hwndActive, pPid);
      
      info = calloc<GUITHREADINFO>();
      info.ref.cbSize = sizeOf<GUITHREADINFO>();

      if (myGetGUIThreadInfo(threadId, info) != 0) {
        final hwndCaret = info.ref.hwndCaret != 0 
            ? info.ref.hwndCaret 
            : (info.ref.hwndFocus != 0 ? info.ref.hwndFocus : hwndActive);
            
        final rect = info.ref.rcCaret;
        
        if (rect.left != 0 || rect.top != 0 || rect.bottom != 0) {
          ptTop = calloc<POINT>()..ref.x = rect.left..ref.y = rect.top;
          ptBottom = calloc<POINT>()..ref.x = rect.left..ref.y = rect.bottom;
          
          myClientToScreen(hwndCaret, ptTop);
          myClientToScreen(hwndCaret, ptBottom);
          
          return CaretPosition(ptBottom.ref.x, ptTop.ref.y, ptBottom.ref.y);
        }
      }
      
      // Fallback to mouse position
      pt = calloc<POINT>();
      if (myGetCursorPos(pt) != 0) {
        return CaretPosition(pt.ref.x, pt.ref.y, pt.ref.y + 16, isMouseFallback: true);
      }
      
      return null;
    } catch (_) {
      return null;
    } finally {
      if (pPid != null) calloc.free(pPid);
      if (info != null) calloc.free(info);
      if (ptTop != null) calloc.free(ptTop);
      if (ptBottom != null) calloc.free(ptBottom);
      if (pt != null) calloc.free(pt);
    }
  }
}
