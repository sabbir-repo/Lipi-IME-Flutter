import time
import queue
import threading
import ctypes
from ctypes import wintypes
import sys
import os
import keyboard
import pystray
from PIL import Image, ImageDraw
try:
    import winreg
except ImportError:
    winreg = None

# Redirect stdout/stderr to devnull when running as a windowed executable (without console) to prevent OS errors
if sys.stdout is None:
    sys.stdout = open(os.devnull, "w")
if sys.stderr is None:
    sys.stderr = open(os.devnull, "w")

from api import fetch_suggestions
from gui import MainWindow

user32 = ctypes.windll.user32

# Win32 Helpers for Modifier Checking (Fast & thread-safe, no string parsing or library lock)
def is_ctrl_pressed():
    return (user32.GetAsyncKeyState(0x11) & 0x8000) != 0

def is_win_pressed():
    return (user32.GetAsyncKeyState(0x5B) & 0x8000) != 0 or (user32.GetAsyncKeyState(0x5C) & 0x8000) != 0

def is_alt_pressed():
    return (user32.GetAsyncKeyState(0x12) & 0x8000) != 0

PUNCT_MAPS = {
    "bn-t-i0-und": {
        '.': '।',
        '$': '৳'
    },
    "hi-t-i0-und": {
        '.': '।',
        '$': '₹'
    },
    "ne-t-i0-und": {
        '.': '।',
        '$': '₹'
    },
    "ar-t-i0-und": {
        '.': '۔',
        ',': '،',
        ';': '؛',
        '?': '؟'
    },
    "ur-t-i0-und": {
        '.': '۔',
        ',': '،',
        ';': '؛',
        '?': '؟'
    }
}

DIGIT_MAPS = {
    "bn-t-i0-und": {'0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪', '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯'},
    "hi-t-i0-und": {'0': '०', '1': '१', '2': '२', '3': '३', '4': '४', '5': '५', '6': '६', '7': '७', '8': '८', '9': '९'},
    "ne-t-i0-und": {'0': '०', '1': '१', '2': '२', '3': '३', '4': '४', '5': '५', '6': '६', '7': '७', '8': '८', '9': '९'},
    "ar-t-i0-und": {'0': '٠', '1': '١', '2': '٢', '3': '٣', '4': '٤', '5': '٥', '6': '٦', '7': '٧', '8': '٨', '9': '٩'},
    "ur-t-i0-und": {'0': '۰', '1': '۱', '2': '۲', '3': '۳', '4': '۴', '5': '۵', '6': '۶', '7': '۷', '8': '۸', '9': '۹'}
}

# Windows API Structures for Caret Position
class RECT(ctypes.Structure):
    _fields_ = [
        ("left", ctypes.c_long),
        ("top", ctypes.c_long),
        ("right", ctypes.c_long),
        ("bottom", ctypes.c_long),
    ]

class GUITHREADINFO(ctypes.Structure):
    _fields_ = [
        ("cbSize", ctypes.c_ulong),
        ("flags", ctypes.c_ulong),
        ("hwndActive", ctypes.c_void_p),
        ("hwndFocus", ctypes.c_void_p),
        ("hwndCapture", ctypes.c_void_p),
        ("hwndMenuOwner", ctypes.c_void_p),
        ("hwndMoveSize", ctypes.c_void_p),
        ("hwndCaret", ctypes.c_void_p),
        ("rcCaret", RECT),
    ]

def get_caret_screen_pos():
    """Retrieves caret screen position (x, top, bottom) if available via Windows API."""
    hwnd_active = user32.GetForegroundWindow()
    if not hwnd_active:
        return None
        
    pid = ctypes.c_ulong()
    thread_id = user32.GetWindowThreadProcessId(hwnd_active, ctypes.byref(pid))
    
    info = GUITHREADINFO()
    info.cbSize = ctypes.sizeof(GUITHREADINFO)
    
    # Query specific thread ID of the foreground window to ensure accurate cross-process focus retrieval
    if user32.GetGUIThreadInfo(thread_id, ctypes.byref(info)):
        hwnd_caret = info.hwndCaret or info.hwndFocus or hwnd_active
        rect = info.rcCaret
        if rect.left != 0 or rect.top != 0 or rect.bottom != 0:
            pt_top = wintypes.POINT(rect.left, rect.top)
            pt_bottom = wintypes.POINT(rect.left, rect.bottom)
            user32.ClientToScreen(hwnd_caret, ctypes.byref(pt_top))
            user32.ClientToScreen(hwnd_caret, ctypes.byref(pt_bottom))
            return pt_bottom.x, pt_top.y, pt_bottom.y
    return None

def get_suggestion_position():
    """Gets suggestion position info: (x, top, bottom) relative to caret/mouse cursor."""
    caret_pos = get_caret_screen_pos()
    if caret_pos:
        return caret_pos
        
    # Fallback to mouse position offset
    try:
        class POINT(ctypes.Structure):
            _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]
        pt = POINT()
        user32.GetCursorPos(ctypes.byref(pt))
        # Treat mouse cursor height as ~16 pixels
        return pt.x, pt.y, pt.y + 16
    except Exception:
        return 100, 100, 116

class SuggestionDebouncer(threading.Thread):
    """Reuses a single background thread to debounce API requests, avoiding spawning threads on keystrokes."""
    def __init__(self, app):
        super().__init__(daemon=True)
        self.app = app
        self.trigger_event = threading.Event()
        self.last_request_time = 0
        self.pending_text = None
        self.lock = threading.Lock()

    def request_fetch(self, text):
        with self.lock:
            self.pending_text = text
            self.last_request_time = time.time()
        self.trigger_event.set()

    def cancel_pending(self):
        with self.lock:
            self.pending_text = None

    def run(self):
        while True:
            self.trigger_event.wait()
            
            # Debounce delay loop using dynamic app config
            while True:
                with self.lock:
                    now = time.time()
                    elapsed = now - self.last_request_time
                    text = self.pending_text
                
                delay = self.app.debounce_delay
                
                if text is None:
                    break # Cancelled by a commit
                if elapsed >= delay:
                    break
                else:
                    time.sleep(delay - elapsed)
            
            with self.lock:
                self.pending_text = None
                self.trigger_event.clear()
                
            if text is not None:
                self.app._fetch_worker(text)

class CommitQueue(threading.Thread):
    """Reuses a single background thread to write/commit translated words sequentially."""
    def __init__(self, app):
        super().__init__(daemon=True)
        self.app = app
        self.queue = queue.Queue()

    def request_commit(self, buffer_text, suggestions, target_idx, is_up_to_date, suffix, active_hwnd):
        self.queue.put((buffer_text, suggestions, target_idx, is_up_to_date, suffix, active_hwnd))

    def run(self):
        while True:
            buffer_text, suggestions, target_idx, is_up_to_date, suffix, active_hwnd = self.queue.get()
            
            word = None
            if is_up_to_date and suggestions and target_idx < len(suggestions):
                word = suggestions[target_idx]
            else:
                # If suggestions are not loaded or outdated, fetch suggestions synchronously in this background thread
                fetched = fetch_suggestions(buffer_text, self.app.lang_code, self.app.offline_enabled, self.app.online_mode)
                fetched = list(fetched)[:5] if fetched else []
                fetched.append(buffer_text)
                
                # Check custom dictionary mapping (case-sensitive check with case-insensitive fallback)
                custom_word = self.app.custom_dict.get(buffer_text) or self.app.custom_dict.get(buffer_text.lower())
                if custom_word:
                    if custom_word in fetched:
                        fetched.remove(custom_word)
                    fetched.insert(0, custom_word)
                    fetched = fetched[:6]
                
                # Reorder based on user preference (case-sensitive check with case-insensitive fallback)
                pref_dict = self.app.user_prefs.get(self.app.lang_code, {})
                preferred = pref_dict.get(buffer_text) or pref_dict.get(buffer_text.lower())
                if preferred:
                    if preferred in fetched:
                        fetched.remove(preferred)
                        if custom_word:
                            fetched.insert(1, preferred)
                        else:
                            fetched.insert(0, preferred)
                    else:
                        if custom_word:
                            fetched.insert(1, preferred)
                        else:
                            fetched.insert(0, preferred)
                    fetched = fetched[:6]
                    
                if target_idx < len(fetched):
                    word = fetched[target_idx]
                else:
                    word = fetched[0]
            
            if not word:
                word = buffer_text
                
            # Learn/Update user preference dynamically
            if word and buffer_text:
                self.app.update_preference(buffer_text, word)
                
            # Restore focus to original active window if focus shifted
            if active_hwnd:
                current_fg = user32.GetForegroundWindow()
                if current_fg != active_hwnd:
                    user32.SetForegroundWindow(active_hwnd)
                    time.sleep(0.01) # Small delay for OS event queue focus swap

            # Type text via native OS SendInput Unicode (VK_PACKET)
            keyboard.write(word)
            if suffix:
                keyboard.write(suffix)
                
            self.queue.task_done()

def set_startup_registry(enable):
    """Enable or disable run on Windows Startup by managing a Shortcut in the Startup folder."""
    import sys
    import os
    import tempfile
    import subprocess
    
    # Try to clean up the old registry key that triggered Windows Defender
    if winreg:
        key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
        app_name = "LipiIME"
        try:
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path, 0, winreg.KEY_SET_VALUE)
            winreg.DeleteValue(key, app_name)
            winreg.CloseKey(key)
        except Exception:
            pass

    # Use the Startup folder instead to avoid heuristic detection
    app_name = "LipiIME"
    startup_dir = os.path.join(os.environ.get("APPDATA", ""), "Microsoft", "Windows", "Start Menu", "Programs", "Startup")
    shortcut_path = os.path.join(startup_dir, f"{app_name}.lnk")
    
    if enable:
        is_exe = sys.argv[0].lower().endswith(".exe") or getattr(sys, 'frozen', False)
        if is_exe:
            target = os.path.abspath(sys.argv[0])
            args = ""
            work_dir = os.path.dirname(target)
        else:
            target = sys.executable
            args = f'"{os.path.abspath(sys.argv[0])}"'
            work_dir = os.path.dirname(os.path.abspath(sys.argv[0]))

        ps_script = f"$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('{shortcut_path}'); $Shortcut.TargetPath = '{target}'; $Shortcut.Arguments = '{args}'; $Shortcut.WorkingDirectory = '{work_dir}'; $Shortcut.Save()"
        try:
            subprocess.run(["powershell.exe", "-NoProfile", "-WindowStyle", "Hidden", "-Command", ps_script], creationflags=0x08000000, check=True)
        except Exception as e:
            print("Failed to create startup shortcut:", e)
    else:
        if os.path.exists(shortcut_path):
            try:
                os.remove(shortcut_path)
            except Exception as e:
                print("Failed to remove startup shortcut:", e)

class TransliterationApp:
    def __init__(self, gui_queue):
        self.gui_queue = gui_queue
        self.buffer = ""
        self.suggestions = []
        self.suggestions_for_text = ""
        self.highlighted_index = 0
        self.enabled = True  # Default state, will be overwritten by load_user_prefs
        self.lang_code = "bn-t-i0-und"  # Default to Bengali
        self.debounce_delay = 0.07  # Default to 70ms
        self.allow_websites = False  # Bypassed inside websites by default
        self.font_size = 11  # Default suggestion window font size
        self.theme_name = "Dark"
        self.startup = False
        self.offline_enabled = True
        self.online_mode = True
        self.sound_enabled = True
        self.suggestion_opacity = 0.9
        self.hook_handler = None
        
        # Track the OS active window handle (HWND) for focus restoration
        self.active_hwnd = None
        self.gui_hwnd = None
        self.tray_icon = None
        
        # Track suppressed keys to swallow both down and up events
        self.suppressed_scan_codes = set()
        
        # Double-press punctuation escape tracking
        self.last_original_char = ""
        self.last_injected_char = ""
        self.last_inject_time = 0
        
        # Load user preferences history (persisted in user home folder)
        self.load_user_prefs()
        
        self.lock = threading.Lock()

        # Initialize background worker threads
        self.debouncer = SuggestionDebouncer(self)
        self.debouncer.start()
        
        self.commit_queue = CommitQueue(self)
        self.commit_queue.start()

    def toggle_active(self):
        """Toggles the global IME on/off."""
        self.enabled = not self.enabled
        with self.lock:
            self.debouncer.cancel_pending()
            self.buffer = ""
            self.suggestions = []
            self.suggestions_for_text = ""
            self.highlighted_index = 0
        self.hide_suggestions()
        
        state_str = "ENABLED" if self.enabled else "DISABLED"
        print(f"\n[IME status: {state_str}]")
        
        if self.sound_enabled:
            try:
                import winsound
                if self.enabled:
                    winsound.Beep(900, 120)
                else:
                    winsound.Beep(600, 120)
            except Exception:
                pass
            
        self.update_gui_status()

    def cycle_language(self):
        """Cycles the active IME language to the next one in the list."""
        lang_codes = ["bn-t-i0-und", "hi-t-i0-und", "ar-t-i0-und", "ne-t-i0-und", "ur-t-i0-und"]
        try:
            idx = lang_codes.index(self.lang_code)
            next_idx = (idx + 1) % len(lang_codes)
        except ValueError:
            next_idx = 0
            
        with self.lock:
            self.lang_code = lang_codes[next_idx]
            
        # Play a sound notification
        if self.sound_enabled:
            try:
                import winsound
                # Different pitch beep for each language to give audio feedback
                winsound.Beep(700 + next_idx * 100, 150)
            except Exception:
                pass
            
        self.update_gui_status()
        self.gui_queue.put({
            "action": "show_lang_notification",
            "lang_code": self.lang_code,
            "enabled": self.enabled
        })

    def load_user_prefs(self):
        import json
        import os
        self.pref_file = os.path.join(os.path.expanduser("~"), ".lipi_ime_prefs.json")
        self.user_prefs = {}
        if os.path.exists(self.pref_file):
            try:
                with open(self.pref_file, "r", encoding="utf-8") as f:
                    self.user_prefs = json.load(f)
            except Exception:
                pass
                
        # Load settings from preferences (with default fallbacks)
        self.enabled = self.user_prefs.get("enabled", True)
        self.theme_name = self.user_prefs.get("theme_name", "Dark")
        self.startup = self.user_prefs.get("startup", False)
        self.online_mode = self.user_prefs.get("online_mode", True)
        self.offline_enabled = self.user_prefs.get("offline_enabled", True)
        self.lang_code = self.user_prefs.get("lang_code", "bn-t-i0-und")
        self.debounce_delay = self.user_prefs.get("debounce_delay", 0.07)
        self.allow_websites = self.user_prefs.get("allow_websites", False)
        self.font_size = self.user_prefs.get("font_size", 11)
        self.suggestion_opacity = self.user_prefs.get("suggestion_opacity", 0.9)
        self.sound_enabled = self.user_prefs.get("sound_enabled", True)
        
        # Load custom dictionary
        self.custom_dict_file = os.path.join(os.path.expanduser("~"), ".lipi_ime_dict.json")
        self.custom_dict = {}
        if os.path.exists(self.custom_dict_file):
            try:
                with open(self.custom_dict_file, "r", encoding="utf-8") as f:
                    self.custom_dict = json.load(f)
            except Exception:
                pass

    def save_user_prefs(self):
        import json
        with self.lock:
            self.user_prefs["enabled"] = self.enabled
            self.user_prefs["theme_name"] = self.theme_name
            self.user_prefs["startup"] = self.startup
            self.user_prefs["online_mode"] = self.online_mode
            self.user_prefs["offline_enabled"] = self.offline_enabled
            self.user_prefs["lang_code"] = self.lang_code
            self.user_prefs["debounce_delay"] = self.debounce_delay
            self.user_prefs["allow_websites"] = self.allow_websites
            self.user_prefs["font_size"] = self.font_size
            self.user_prefs["suggestion_opacity"] = self.suggestion_opacity
            self.user_prefs["sound_enabled"] = self.sound_enabled
            data = dict(self.user_prefs)
        try:
            with open(self.pref_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
        except Exception:
            pass

    def save_custom_dict(self):
        import json
        with self.lock:
            data = dict(self.custom_dict)
        try:
            with open(self.custom_dict_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=4)
        except Exception:
            pass

    def update_preference(self, buffer_text, selected_word):
        with self.lock:
            lang_key = self.lang_code
            if lang_key not in self.user_prefs:
                self.user_prefs[lang_key] = {}
            # Save using the exact case-sensitive buffer_text key
            self.user_prefs[lang_key][buffer_text] = selected_word
        threading.Thread(target=self.save_user_prefs, daemon=True).start()

    def update_gui_status(self, active_app=""):
        """Sends current state info to the main Tkinter dashboard queue and updates tray icon."""
        if hasattr(self, "tray_icon") and self.tray_icon:
            try:
                status_text = "Active" if self.enabled else "Disabled"
                self.tray_icon.title = f"Lipi IME ({status_text})"
            except Exception:
                pass
                
        self.gui_queue.put({
            "action": "update_status",
            "enabled": self.enabled,
            "lang_code": self.lang_code,
            "active_app": active_app,
            "allow_websites": self.allow_websites,
            "font_size": self.font_size,
            "startup": self.startup,
            "theme_name": self.theme_name,
            "online_mode": self.online_mode,
            "offline_enabled": self.offline_enabled,
            "debounce_delay": int(self.debounce_delay * 1000),
            "opacity": self.suggestion_opacity,
            "sound_enabled": self.sound_enabled
        })

    def is_composition_in_website(self):
        """
        Detects if keyboard focus is currently inside a web page (website) in a browser window.
        Returns True if in a web page (so IME should bypass), False otherwise.
        """
        if self.allow_websites:
            return False
            
        try:
            # 1. Get active process executable name
            pid = ctypes.c_ulong()
            hwnd_active = user32.GetForegroundWindow()
            if not hwnd_active:
                return False
            thread_id = user32.GetWindowThreadProcessId(hwnd_active, ctypes.byref(pid))
            
            PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
            kernel32 = ctypes.windll.kernel32
            h_process = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
            if not h_process:
                h_process = kernel32.OpenProcess(0x0400, False, pid) # Fallback to standard query
                
            process_name = ""
            if h_process:
                try:
                    buffer = ctypes.create_unicode_buffer(512)
                    size = ctypes.c_ulong(512)
                    if kernel32.QueryFullProcessImageNameW(h_process, 0, buffer, ctypes.byref(size)):
                        import os
                        process_name = os.path.basename(buffer.value).lower()
                except Exception:
                    pass
                finally:
                    kernel32.CloseHandle(h_process)
                    
            if not process_name:
                return False
                
            # List of standard web browser executables
            browsers = {"chrome.exe", "msedge.exe", "firefox.exe", "opera.exe", "brave.exe"}
            if process_name not in browsers:
                return False
                
            # 2. Layer 1: Focused window Win32 Class Name
            info = GUITHREADINFO()
            info.cbSize = ctypes.sizeof(GUITHREADINFO)
            class_name = ""
            if user32.GetGUIThreadInfo(thread_id, ctypes.byref(info)):
                hwnd_focus = info.hwndFocus
                if hwnd_focus:
                    class_buffer = ctypes.create_unicode_buffer(256)
                    user32.GetClassNameW(hwnd_focus, class_buffer, 256)
                    class_name = class_buffer.value
                    
                    web_content_classes = {
                        "Chrome_RenderWidgetHostHWND", 
                        "MozillaContentWindowClass", 
                        "Internet Explorer_Server"
                    }
                    if class_name in web_content_classes:
                        return True
                        
            # 3. Layer 2: Geometric fallback (Caret/Mouse Y position relative to Window Top)
            caret_pos = get_caret_screen_pos()
            if caret_pos:
                _, _, caret_y = caret_pos
            else:
                try:
                    class POINT(ctypes.Structure):
                        _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]
                    pt = POINT()
                    user32.GetCursorPos(ctypes.byref(pt))
                    caret_y = pt.y
                except Exception:
                    caret_y = 0
                    
            if caret_y > 0:
                win_rect = RECT()
                if user32.GetWindowRect(hwnd_active, ctypes.byref(win_rect)):
                    diff = caret_y - win_rect.top
                    # Web viewport always starts > 100px below browser top (toolbar/tabs)
                    if diff > 100:
                        return True
        except Exception:
            pass
        return False

    def on_key_event(self, e):
        """
        Processes global key events synchronously in the hook.
        Returns False to block the event from the OS, or True to let it pass.
        """
        # Global Toggle Check (Alt + T) and Language Swap Check (Alt + L)
        if e.event_type == 'down':
            if e.name == 't' and is_alt_pressed():
                self.toggle_active()
                self.suppressed_scan_codes.add(e.scan_code)
                try:
                    # Send a dummy VK_NONAME keystroke to prevent Windows from activating the window menu bar and taking focus
                    ctypes.windll.user32.keybd_event(0xFC, 0, 0, 0)
                    ctypes.windll.user32.keybd_event(0xFC, 0, 2, 0)
                except Exception:
                    pass
                return False
            elif e.name == 'l' and is_alt_pressed():
                self.cycle_language()
                self.suppressed_scan_codes.add(e.scan_code)
                try:
                    # Send a dummy VK_NONAME keystroke to prevent Windows from activating the window menu bar and taking focus
                    ctypes.windll.user32.keybd_event(0xFC, 0, 0, 0)
                    ctypes.windll.user32.keybd_event(0xFC, 0, 2, 0)
                except Exception:
                    pass
                return False

        # If it's a key release (up) event for a key we suppressed on press (down), suppress it.
        if e.event_type == 'up':
            if e.scan_code in self.suppressed_scan_codes:
                self.suppressed_scan_codes.discard(e.scan_code)
                return False
            return True

        # From this point on, we only handle KeyDown events.
        if not self.enabled:
            return True

        name = e.name
        if not name:
            return True

        # Check if composition should be bypassed because focus is inside a browser website
        if self.is_composition_in_website():
            if self.buffer:
                self.commit_suggestion(self.highlighted_index, suffix="", is_digit_select=False)
            return True

        # If Ctrl, Windows, or Alt modifiers are pressed, bypass IME but commit buffer if active.
        if is_ctrl_pressed() or is_win_pressed() or is_alt_pressed():
            if self.buffer:
                self.commit_suggestion(self.highlighted_index, suffix="", is_digit_select=False)
            return True

        # Check if the key is a mapped punctuation
        lang_puncts = PUNCT_MAPS.get(self.lang_code, {})
        if name in lang_puncts:
            # First, if there's a buffer, commit it
            if self.buffer:
                self.commit_suggestion(self.highlighted_index, suffix="", is_digit_select=False)
            
            translated_char = lang_puncts[name]
            now = time.time()
            # Double-press check:
            if (self.last_original_char == name and 
                self.last_injected_char == translated_char and 
                now - self.last_inject_time < 0.8):
                
                # Double-press detected: delete translated, write original
                self.last_original_char = ""
                self.last_injected_char = ""
                self.last_inject_time = 0
                
                keyboard.send('backspace')
                keyboard.write(name)
            else:
                # First press: write translated character
                self.last_original_char = name
                self.last_injected_char = translated_char
                self.last_inject_time = now
                
                keyboard.write(translated_char)
                
            self.suppressed_scan_codes.add(e.scan_code)
            return False
        else:
            # Reset double-press tracking if any other key is pressed
            self.last_original_char = ""
            self.last_injected_char = ""
            self.last_inject_time = 0

        # Handle digits translation (supporting standard & numpad numbers)
        lang_digits = DIGIT_MAPS.get(self.lang_code, {})
        digit_key = None
        if name in lang_digits:
            digit_key = name
        elif name.startswith("numpad ") and name.replace("numpad ", "") in lang_digits:
            digit_key = name.replace("numpad ", "")

        if digit_key is not None:
            # If buffer and suggestions exist, and digit is 1-6 from main keys, use for candidate selection
            if self.buffer and self.suggestions and digit_key in ('1', '2', '3', '4', '5', '6') and not name.startswith("numpad "):
                pass
            else:
                # Translate the digit
                translated_digit = lang_digits[digit_key]
                # If there's a buffer, commit it first
                if self.buffer:
                    self.commit_suggestion(self.highlighted_index, suffix="", is_digit_select=False)
                
                keyboard.write(translated_digit)
                self.suppressed_scan_codes.add(e.scan_code)
                return False

        # 1. Letters (a-z, A-Z)
        if len(name) == 1 and name.isalpha():
            with self.lock:
                self.buffer += name
            self.async_fetch_suggestions()
            self.suppressed_scan_codes.add(e.scan_code)
            return False

        # 2. Backspace key
        if name == 'backspace':
            if self.buffer:
                with self.lock:
                    self.buffer = self.buffer[:-1]
                if self.buffer:
                    self.async_fetch_suggestions()
                else:
                    self.hide_suggestions()
                self.suppressed_scan_codes.add(e.scan_code)
                return False
            return True

        # 3. Space key
        if name == 'space':
            if self.buffer:
                self.commit_suggestion(self.highlighted_index, suffix=" ", is_digit_select=False)
                self.suppressed_scan_codes.add(e.scan_code)
                return False
            return True

        # 4. Enter key
        if name == 'enter':
            if self.buffer:
                self.commit_suggestion(self.highlighted_index, suffix="", is_digit_select=False)
                self.suppressed_scan_codes.add(e.scan_code)
                return False
            return True

        # 5. Escape key (commissions typed English buffer as-is)
        if name in ('esc', 'escape'):
            if self.buffer:
                # Force commit English buffer literal text
                with self.lock:
                    self.suggestions = [self.buffer]
                    self.suggestions_for_text = self.buffer
                self.commit_suggestion(0, suffix="", is_digit_select=True)
                self.suppressed_scan_codes.add(e.scan_code)
                return False
            return True

        # 6. Digits 1-6 (Candidate Selection, including option 6 - English text)
        if name in ('1', '2', '3', '4', '5', '6'):
            if self.buffer and self.suggestions:
                idx = int(name) - 1
                if idx < len(self.suggestions):
                    self.commit_suggestion(idx, suffix="", is_digit_select=True)
                    self.suppressed_scan_codes.add(e.scan_code)
                    return False
                self.suppressed_scan_codes.add(e.scan_code)
                return False
            return True

        # 7. Up / Down Arrows (Candidate Navigation)
        if name in ('up', 'down'):
            if self.buffer and self.suggestions:
                num_cands = len(self.suggestions)
                if num_cands > 0:
                    if name == 'down':
                        self.highlighted_index = (self.highlighted_index + 1) % num_cands
                    else:
                        self.highlighted_index = (self.highlighted_index - 1) % num_cands
                    self.gui_queue.put({
                        "action": "highlight",
                        "index": self.highlighted_index
                    })
                self.suppressed_scan_codes.add(e.scan_code)
                return False
            return True

        # 8. Modifiers (ignored in composition but not committed)
        modifiers_to_ignore = {
            'shift', 'left shift', 'right shift',
            'ctrl', 'left ctrl', 'right ctrl',
            'alt', 'left alt', 'right alt', 'alt gr',
            'windows', 'left windows', 'right windows',
            'caps lock', 'num lock', 'scroll lock'
        }
        if name in modifiers_to_ignore:
            return True

        # 9. Punctuation / other keys: commit active suggestion first, then let key pass
        if self.buffer:
            self.commit_suggestion(self.highlighted_index, suffix="", is_digit_select=False)

        return True

    def async_fetch_suggestions(self):
        text = self.buffer
        if not text:
            return
            
        res = fetch_suggestions(text, self.lang_code, self.offline_enabled, self.online_mode)
        with self.lock:
            if self.buffer == text and self.enabled:
                # Limit API candidates to at most 5, and append literal English text as the 6th option
                res = list(res)[:5] if res else []
                res.append(text)
                
                # Check custom dictionary mapping (case-sensitive check with case-insensitive fallback)
                custom_word = self.custom_dict.get(text) or self.custom_dict.get(text.lower())
                if custom_word:
                    if custom_word in res:
                        res.remove(custom_word)
                    res.insert(0, custom_word)
                    res = res[:6]
                
                # Reorder based on user preference history (case-sensitive check with case-insensitive fallback)
                pref_dict = self.user_prefs.get(self.lang_code, {})
                preferred = pref_dict.get(text) or pref_dict.get(text.lower())
                if preferred:
                    if preferred in res:
                        res.remove(preferred)
                        if custom_word:
                            res.insert(1, preferred)
                        else:
                            res.insert(0, preferred)
                    else:
                        if custom_word:
                            res.insert(1, preferred)
                        else:
                            res.insert(0, preferred)
                    res = res[:6]
                        
                self.suggestions = res
                self.suggestions_for_text = text
                if self.suggestions:
                    self.highlighted_index = 0
                    x, top, bottom = get_suggestion_position()
                    self.gui_queue.put({
                        "action": "show",
                        "x": x,
                        "caret_top": top,
                        "caret_bottom": bottom,
                        "buffer": self.buffer,
                        "candidates": self.suggestions,
                        "highlighted_index": self.highlighted_index
                    })
                else:
                    self.hide_suggestions()

    def _fetch_worker(self, text):
        res = fetch_suggestions(text, self.lang_code, self.offline_enabled, self.online_mode)
        with self.lock:
            if self.buffer == text and self.enabled:
                # Limit API candidates to at most 5, and append literal English text as the 6th option
                res = list(res)[:5] if res else []
                res.append(text)
                
                # Check custom dictionary mapping (case-sensitive check with case-insensitive fallback)
                custom_word = self.custom_dict.get(text) or self.custom_dict.get(text.lower())
                if custom_word:
                    if custom_word in res:
                        res.remove(custom_word)
                    res.insert(0, custom_word)
                    res = res[:6]
                
                # Reorder based on user preference history (case-sensitive check with case-insensitive fallback)
                pref_dict = self.user_prefs.get(self.lang_code, {})
                preferred = pref_dict.get(text) or pref_dict.get(text.lower())
                if preferred:
                    if preferred in res:
                        res.remove(preferred)
                        if custom_word:
                            res.insert(1, preferred)
                        else:
                            res.insert(0, preferred)
                    else:
                        if custom_word:
                            res.insert(1, preferred)
                        else:
                            res.insert(0, preferred)
                    res = res[:6]
                        
                self.suggestions = res
                self.suggestions_for_text = text
                if self.suggestions:
                    self.highlighted_index = 0
                    x, top, bottom = get_suggestion_position()
                    self.gui_queue.put({
                        "action": "show",
                        "x": x,
                        "caret_top": top,
                        "caret_bottom": bottom,
                        "buffer": self.buffer,
                        "candidates": self.suggestions,
                        "highlighted_index": self.highlighted_index
                    })
                else:
                    self.hide_suggestions()

    def hide_suggestions(self):
        self.suggestions_for_text = ""
        self.gui_queue.put({"action": "hide"})

    def commit_suggestion(self, target_idx, suffix="", is_digit_select=False):
        """Resets composition state and queues the commit to CommitQueue."""
        with self.lock:
            if not self.buffer:
                return
            
            self.debouncer.cancel_pending()
            
            buffer_text = self.buffer
            suggestions = list(self.suggestions)
            
            # Suggestions are up-to-date if they match the current buffer, or if explicitly selected
            is_up_to_date = (self.suggestions_for_text == self.buffer) or is_digit_select
            
            # Reset composition states immediately
            self.buffer = ""
            self.suggestions = []
            self.suggestions_for_text = ""
            self.highlighted_index = 0
            self.hide_suggestions()
            
        self.commit_queue.request_commit(buffer_text, suggestions, target_idx, is_up_to_date, suffix, self.active_hwnd)

def focus_and_mouse_poller(app, gui):
    """Polls mouse clicks and active window focus shifts to clear buffer and hide suggestions."""
    was_down = False
    last_process_name = ""
    
    while True:
        # 1. Clear buffer on mouse clicks outside the suggestion window
        is_down = (user32.GetAsyncKeyState(0x01) & 0x8000) != 0 or (user32.GetAsyncKeyState(0x02) & 0x8000) != 0
        if is_down and not was_down:
            # Thread-safe cursor checking using Win32 API bounds to avoid Tkinter thread violations
            mouse_inside_sugg = False
            try:
                sugg_hwnd = gui.suggestion_win.root.winfo_id()
                if sugg_hwnd and user32.IsWindowVisible(sugg_hwnd):
                    class RECT(ctypes.Structure):
                        _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long), ("right", ctypes.c_long), ("bottom", ctypes.c_long)]
                    win_rect = RECT()
                    if user32.GetWindowRect(sugg_hwnd, ctypes.byref(win_rect)):
                        class POINT(ctypes.Structure):
                            _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]
                        pt = POINT()
                        user32.GetCursorPos(ctypes.byref(pt))
                        mouse_inside_sugg = (win_rect.left <= pt.x <= win_rect.right and win_rect.top <= pt.y <= win_rect.bottom)
            except Exception:
                pass
                
            if app.buffer and not mouse_inside_sugg:
                with app.lock:
                    app.debouncer.cancel_pending()
                    app.buffer = ""
                    app.suggestions = []
                    app.suggestions_for_text = ""
                    app.highlighted_index = 0
                    app.hide_suggestions()
        was_down = is_down
        
        # 2. Track focus shift & focused process name
        current_fg = user32.GetForegroundWindow()
        process_name = "None"
        
        if current_fg:
            pid = ctypes.c_ulong()
            user32.GetWindowThreadProcessId(current_fg, ctypes.byref(pid))
            PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
            kernel32 = ctypes.windll.kernel32
            h_process = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
            if not h_process:
                h_process = kernel32.OpenProcess(0x0400, False, pid)
            if h_process:
                try:
                    buffer = ctypes.create_unicode_buffer(512)
                    size = ctypes.c_ulong(512)
                    if kernel32.QueryFullProcessImageNameW(h_process, 0, buffer, ctypes.byref(size)):
                        import os
                        process_name = os.path.basename(buffer.value)
                except Exception:
                    pass
                finally:
                    kernel32.CloseHandle(h_process)
                    
        # Coordination with composition states
        if app.buffer:
            if app.active_hwnd is None:
                # Store focus when user starts typing
                app.active_hwnd = current_fg
                
            # Hide suggestions if focus changes to a different window (not our GUI window)
            if current_fg != app.active_hwnd and current_fg != app.gui_hwnd:
                with app.lock:
                    app.debouncer.cancel_pending()
                    app.buffer = ""
                    app.suggestions = []
                    app.suggestions_for_text = ""
                    app.highlighted_index = 0
                    app.hide_suggestions()
        else:
            # Update app.active_hwnd when not composing
            if current_fg != app.gui_hwnd:
                app.active_hwnd = current_fg
                
        # If active application changed, update Dashboard UI
        if process_name != last_process_name:
            last_process_name = process_name
            app.update_gui_status(active_app=process_name)
        time.sleep(0.05)

def create_tray_icon_image(width=64, height=64):
    """Load the Lipi IME logo from embedded base64 bytes for the system tray."""
    import base64
    from io import BytesIO
    ICON_BASE64 = "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"
    try:
        icon_data = base64.b64decode(ICON_BASE64)
        image = Image.open(BytesIO(icon_data))
        return image.resize((width, height), Image.Resampling.LANCZOS)
    except Exception:
        # Fallback to programmatically generated neon circle if something fails
        image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        dc = ImageDraw.Draw(image)
        dc.ellipse([4, 4, width - 5, height - 5], outline=(71, 167, 255, 100), width=6)
        dc.ellipse([14, 14, width - 15, height - 15], fill=(71, 167, 255, 255))
        return image

def setup_system_tray(app):
    """Initializes and runs the pystray system tray icon."""
    image = create_tray_icon_image()
    
    def on_show_dashboard(icon, item):
        app.gui_queue.put({"action": "show_gui"})
        
    def on_exit(icon, item):
        icon.stop()
        if app.hook_handler:
            try:
                app.hook_handler()
            except Exception:
                pass
        app.gui_queue.put({"action": "exit"})
        
    def toggle_active_action(icon, item):
        app.toggle_active()
        
    def set_lang(code):
        with app.lock:
            if app.lang_code == code:
                return
            app.lang_code = code
        app.save_user_prefs()
        app.update_gui_status()
        
    def toggle_sound(icon, item):
        with app.lock:
            app.sound_enabled = not app.sound_enabled
        app.save_user_prefs()
        app.update_gui_status()
        
    def toggle_offline(icon, item):
        with app.lock:
            app.offline_enabled = not app.offline_enabled
        app.save_user_prefs()
        app.update_gui_status()

    menu = pystray.Menu(
        pystray.MenuItem("Show Dashboard", on_show_dashboard, default=True),
        pystray.MenuItem("Active (Alt + T)", toggle_active_action, checked=lambda item: app.enabled),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Select Language", pystray.Menu(
            pystray.MenuItem("Bengali", lambda icon, item: set_lang("bn-t-i0-und"), checked=lambda item: app.lang_code == "bn-t-i0-und"),
            pystray.MenuItem("Hindi", lambda icon, item: set_lang("hi-t-i0-und"), checked=lambda item: app.lang_code == "hi-t-i0-und"),
            pystray.MenuItem("Arabic", lambda icon, item: set_lang("ar-t-i0-und"), checked=lambda item: app.lang_code == "ar-t-i0-und"),
            pystray.MenuItem("Nepali", lambda icon, item: set_lang("ne-t-i0-und"), checked=lambda item: app.lang_code == "ne-t-i0-und"),
            pystray.MenuItem("Urdu", lambda icon, item: set_lang("ur-t-i0-und"), checked=lambda item: app.lang_code == "ur-t-i0-und")
        )),
        pystray.MenuItem("Settings", pystray.Menu(
            pystray.MenuItem("Enable Sound Alerts", toggle_sound, checked=lambda item: app.sound_enabled),
            pystray.MenuItem("Offline Fallback Mode", toggle_offline, checked=lambda item: app.offline_enabled)
        )),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Exit IME", on_exit)
    )
    status_text = "Active" if app.enabled else "Disabled"
    icon = pystray.Icon("LipiIME", image, f"Lipi IME ({status_text})", menu)
    app.tray_icon = icon
    icon.run()

def main():
    # Single instance protection
    mutex_name = "Global\\LipiIME_SingleInstanceMutex"
    mutex = ctypes.windll.kernel32.CreateMutexW(None, False, mutex_name)
    if ctypes.windll.kernel32.GetLastError() == 183: # ERROR_ALREADY_EXISTS
        import tkinter as tk
        from tkinter import messagebox
        root = tk.Tk()
        root.withdraw()
        messagebox.showinfo("Lipi IME", "Lipi IME is already running! Check your system tray (taskbar corner).")
        sys.exit(0)
        
    gui_queue = queue.Queue()
    
    # Initialize coordinator
    app = TransliterationApp(gui_queue)
    
    # GUI Dashboard callbacks linking UI changes directly to core logic
    def on_toggle_active():
        app.toggle_active()
        
    def on_lang_change(lang_code):
        with app.lock:
            if app.lang_code == lang_code:
                return
            app.lang_code = lang_code
        app.save_user_prefs()
        app.update_gui_status()
        
    def on_debounce_change(val, save=True):
        with app.lock:
            new_delay = val / 1000.0
            if app.debounce_delay == new_delay:
                if save:
                    app.save_user_prefs()
                return
            app.debounce_delay = new_delay
        if save:
            app.save_user_prefs()
        
    def on_allow_websites_change(val):
        with app.lock:
            if app.allow_websites == val:
                return
            app.allow_websites = val
        app.save_user_prefs()
        app.update_gui_status()
        
    def on_font_size_change(val, save=True):
        changed = False
        with app.lock:
            if app.font_size != val:
                app.font_size = val
                changed = True
        if changed:
            gui_queue.put({
                "action": "update_font_size",
                "size": val
            })
        if save:
            app.save_user_prefs()
            
    def on_gui_select(index):
        app.commit_suggestion(index, suffix="", is_digit_select=True)
        
    def on_close():
        if app.hook_handler:
            try:
                app.hook_handler()
            except Exception:
                pass
        if hasattr(app, "tray_icon") and app.tray_icon:
            try:
                app.tray_icon.stop()
            except Exception:
                pass
        gui_queue.put({"action": "exit"})
        
    def on_theme_change(theme_name):
        with app.lock:
            app.theme_name = theme_name
        app.save_user_prefs()
        app.update_gui_status()
        
    def on_startup_change(enabled):
        with app.lock:
            app.startup = enabled
        try:
            set_startup_registry(enabled)
        except Exception:
            pass
        app.save_user_prefs()
        app.update_gui_status()
        
    def add_custom_word(key, val):
        with app.lock:
            app.custom_dict[key.lower()] = val
        app.save_custom_dict()
        
    def remove_custom_word(key):
        with app.lock:
            if key.lower() in app.custom_dict:
                del app.custom_dict[key.lower()]
        app.save_custom_dict()
        
    def get_custom_words():
        with app.lock:
            return dict(app.custom_dict)

    def clear_custom_words():
        with app.lock:
            app.custom_dict.clear()
        app.save_custom_dict()

    def on_offline_enabled_change(enabled):
        with app.lock:
            if app.offline_enabled == enabled:
                return
            app.offline_enabled = enabled
        app.save_user_prefs()
        app.update_gui_status()

    def on_online_mode_change(enabled):
        with app.lock:
            if app.online_mode == enabled:
                return
            app.online_mode = enabled
        app.save_user_prefs()
        app.update_gui_status()

    def on_sound_enabled_change(enabled):
        with app.lock:
            if app.sound_enabled == enabled:
                return
            app.sound_enabled = enabled
        app.save_user_prefs()
        app.update_gui_status()

    def on_opacity_change(val, save=True):
        changed = False
        with app.lock:
            if app.suggestion_opacity != val:
                app.suggestion_opacity = val
                changed = True
        if changed:
            gui_queue.put({
                "action": "update_opacity",
                "opacity": val
            })
        if save:
            app.save_user_prefs()

    callbacks = {
        "toggle_active": on_toggle_active,
        "lang_change": on_lang_change,
        "debounce_change": on_debounce_change,
        "allow_websites_change": on_allow_websites_change,
        "font_size_change": on_font_size_change,
        "gui_select": on_gui_select,
        "on_close": on_close,
        "theme_change": on_theme_change,
        "startup_change": on_startup_change,
        "add_custom_word": add_custom_word,
        "remove_custom_word": remove_custom_word,
        "clear_custom_words": clear_custom_words,
        "get_custom_words": get_custom_words,
        "online_mode_change": on_online_mode_change,
        "offline_enabled_change": on_offline_enabled_change,
        "sound_enabled_change": on_sound_enabled_change,
        "opacity_change": on_opacity_change,
        "save_prefs": app.save_user_prefs
    }
    
    # Sync startup registry to preferences
    try:
        set_startup_registry(app.startup)
    except Exception:
        pass
    
    # Initialize suggestion window
    gui = MainWindow(gui_queue, callbacks)
    app.gui_hwnd = gui.root.winfo_id()
    
    # Start keyboard hook with blocking / key suppression enabled
    app.hook_handler = keyboard.hook(app.on_key_event, suppress=True)
    
    # Send initial status update
    app.update_gui_status()
    
    # Start focus & mouse click polling thread
    threading.Thread(target=focus_and_mouse_poller, args=(app, gui), daemon=True).start()
    
    # Start system tray background thread
    threading.Thread(target=setup_system_tray, args=(app,), daemon=True).start()
    
    try:
        # Run Tkinter main loop (MainWindow)
        gui.run()
    finally:
        # Stop hook on exit
        if app.hook_handler:
            try:
                app.hook_handler()
            except Exception:
                pass

if __name__ == "__main__":
    main()
