import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Constants
const int WH_KEYBOARD_LL = 13;
const int WM_KEYDOWN = 0x0100;
const int WM_SYSKEYDOWN = 0x0104;
const int VK_MENU = 0x12; // Alt
const int VK_SHIFT = 0x10;
const int VK_CONTROL = 0x11; // Ctrl
const int VK_LWIN = 0x5B; // Left Win
const int VK_RWIN = 0x5C; // Right Win
const int VK_BACK = 0x08;
const int VK_SPACE = 0x20;
const int VK_RETURN = 0x0D;
const int VK_ESCAPE = 0x1B;
const int VK_UP = 0x26;
const int VK_DOWN = 0x28;

const int LLKHF_INJECTED = 0x00000010;
const int INPUT_KEYBOARD = 1;
const int KEYEVENTF_UNICODE = 0x0004;
const int KEYEVENTF_KEYUP = 0x0002;

// Structs
final class KBDLLHOOKSTRUCT extends Struct {
  @Uint32()
  external int vkCode;
  @Uint32()
  external int scanCode;
  @Uint32()
  external int flags;
  @Uint32()
  external int time;
  @IntPtr()
  external int dwExtraInfo;
}

final class KEYBDINPUT extends Struct {
  @Uint16()
  external int wVk;
  @Uint16()
  external int wScan;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int time;
  @IntPtr()
  external int dwExtraInfo;
}

// Dart FFI doesn't support nested structs/unions directly easily without manual memory layout,
// but for INPUT, we can just define a struct with the exact memory layout of INPUT for keyboard.
// INPUT is a union of (MOUSEINPUT, KEYBDINPUT, HARDWAREINPUT) + a type field.
// On 64-bit windows, INPUT struct size is 40 bytes, alignment 8.
// typedef struct tagINPUT {
//   DWORD type; (4 bytes + 4 bytes padding)
//   union { MOUSEINPUT mi; KEYBDINPUT ki; HARDWAREINPUT hi; } DUMMYUNIONNAME;
// } INPUT, *PINPUT, *LPINPUT;
// KEYBDINPUT size is 24 bytes. Total INPUT size is 40 bytes.

final class INPUT_KBD extends Struct {
  @Uint32()
  external int type;
  
  @Uint32()
  external int padding1;

  @Uint16()
  external int wVk;
  @Uint16()
  external int wScan;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int time;
  
  // Dart FFI auto-adds 4 bytes padding here because dwExtraInfo is 8-byte aligned on 64-bit
  @IntPtr()
  external int dwExtraInfo;
  
  // Padding to make total size 40 bytes (required by SendInput)
  @Uint64()
  external int padding2;
}

// User32 Functions
final DynamicLibrary user32 = DynamicLibrary.open('user32.dll');
final DynamicLibrary kernel32 = DynamicLibrary.open('kernel32.dll');

typedef SetWindowsHookExC = IntPtr Function(Int32 idHook, Pointer<NativeFunction<IntPtr Function(Int32, IntPtr, IntPtr)>> lpfn, IntPtr hMod, Uint32 dwThreadId);
typedef SetWindowsHookExDart = int Function(int idHook, Pointer<NativeFunction<IntPtr Function(Int32, IntPtr, IntPtr)>> lpfn, int hMod, int dwThreadId);
final SetWindowsHookExDart mySetWindowsHookEx = user32.lookupFunction<SetWindowsHookExC, SetWindowsHookExDart>('SetWindowsHookExW');

typedef UnhookWindowsHookExC = Int32 Function(IntPtr hhk);
typedef UnhookWindowsHookExDart = int Function(int hhk);
final UnhookWindowsHookExDart myUnhookWindowsHookEx = user32.lookupFunction<UnhookWindowsHookExC, UnhookWindowsHookExDart>('UnhookWindowsHookEx');

typedef CallNextHookExC = IntPtr Function(IntPtr hhk, Int32 nCode, IntPtr wParam, IntPtr lParam);
typedef CallNextHookExDart = int Function(int hhk, int nCode, int wParam, int lParam);
final CallNextHookExDart myCallNextHookEx = user32.lookupFunction<CallNextHookExC, CallNextHookExDart>('CallNextHookEx');

typedef GetAsyncKeyStateC = Int16 Function(Int32 vKey);
typedef GetAsyncKeyStateDart = int Function(int vKey);
final GetAsyncKeyStateDart myGetAsyncKeyState = user32.lookupFunction<GetAsyncKeyStateC, GetAsyncKeyStateDart>('GetAsyncKeyState');

typedef SendInputC = Uint32 Function(Uint32 cInputs, Pointer<INPUT_KBD> pInputs, Int32 cbSize);
typedef SendInputDart = int Function(int cInputs, Pointer<INPUT_KBD> pInputs, int cbSize);
final SendInputDart mySendInput = user32.lookupFunction<SendInputC, SendInputDart>('SendInput');

typedef GetModuleHandleC = IntPtr Function(Pointer<Utf16> lpModuleName);
typedef GetModuleHandleDart = int Function(Pointer<Utf16> lpModuleName);
final GetModuleHandleDart myGetModuleHandle = kernel32.lookupFunction<GetModuleHandleC, GetModuleHandleDart>('GetModuleHandleW');

typedef FindWindowC = IntPtr Function(Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);
typedef FindWindowDart = int Function(Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);
final FindWindowDart myFindWindow = user32.lookupFunction<FindWindowC, FindWindowDart>('FindWindowW');

typedef ShowWindowC = Int32 Function(IntPtr hWnd, Int32 nCmdShow);
typedef ShowWindowDart = int Function(int hWnd, int nCmdShow);
final ShowWindowDart myShowWindow = user32.lookupFunction<ShowWindowC, ShowWindowDart>('ShowWindow');

typedef SetWindowLongPtrC = IntPtr Function(IntPtr hWnd, Int32 nIndex, IntPtr dwNewLong);
typedef SetWindowLongPtrDart = int Function(int hWnd, int nIndex, int dwNewLong);
final SetWindowLongPtrDart mySetWindowLongPtr = user32.lookupFunction<SetWindowLongPtrC, SetWindowLongPtrDart>('SetWindowLongPtrW');

typedef GetWindowLongPtrC = IntPtr Function(IntPtr hWnd, Int32 nIndex);
typedef GetWindowLongPtrDart = int Function(int hWnd, int nIndex);
final GetWindowLongPtrDart myGetWindowLongPtr = user32.lookupFunction<GetWindowLongPtrC, GetWindowLongPtrDart>('GetWindowLongPtrW');

typedef SetWindowPosC = Int32 Function(IntPtr hWnd, IntPtr hWndInsertAfter, Int32 X, Int32 Y, Int32 cx, Int32 cy, Uint32 uFlags);
typedef SetWindowPosDart = int Function(int hWnd, int hWndInsertAfter, int X, int Y, int cx, int cy, int uFlags);
final SetWindowPosDart mySetWindowPos = user32.lookupFunction<SetWindowPosC, SetWindowPosDart>('SetWindowPos');

typedef GetClassNameC = Int32 Function(IntPtr hWnd, Pointer<Utf16> lpClassName, Int32 nMaxCount);
typedef GetClassNameDart = int Function(int hWnd, Pointer<Utf16> lpClassName, int nMaxCount);
final GetClassNameDart myGetClassName = user32.lookupFunction<GetClassNameC, GetClassNameDart>('GetClassNameW');

typedef GetShellWindowC = IntPtr Function();
typedef GetShellWindowDart = int Function();
final GetShellWindowDart myGetShellWindow = user32.lookupFunction<GetShellWindowC, GetShellWindowDart>('GetShellWindow');

typedef OpenProcessC = IntPtr Function(Uint32 dwDesiredAccess, Int32 bInheritHandle, Uint32 dwProcessId);
typedef OpenProcessDart = int Function(int dwDesiredAccess, int bInheritHandle, int dwProcessId);
final OpenProcessDart myOpenProcess = kernel32.lookupFunction<OpenProcessC, OpenProcessDart>('OpenProcess');

typedef QueryFullProcessImageNameC = Int32 Function(IntPtr hProcess, Uint32 dwFlags, Pointer<Utf16> lpExeName, Pointer<Uint32> lpdwSize);
typedef QueryFullProcessImageNameDart = int Function(int hProcess, int dwFlags, Pointer<Utf16> lpExeName, Pointer<Uint32> lpdwSize);
final QueryFullProcessImageNameDart myQueryFullProcessImageName = kernel32.lookupFunction<QueryFullProcessImageNameC, QueryFullProcessImageNameDart>('QueryFullProcessImageNameW');

typedef CloseHandleC = Int32 Function(IntPtr hObject);
typedef CloseHandleDart = int Function(int hObject);
final CloseHandleDart myCloseHandle = kernel32.lookupFunction<CloseHandleC, CloseHandleDart>('CloseHandle');

typedef BeepC = Int32 Function(Uint32 dwFreq, Uint32 dwDuration);
typedef BeepDart = int Function(int dwFreq, int dwDuration);
final BeepDart myBeep = kernel32.lookupFunction<BeepC, BeepDart>('Beep');
