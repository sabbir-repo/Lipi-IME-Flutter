import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'win32_ffi.dart';
import 'win32_caret.dart' as caret_lib;
import 'ime_controller.dart';
import 'preference_manager.dart';
import '../api/api_service.dart';

class Win32Hook {
  static final Win32Hook _instance = Win32Hook._internal();
  factory Win32Hook() => _instance;
  Win32Hook._internal();

  int _hHook = 0;
  NativeCallable<IntPtr Function(Int32, IntPtr, IntPtr)>? _callback;

  static int _lastActiveHwnd = 0;
  
  // 🟢 ব্যাকগ্রাউন্ড থ্রেড থেকে ব্রাউজার ফোকাস আপডেট করার জন্য এই ভেরিয়েবলটি ব্যবহার করা হবে
  static bool isBrowserFocused = false; 
  
  String _lastOriginalChar = "";
  String _lastInjectedChar = "";
  int _lastInjectTime = 0;



  void _cleanupPreviousHook() {
    try {
      final dir = Directory('${Platform.environment['USERPROFILE']}\\.lipi_ime');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('${dir.path}\\hook_handle.txt');
      if (file.existsSync()) {
        final content = file.readAsStringSync().trim();
        final prevHandle = int.tryParse(content) ?? 0;
        if (prevHandle != 0) {
          myUnhookWindowsHookEx(prevHandle);
          print("Successfully unhooked legacy hook handle from previous run: $prevHandle");
        }
      }
    } catch (e) {
      print("Failed to clean up legacy hook: $e");
    }
  }

  void _saveHookHandle(int handle) {
    try {
      final dir = Directory('${Platform.environment['USERPROFILE']}\\.lipi_ime');
      final file = File('${dir.path}\\hook_handle.txt');
      file.writeAsStringSync(handle.toString());
    } catch (_) {}
  }

  void startHook() {
    if (_hHook != 0) return;

    _cleanupPreviousHook();
    
    // Create native callable for the hook proc and keep a reference to prevent GC
    _callback = NativeCallable<IntPtr Function(Int32, IntPtr, IntPtr)>.isolateLocal(
      _keyboardHookProc, 
      exceptionalReturn: 0
    );
    
    final hInstance = myGetModuleHandle(nullptr);
    _hHook = mySetWindowsHookEx(WH_KEYBOARD_LL, _callback!.nativeFunction, hInstance, 0);
    _saveHookHandle(_hHook);
  }

  void stopHook() {
    if (_hHook != 0) {
      myUnhookWindowsHookEx(_hHook);
      _hHook = 0;
      _saveHookHandle(0);
      _callback?.close();
      _callback = null;
    }
  }

  static int _keyboardHookProc(int nCode, int wParam, int lParam) {
    if (nCode >= 0) {
      final kbdStruct = Pointer<KBDLLHOOKSTRUCT>.fromAddress(lParam).ref;
      
      if ((kbdStruct.flags & LLKHF_INJECTED) != 0) {
        return myCallNextHookEx(Win32Hook()._hHook, nCode, wParam, lParam);
      }

      bool isKeyDown = wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN;
      int vkCode = kbdStruct.vkCode;
      final ime = ImeController();
      
      // Shortcut checks (always work, even if IME is disabled)
      bool isAltPressed = (myGetAsyncKeyState(VK_MENU) & 0x8000) != 0;
      
      // Alt+T = toggle IME on/off
      if (isKeyDown && isAltPressed && vkCode == 0x54) { // 'T'
        ime.toggleActive();
        return 1;
      }

      // Alt+L = cycle language
      if (isKeyDown && isAltPressed && vkCode == 0x4C) { // 'L'
        ime.cycleLanguage();
        return 1;
      }

      final hwndActive = caret_lib.myGetForegroundWindow();
      if (hwndActive != 0) {
        final pPid = calloc<Uint32>();
        caret_lib.myGetWindowThreadProcessId(hwndActive, pPid);
        final activePid = pPid.value;
        calloc.free(pPid);
        if (activePid == pid) {
          return myCallNextHookEx(Win32Hook()._hHook, nCode, wParam, lParam);
        }
      }

      // If any helper/modifier shortcut is pressed (Ctrl, Win, or Alt), bypass IME
      bool isCtrlPressed = (myGetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
      bool isWinPressed = (myGetAsyncKeyState(VK_LWIN) & 0x8000) != 0 || (myGetAsyncKeyState(VK_RWIN) & 0x8000) != 0;
      if (isCtrlPressed || isWinPressed || isAltPressed) {
        if (isKeyDown && ime.buffer.isNotEmpty) {
          final currentBuffer = ime.buffer;
          final currentIndex = ime.highlightedIndex;
          final currentSuggestions = List<String>.from(ime.suggestions);
          final lastFetched = ime.lastFetchedBuffer;
          
          ime.clearBuffer();
          
          Future(() => Win32Hook().commitCurrentWithCaptured(
            currentBuffer,
            currentIndex,
            currentSuggestions,
            lastFetched,
            "",
          ));
        }
        return myCallNextHookEx(Win32Hook()._hHook, nCode, wParam, lParam);
      }

      if (!ime.isEnabled) {
        return myCallNextHookEx(Win32Hook()._hHook, nCode, wParam, lParam);
      }

      // 🟢 উইন্ডোজকে ফাস্ট রেসপন্স দেওয়ার জন্য KeyDown আগেই চেক করে নেওয়া হলো
      if (!isKeyDown) {
        return myCallNextHookEx(Win32Hook()._hHook, nCode, wParam, lParam);
      }

      // 🟢 বাগ ফিক্স: কোনো উইন্ডোজ API কল ছাড়াই শুধু ক্যাশ করা ভেরিয়েবল চেক করা হচ্ছে
      if (Win32Hook.isBrowserFocused) {
        if (ime.buffer.isNotEmpty) {
          ime.clearBuffer();
        }
        return myCallNextHookEx(Win32Hook()._hHook, nCode, wParam, lParam);
      }

      // Check shift state and see if it's a mapped digit or punctuation
      bool isShift = (myGetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
      final mapped = Win32Hook().getMappedChar(vkCode, isShift, ime.langCode);
      if (mapped != null) {
        if (ime.buffer.isNotEmpty) {
          final currentBuffer = ime.buffer;
          final currentIndex = ime.highlightedIndex;
          final currentSuggestions = List<String>.from(ime.suggestions);
          final lastFetched = ime.lastFetchedBuffer;
          
          ime.clearBuffer();
          
          Future(() async {
            await Win32Hook().commitCurrentWithCaptured(
              currentBuffer,
              currentIndex,
              currentSuggestions,
              lastFetched,
              "",
            );
            Win32Hook().injectTranslatedOrEscape(mapped, vkCode, isShift);
          });
        } else {
          Win32Hook().injectTranslatedOrEscape(mapped, vkCode, isShift);
        }
        Future(() => ime.playKeystrokeSound());
        return 1; // Swallow the raw key event
      }

      if (vkCode >= 0x41 && vkCode <= 0x5A) { // A-Z
        String char = String.fromCharCode(vkCode).toLowerCase();
        bool isShift = (myGetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
        if (isShift) char = char.toUpperCase();
        
        ime.appendBuffer(char);
        Future(() => ime.playKeystrokeSound());
        return 1;
      }

      if (vkCode == VK_BACK) {
        if (ime.buffer.isNotEmpty) {
          ime.popBuffer();
          Future(() => ime.playKeystrokeSound());
          return 1;
        }
      }
      
      if (vkCode == VK_SPACE || vkCode == VK_RETURN) {
        if (ime.buffer.isNotEmpty) {
          String suffix = vkCode == VK_SPACE ? " " : "\n";
          
          final currentBuffer = ime.buffer;
          final currentIndex = ime.highlightedIndex;
          final currentSuggestions = List<String>.from(ime.suggestions);
          final lastFetched = ime.lastFetchedBuffer;
          
          ime.clearBuffer();
          
          // Schedule commit asynchronously
          Future(() => Win32Hook().commitCurrentWithCaptured(
            currentBuffer,
            currentIndex,
            currentSuggestions,
            lastFetched,
            suffix,
          ));
          Future(() => ime.playKeystrokeSound());
          return 1;
        }
      }

      if (vkCode == VK_ESCAPE) {
        if (ime.buffer.isNotEmpty) {
          ime.clearBuffer();
          Future(() => ime.playKeystrokeSound());
          return 1;
        }
      }

      if (vkCode >= 0x31 && vkCode <= 0x36) { // 1-6
        if (ime.buffer.isNotEmpty && ime.suggestions.isNotEmpty) {
          int idx = vkCode - 0x31;
          if (idx < ime.suggestions.length) {
            final currentBuffer = ime.buffer;
            final currentSuggestions = List<String>.from(ime.suggestions);
            final lastFetched = ime.lastFetchedBuffer;
            
            ime.clearBuffer();
            
            Future(() => Win32Hook().commitCurrentWithCaptured(
              currentBuffer,
              idx,
              currentSuggestions,
              lastFetched,
              "",
            ));
            return 1;
          }
        }
      }
      
      if (vkCode == VK_UP || vkCode == VK_DOWN) {
        if (ime.buffer.isNotEmpty) {
          if (vkCode == VK_DOWN) ime.selectNext();
          else ime.selectPrevious();
          return 1;
        }
      }
    }
    return myCallNextHookEx(Win32Hook()._hHook, nCode, wParam, lParam);
  }

  // 🟢 মেথডটিকে পাবলিক (Public) করা হয়েছে, যাতে FocusTracker একে কল করতে পারে
  static bool checkIsCompositionInWebsite(int hwndActive) {
    Pointer<Uint32>? pPid;
    Pointer<Uint16>? buffer;
    Pointer<Uint32>? size;
    Pointer<caret_lib.GUITHREADINFO>? info;
    Pointer<Uint16>? classBuffer;
    Pointer<caret_lib.RECT>? winRect;
    int hProcess = 0;

    try {
      final ime = ImeController();
      if (ime.allowWebsites) return false;

      pPid = calloc<Uint32>();
      final threadId = caret_lib.myGetWindowThreadProcessId(hwndActive, pPid);
      final pidVal = pPid.value;

      if (pidVal == 0) return false;

      // 1. Get process name
      hProcess = myOpenProcess(0x1000, 0, pidVal); // PROCESS_QUERY_LIMITED_INFORMATION
      if (hProcess == 0) {
        hProcess = myOpenProcess(0x0400, 0, pidVal); // PROCESS_QUERY_INFORMATION fallback
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

      // Update current active executable
      if (processName.isNotEmpty && ime.currentActiveExe != processName) {
        ime.currentActiveExe = processName;
      }

      // Premium Feature: App Blacklist Bypass
      if (processName.isNotEmpty && ime.appBlacklist.contains(processName)) {
        return true;
      }

      if (processName.isEmpty) return false;

      const browsers = {"chrome.exe", "msedge.exe", "firefox.exe", "opera.exe", "brave.exe"};
      if (!browsers.contains(processName)) return false;

      // 2. Check window class name of focused element
      String className = "";
      if (threadId != 0) {
        info = calloc<caret_lib.GUITHREADINFO>();
        info.ref.cbSize = sizeOf<caret_lib.GUITHREADINFO>();
        if (caret_lib.myGetGUIThreadInfo(threadId, info) != 0) {
          final hwndFocus = info.ref.hwndFocus;
          if (hwndFocus != 0) {
            classBuffer = calloc<Uint16>(256);
            final len = myGetClassName(hwndFocus, classBuffer.cast<Utf16>(), 256);
            if (len > 0) {
              className = classBuffer.cast<Utf16>().toDartString();
            }
          }
        }
      }

      const webContentClasses = {
        "Chrome_RenderWidgetHostHWND",
        "MozillaContentWindowClass",
        "Internet Explorer_Server"
      };
      if (webContentClasses.contains(className)) {
        return true;
      }

      // 3. Geometric fallback (Caret/Mouse Y relative to active window top)
      final caretPos = caret_lib.Win32Caret.getCaretScreenPos();
      if (caretPos != null) {
        winRect = calloc<caret_lib.RECT>();
        if (caret_lib.myGetWindowRect(hwndActive, winRect) != 0) {
          final diff = caretPos.bottom - winRect.ref.top;
          if (diff > 100) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      if (pPid != null) calloc.free(pPid);
      if (buffer != null) calloc.free(buffer);
      if (size != null) calloc.free(size);
      if (info != null) calloc.free(info);
      if (classBuffer != null) calloc.free(classBuffer);
      if (winRect != null) calloc.free(winRect);
      if (hProcess != 0) myCloseHandle(hProcess);
    }
  }



  Future<void> commitCurrentWithCaptured(
    String capturedBuffer,
    int capturedIndex,
    List<String> capturedSuggestions,
    String lastFetchedBuffer,
    String suffix,
  ) async {
    final ime = ImeController();
    bool isStale = lastFetchedBuffer != capturedBuffer;
    String word = capturedBuffer;
    
    List<String> finalSuggestions = capturedSuggestions;
    
    if (!isStale && capturedSuggestions.isNotEmpty) {
      if (capturedIndex < capturedSuggestions.length) {
        word = capturedSuggestions[capturedIndex];
      } else {
        word = capturedSuggestions.first;
      }
    } else {
      final customDict = PreferenceManager().getCustomDict(ime.langCode);
      final customWord = customDict[capturedBuffer] ?? customDict[capturedBuffer.toLowerCase()];
      
      final history = PreferenceManager().getHistory(ime.langCode);
      final preferred = history[capturedBuffer] ?? history[capturedBuffer.toLowerCase()];
      
      if (customWord != null) {
        word = customWord;
      } else if (preferred != null) {
        word = preferred;
      } else {
        try {
          final results = await ApiService().fetchSuggestions(
            capturedBuffer, 
            ime.langCode, 
            ime.offlineEnabled, 
            ime.onlineMode
          );
          if (results.isNotEmpty) {
            finalSuggestions = results;
            final list = results.take(5).toList();
            
            final customDict2 = PreferenceManager().getCustomDict(ime.langCode);
            final customWord2 = customDict2[capturedBuffer] ?? customDict2[capturedBuffer.toLowerCase()];
            if (customWord2 != null) {
              if (list.contains(customWord2)) {
                list.remove(customWord2);
              }
              list.insert(0, customWord2);
            }
            
            final history2 = PreferenceManager().getHistory(ime.langCode);
            final preferred2 = history2[capturedBuffer] ?? history2[capturedBuffer.toLowerCase()];
            if (preferred2 != null) {
              if (list.contains(preferred2)) {
                list.remove(preferred2);
              }
              if (customWord2 != null) {
                list.insert(1, preferred2);
              } else {
                list.insert(0, preferred2);
              }
            }
            word = list.first;
          }
        } catch (e) {
        }
      }
    }
    
    if (word.isNotEmpty && capturedBuffer.isNotEmpty) {
      PreferenceManager().savePreference(ime.langCode, capturedBuffer, word);
    }

    if (capturedBuffer.isNotEmpty && finalSuggestions.isNotEmpty) {
      ApiService().cacheWord(ime.langCode, capturedBuffer, finalSuggestions);
    }
    
    injectString(word + suffix);
  }

  void injectString(String text) {
    final pInputs = calloc<INPUT_KBD>(text.length);
    for (int i = 0; i < text.length; i++) {
      pInputs[i].type = INPUT_KEYBOARD;
      pInputs[i].wVk = 0;
      pInputs[i].wScan = text.codeUnitAt(i);
      pInputs[i].dwFlags = KEYEVENTF_UNICODE;
      pInputs[i].time = 0;
      pInputs[i].dwExtraInfo = 0;
    }
    
    mySendInput(text.length, pInputs, sizeOf<INPUT_KBD>());
    
    final pInputsUp = calloc<INPUT_KBD>(text.length);
    for (int i = 0; i < text.length; i++) {
      pInputsUp[i].type = INPUT_KEYBOARD;
      pInputsUp[i].wVk = 0;
      pInputsUp[i].wScan = text.codeUnitAt(i);
      pInputsUp[i].dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
      pInputsUp[i].time = 0;
      pInputsUp[i].dwExtraInfo = 0;
    }
    
    mySendInput(text.length, pInputsUp, sizeOf<INPUT_KBD>());
    
    calloc.free(pInputs);
    calloc.free(pInputsUp);
  }

  void injectTranslatedOrEscape(String mappedChar, int vkCode, bool isShift) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final originalStr = _getOriginalCharStr(vkCode, isShift);
    
    if (_lastOriginalChar == originalStr &&
        _lastInjectedChar == mappedChar &&
        (now - _lastInjectTime) < 800) {
      _lastOriginalChar = "";
      _lastInjectedChar = "";
      _lastInjectTime = 0;
      
      injectBackspaceAndChar(originalStr);
    } else {
      _lastOriginalChar = originalStr;
      _lastInjectedChar = mappedChar;
      _lastInjectTime = now;
      
      injectString(mappedChar);
    }
  }

  void injectBackspaceAndChar(String char) {
    _isInjecting = true;
    
    final pInputs = calloc<INPUT_KBD>(4 + char.length * 2);
    
    pInputs[0].type = INPUT_KEYBOARD;
    pInputs[0].wVk = VK_BACK;
    pInputs[0].wScan = 0;
    pInputs[0].dwFlags = 0;
    pInputs[0].time = 0;
    pInputs[0].dwExtraInfo = 0;
    
    pInputs[1].type = INPUT_KEYBOARD;
    pInputs[1].wVk = VK_BACK;
    pInputs[1].wScan = 0;
    pInputs[1].dwFlags = KEYEVENTF_KEYUP;
    pInputs[1].time = 0;
    pInputs[1].dwExtraInfo = 0;
    
    int idx = 2;
    for (int i = 0; i < char.length; i++) {
      pInputs[idx].type = INPUT_KEYBOARD;
      pInputs[idx].wVk = 0;
      pInputs[idx].wScan = char.codeUnitAt(i);
      pInputs[idx].dwFlags = KEYEVENTF_UNICODE;
      pInputs[idx].time = 0;
      pInputs[idx].dwExtraInfo = 0;
      
      pInputs[idx + 1].type = INPUT_KEYBOARD;
      pInputs[idx + 1].wVk = 0;
      pInputs[idx + 1].wScan = char.codeUnitAt(i);
      pInputs[idx + 1].dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
      pInputs[idx + 1].time = 0;
      pInputs[idx + 1].dwExtraInfo = 0;
      
      idx += 2;
    }
    
    mySendInput(idx, pInputs, sizeOf<INPUT_KBD>());
    calloc.free(pInputs);
    
    Future.delayed(const Duration(milliseconds: 10), () {
      _isInjecting = false;
    });
  }

  String? getMappedChar(int vkCode, bool isShift, String langCode) {
    String? digitChar;
    if (vkCode >= 0x30 && vkCode <= 0x39) {
      digitChar = String.fromCharCode(vkCode);
    } else if (vkCode >= 0x60 && vkCode <= 0x69) {
      digitChar = String.fromCharCode(vkCode - 0x30);
    }

    if (digitChar != null) {
      final ime = ImeController();
      if (ime.buffer.isNotEmpty && !isShift && (vkCode >= 0x31 && vkCode <= 0x36) && (vkCode < 0x60)) {
        return null;
      }
      
      if (isShift && vkCode == 0x34) {
      } else {
        return _getTranslatedDigit(digitChar, langCode);
      }
    }

    if (vkCode == 0xBE) {
      if (langCode == "bn-t-i0-und" || langCode == "hi-t-i0-und" || langCode == "ne-t-i0-und") return "।";
      if (langCode == "ar-t-i0-und" || langCode == "ur-t-i0-und") return "۔";
    }

    if (vkCode == 0x34 && isShift) {
      if (langCode == "bn-t-i0-und") return "৳";
      if (langCode == "hi-t-i0-und" || langCode == "ne-t-i0-und") return "₹";
    }

    if (vkCode == 0xBC) {
      if (langCode == "ar-t-i0-und" || langCode == "ur-t-i0-und") {
        if (!isShift) return "،";
      }
    }

    if (vkCode == 0xBA) {
      if (langCode == "ar-t-i0-und" || langCode == "ur-t-i0-und") {
        if (!isShift) return "؛";
      }
    }

    if (vkCode == 0xBF && isShift) {
      if (langCode == "ar-t-i0-und" || langCode == "ur-t-i0-und") return "؟";
    }

    return null;
  }

  String _getTranslatedDigit(String digit, String langCode) {
    const bn = {'0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪', '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯'};
    const hiNe = {'0': '०', '1': '१', '2': '२', '3': '३', '4': '४', '5': '५', '6': '६', '7': '७', '8': '८', '9': '९'};
    const ar = {'0': '٠', '1': '١', '2': '٢', '3': '٣', '4': '٤', '5': '٥', '6': '٦', '7': '٧', '8': '٨', '9': '٩'};
    const ur = {'0': '۰', '1': '۱', '2': '۲', '3': '۳', '4': '۴', '5': '۵', '6': '۶', '7': '۷', '8': '۸', '9': '۹'};

    if (langCode == "bn-t-i0-und") return bn[digit] ?? digit;
    if (langCode == "hi-t-i0-und" || langCode == "ne-t-i0-und") return hiNe[digit] ?? digit;
    if (langCode == "ar-t-i0-und") return ar[digit] ?? digit;
    if (langCode == "ur-t-i0-und") return ur[digit] ?? digit;
    return digit;
  }

  String _getOriginalCharStr(int vkCode, bool isShift) {
    if (vkCode >= 0x30 && vkCode <= 0x39) {
      if (isShift && vkCode == 0x34) return "\$";
      return String.fromCharCode(vkCode);
    }
    if (vkCode >= 0x60 && vkCode <= 0x69) {
      return String.fromCharCode(vkCode - 0x30);
    }
    if (vkCode == 0xBE) return ".";
    if (vkCode == 0xBC) return ",";
    if (vkCode == 0xBA) return ";";
    if (vkCode == 0xBF) return "?";
    return "";
  }
}