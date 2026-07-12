import tkinter as tk
from tkinter import font
import customtkinter as ctk
import queue
import ctypes
from ctypes import byref, c_int

# Available languages mapping
LANGS = {
    "Bengali": "bn-t-i0-und",
    "Hindi": "hi-t-i0-und",
    "Arabic": "ar-t-i0-und",
    "Nepali": "ne-t-i0-und",
    "Urdu": "ur-t-i0-und"
}

THEMES = {
    "Dark": {
        "bg": "#111113",
        "card_bg": "#18181c",
        "border": "#2c2c36",
        "text": "#f0f0f5",
        "sub_text": "#8b8b9a",
        "accent": "#fd8459",
        "highlight_bg": "#1f1f2a",
        "enabled": "#ff4ec2",
        "disabled": "#ff3b30",
        "buffer_bg": "#1a1a24"
    },
    "Light": {
        "bg": "#ffffff",
        "card_bg": "#f5f5f7",
        "border": "#d2d2d7",
        "text": "#111113",
        "sub_text": "#86868b",
        "accent": "#ff4ec2",
        "highlight_bg": "#f0f0f2",
        "enabled": "#fd8459",
        "disabled": "#ef4444",
        "buffer_bg": "#e3e3e6"
    },
    "Neon Glow": {
        "bg": "#0f0f13",
        "card_bg": "#15151a",
        "border": "#ff4ec2",
        "text": "#ffffff",
        "sub_text": "#fd8459",
        "accent": "#ff4ec2",
        "highlight_bg": "#1c0d24",
        "enabled": "#fd8459",
        "disabled": "#ff073a",
        "buffer_bg": "#12081c"
    }
}

class SuggestionWindow:
    def __init__(self, parent, selection_callback):
        self.parent = parent
        self.selection_callback = selection_callback
        self.highlighted_index = 0
        self.candidates_count = 0
        self.opacity = 0.9
        
        # Initialize Toplevel window (child of MainWindow)
        self.root = tk.Toplevel(parent)
        self.root.title("Suggestions")
        
        # Make it frameless and always on top
        self.root.overrideredirect(True)
        self.root.wm_attributes("-topmost", True)
        self.root.wm_attributes("-toolwindow", True)
        
        # Styling
        self.bg_color = "#111113"         # Deep midnight dark background
        self.border_color = "#2c2c36"     # Card border
        self.text_color = "#f0f0f5"       # Active candidates text
        self.num_color = "#6c6c7c"        # Candidate index numbers
        self.highlight_bg = "#20202a"     # Hover/Select background
        self.accent_color = "#ff4ec2"     # Neon pink highlight accent
        self.buffer_bg = "#1a1a24"        # Buffer badge background
        
        self.root.configure(
            bg=self.bg_color, 
            highlightbackground=self.border_color, 
            highlightcolor=self.border_color, 
            highlightthickness=1
        )
        
        # Fonts
        self.main_font = font.Font(family="Segoe UI", size=11, weight="normal")
        self.bold_font = font.Font(family="Segoe UI", size=11, weight="bold")
        self.small_font = font.Font(family="Segoe UI", size=9, weight="bold")
        
        # Buffer Container & Label (Displays currently typed word)
        self.buffer_container = tk.Frame(self.root, bg=self.bg_color)
        self.buffer_container.pack(fill="x", padx=12, pady=(10, 6))
        
        self.buffer_label = tk.Label(
            self.buffer_container, 
            text="", 
            font=self.small_font, 
            fg=self.accent_color, 
            bg=self.buffer_bg,
            padx=8,
            pady=3,
            anchor="w"
        )
        self.buffer_label.pack(side="left")
        
        # Candidate List Containers (supporting up to 6 candidates)
        self.candidate_frames = []
        self.num_labels = []
        self.word_labels = []
        self.accent_indicators = []
        
        for i in range(6):
            frame = tk.Frame(self.root, bg=self.bg_color, cursor="hand2")
            frame.pack(fill="x", padx=6, pady=2)
            
            accent_ind = tk.Frame(frame, width=3, bg=self.bg_color)
            accent_ind.pack(side="left", fill="y")
            
            num_lbl = tk.Label(
                frame, 
                text=f"{i+1}.", 
                font=self.bold_font, 
                fg=self.num_color, 
                bg=self.bg_color,
                width=3,
                anchor="e"
            )
            num_lbl.pack(side="left", padx=(6, 10), pady=4)
            
            word_lbl = tk.Label(
                frame, 
                text="", 
                font=self.main_font, 
                fg=self.text_color, 
                bg=self.bg_color,
                anchor="w"
            )
            word_lbl.pack(side="left", fill="x", expand=True, padx=(0, 12), pady=4)
            
            # Binds
            idx = i
            frame.bind("<Button-1>", lambda event, val=idx: self.on_click(val))
            num_lbl.bind("<Button-1>", lambda event, val=idx: self.on_click(val))
            word_lbl.bind("<Button-1>", lambda event, val=idx: self.on_click(val))
            
            frame.bind("<Enter>", lambda event, val=idx: self.select_highlight(val))
            
            self.candidate_frames.append(frame)
            self.accent_indicators.append(accent_ind)
            self.num_labels.append(num_lbl)
            self.word_labels.append(word_lbl)
            
        self.root.withdraw()

    def enable_rounded_corners(self):
        """Enable rounded corners using Windows DWM API if on Windows 11."""
        try:
            dwmapi = ctypes.WinDLL("dwmapi")
            hwnd = self.root.winfo_id()
            dec = c_int(3)
            dwmapi.DwmSetWindowAttribute(c_int(hwnd), c_int(33), byref(dec), ctypes.sizeof(dec))
        except Exception:
            pass

    def on_click(self, index):
        self.selection_callback(index)
        
    def select_highlight(self, index):
        if self.candidates_count == 0 or index >= self.candidates_count:
            return
        self.highlighted_index = index
        for i in range(6):
            if i < self.candidates_count:
                if i == index:
                    self.candidate_frames[i].configure(bg=self.highlight_bg)
                    self.accent_indicators[i].configure(bg=self.accent_color)
                    self.num_labels[i].configure(bg=self.highlight_bg, fg=self.accent_color)
                    self.word_labels[i].configure(bg=self.highlight_bg)
                else:
                    self.candidate_frames[i].configure(bg=self.bg_color)
                    self.accent_indicators[i].configure(bg=self.bg_color)
                    self.num_labels[i].configure(bg=self.bg_color, fg=self.num_color)
                    self.word_labels[i].configure(bg=self.bg_color)

    def show(self, x, caret_top, caret_bottom, buffer_text, candidates, highlighted_index=0):
        if not candidates:
            self.hide()
            return
            
        self.last_x = x
        self.last_caret_top = caret_top
        self.last_caret_bottom = caret_bottom
        self.last_buffer_text = buffer_text
        self.last_candidates = candidates
        
        self.candidates_count = len(candidates)
        self.buffer_label.configure(text=f" {buffer_text.upper()} ")
        
        for i in range(6):
            if i < self.candidates_count:
                self.word_labels[i].configure(text=candidates[i])
                self.candidate_frames[i].pack(fill="x", padx=6, pady=2)
            else:
                self.candidate_frames[i].pack_forget()
                
        self.select_highlight(highlighted_index)
        self.root.update_idletasks()
        
        # Calculate requested size dynamically
        width = self.root.winfo_reqwidth() + 1
        height = self.root.winfo_reqheight()
        
        # Clamp width for aesthetic balance (maximum 450px)
        width = min(450, width)
        
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        
        target_y = caret_bottom + 4
        if target_y + height > screen_height:
            target_y = caret_top - height - 4
            
        target_x = x
        if target_x + width > screen_width:
            target_x = screen_width - width - 10
        if target_x < 0:
            target_x = 10
        if target_y < 0:
            target_y = 10
            
        self.root.geometry(f"{width}x{height}+{target_x}+{target_y}")
        self.root.deiconify()
        try:
            self.root.wm_attributes("-alpha", self.opacity)
        except Exception:
            pass
        self.enable_rounded_corners()

    def hide(self):
        self.candidates_count = 0
        self.root.withdraw()

    def is_mouse_inside(self):
        try:
            mx = self.root.winfo_pointerx()
            my = self.root.winfo_pointery()
            wx = self.root.winfo_x()
            wy = self.root.winfo_y()
            ww = self.root.winfo_width()
            wh = self.root.winfo_height()
            return wx <= mx <= wx + ww and wy <= my <= wy + wh
        except Exception:
            return False

    def set_opacity(self, opacity):
        self.opacity = opacity
        try:
            self.root.wm_attributes("-alpha", opacity)
        except Exception:
            pass

    def set_font_size(self, size):
        self.main_font.configure(size=size)
        self.bold_font.configure(size=size)
        self.small_font.configure(size=max(8, size - 2))
        
        try:
            if self.root.winfo_viewable() and hasattr(self, 'last_candidates') and self.last_candidates:
                self.show(
                    self.last_x,
                    self.last_caret_top,
                    self.last_caret_bottom,
                    self.last_buffer_text,
                    self.last_candidates,
                    self.highlighted_index
                )
        except Exception:
            pass

    def apply_theme(self, theme_name):
        colors = THEMES.get(theme_name, THEMES["Dark"])
        self.bg_color = colors["bg"]
        self.border_color = colors["border"]
        self.text_color = colors["text"]
        self.num_color = colors["sub_text"]
        self.highlight_bg = colors["highlight_bg"]
        self.accent_color = colors["accent"]
        self.buffer_bg = colors["buffer_bg"]
        
        self.root.configure(
            bg=self.bg_color, 
            highlightbackground=self.border_color, 
            highlightcolor=self.border_color,
            highlightthickness=1
        )
        
        self.buffer_container.configure(bg=self.bg_color)
        self.buffer_label.configure(bg=self.buffer_bg, fg=self.accent_color)
        
        for i in range(6):
            self.candidate_frames[i].configure(bg=self.bg_color)
            self.accent_indicators[i].configure(bg=self.bg_color)
            self.num_labels[i].configure(bg=self.bg_color, fg=self.num_color)
            self.word_labels[i].configure(bg=self.bg_color, fg=self.text_color)
            
        self.select_highlight(self.highlighted_index)


class LanguageNotificationWindow(tk.Toplevel):
    def __init__(self, parent):
        super().__init__(parent)
        self.overrideredirect(True)
        self.attributes("-topmost", True)
        self.attributes("-alpha", 0.5)
        self.withdraw()
        
        # Apply rounded corners using Windows DWM API
        try:
            dwmapi = ctypes.WinDLL("dwmapi")
            hwnd = self.winfo_id()
            dec = c_int(3)
            dwmapi.DwmSetWindowAttribute(c_int(hwnd), c_int(33), byref(dec), ctypes.sizeof(dec))
        except Exception:
            pass
            
        # Make the window click-through and non-focusable on Windows
        try:
            hwnd = self.winfo_id()
            GWL_EXSTYLE = -20
            WS_EX_NOACTIVATE = 0x08000000
            WS_EX_TRANSPARENT = 0x00000020
            
            style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
            style |= WS_EX_NOACTIVATE | WS_EX_TRANSPARENT
            ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style)
        except Exception:
            pass
            
        self.font = font.Font(family="Segoe UI", size=9, weight="bold")
        
        self.label = tk.Label(
            self,
            text="",
            font=self.font,
            padx=8,
            pady=4,
            bd=0
        )
        self.label.pack()
        
        self.hide_timer = None
        self.track_timer = None
        self.is_showing = False
        
    def show_language(self, language_name, colors, enabled=True):
        self.is_showing = True
        
        if self.hide_timer:
            self.after_cancel(self.hide_timer)
            self.hide_timer = None
        if self.track_timer:
            self.after_cancel(self.track_timer)
            self.track_timer = None
            
        # Configure look
        if enabled:
            bg_color = colors.get("accent", "#1a73e8")
        else:
            bg_color = colors.get("disabled", "#ff3b30")
        fg_color = "#ffffff"
        
        self.configure(bg=bg_color)
        self.label.configure(
            bg=bg_color,
            fg=fg_color,
            text=f"🌐 {language_name.upper()}"
        )
        
        # Initial position
        self.update_position()
        self.deiconify()
        self.lift()
        
        # Start mouse tracking loop
        self.track_mouse()
        
        # Auto-hide after 1 second (1000 ms)
        self.hide_timer = self.after(1000, self.hide)
        
    def update_position(self):
        try:
            # Position at current mouse coordinates offset by 15 pixels
            mx = self.winfo_pointerx()
            my = self.winfo_pointery()
            self.geometry(f"+{mx + 15}+{my + 15}")
        except Exception:
            pass
            
    def track_mouse(self):
        if not self.is_showing:
            return
        self.update_position()
        self.track_timer = self.after(10, self.track_mouse)
        
    def hide(self):
        self.is_showing = False
        if self.track_timer:
            self.after_cancel(self.track_timer)
            self.track_timer = None
        self.withdraw()
        self.hide_timer = None


class DictionaryManagerWindow(ctk.CTkToplevel):
    def __init__(self, parent, colors, add_callback, remove_callback, clear_callback, get_words_callback):
        super().__init__(parent)
        self.parent = parent
        self.colors = colors
        self.add_callback = add_callback
        self.remove_callback = remove_callback
        self.clear_callback = clear_callback
        self.get_words_callback = get_words_callback
        
        self.title("Custom Dictionary Manager")
        self.geometry("470x590")
        self.resizable(False, False)
        self.configure(fg_color=colors["bg"])
        self.transient(parent)
        self.grab_set()
        
        # Apply rounded corners using DWM API
        try:
            dwmapi = ctypes.WinDLL("dwmapi")
            hwnd = self.winfo_id()
            dec = c_int(3)
            dwmapi.DwmSetWindowAttribute(c_int(hwnd), c_int(33), byref(dec), ctypes.sizeof(dec))
        except Exception:
            pass
            
        # Apply window icon
        try:
            import os
            logo_ico_path = os.path.join(os.path.dirname(__file__), "logo.ico")
            if os.path.exists(logo_ico_path):
                self.iconbitmap(logo_ico_path)
        except Exception:
            pass
            
        self.title_font = ctk.CTkFont(family="Segoe UI", size=14, weight="bold")
        self.main_font = ctk.CTkFont(family="Segoe UI", size=11, weight="normal")
        self.bold_font = ctk.CTkFont(family="Segoe UI", size=11, weight="bold")
        
        # Header
        lbl = ctk.CTkLabel(self, text="Custom Dictionary Manager", font=self.title_font, text_color=colors["text"])
        lbl.pack(pady=(15, 10))
        
        # Input Frame
        input_frame = ctk.CTkFrame(self, fg_color="transparent")
        input_frame.pack(fill="x", padx=25, pady=8)
        
        lbl_key = ctk.CTkLabel(input_frame, text="English Input:", font=self.main_font, text_color=colors["sub_text"])
        lbl_key.grid(row=0, column=0, sticky="w", pady=6, padx=(0, 10))
        
        self.key_entry = ctk.CTkEntry(
            input_frame, 
            fg_color=colors["card_bg"], 
            text_color=colors["text"], 
            border_color=colors["border"], 
            border_width=1, 
            font=self.main_font,
            corner_radius=6
        )
        self.key_entry.grid(row=0, column=1, sticky="we", padx=(10, 0), pady=6)
        
        lbl_val = ctk.CTkLabel(input_frame, text="Native Value:", font=self.main_font, text_color=colors["sub_text"])
        lbl_val.grid(row=1, column=0, sticky="w", pady=6, padx=(0, 10))
        
        self.val_entry = ctk.CTkEntry(
            input_frame, 
            fg_color=colors["card_bg"], 
            text_color=colors["text"], 
            border_color=colors["border"], 
            border_width=1, 
            font=self.main_font,
            corner_radius=6
        )
        self.val_entry.grid(row=1, column=1, sticky="we", padx=(10, 0), pady=6)
        
        input_frame.columnconfigure(1, weight=1)
        
        # Add Button
        self.add_btn = ctk.CTkButton(
            self, 
            text="Add Word Mapping", 
            font=self.bold_font, 
            fg_color=colors["accent"], 
            hover_color=colors["accent"], 
            text_color="#ffffff", 
            corner_radius=6,
            command=self.on_add
        )
        self.add_btn.pack(pady=12)
        
        # Separator line
        sep = ctk.CTkFrame(self, height=1, fg_color=colors["border"])
        sep.pack(fill="x", padx=25, pady=8)
        
        # Search Box
        search_frame = ctk.CTkFrame(self, fg_color="transparent")
        search_frame.pack(fill="x", padx=25, pady=8)
        
        lbl_search = ctk.CTkLabel(search_frame, text="Search Mappings:", font=self.main_font, text_color=colors["sub_text"])
        lbl_search.pack(side="left", padx=(0, 10))
        
        self.search_var = tk.StringVar()
        self.search_var.trace_add("write", lambda *args: self.populate_list())
        
        self.search_entry = ctk.CTkEntry(
            search_frame, 
            textvariable=self.search_var, 
            fg_color=colors["card_bg"], 
            text_color=colors["text"], 
            border_color=colors["border"], 
            border_width=1, 
            font=self.main_font,
            corner_radius=6
        )
        self.search_entry.pack(side="right", fill="x", expand=True, padx=(10, 0))
        
        # Listbox Frame
        list_frame = ctk.CTkFrame(self, fg_color="transparent")
        list_frame.pack(fill="both", expand=True, padx=25, pady=12)
        
        self.scrollbar = ctk.CTkScrollbar(list_frame)
        self.scrollbar.pack(side="right", fill="y", padx=(8, 0))
        
        self.listbox = tk.Listbox(
            list_frame, 
            bg=colors["card_bg"], 
            fg=colors["text"], 
            selectbackground=colors["accent"], 
            selectforeground="#ffffff",
            bd=0, 
            font=self.main_font,
            yscrollcommand=self.scrollbar.set,
            highlightthickness=0,
            height=6
        )
        self.listbox.pack(side="left", fill="both", expand=True)
        self.scrollbar.configure(command=self.listbox.yview)
        
        # Action Buttons Frame
        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.pack(pady=12)
        
        self.del_btn = ctk.CTkButton(
            btn_frame, 
            text="Delete Selected Mapping", 
            font=self.bold_font, 
            fg_color="#d9534f", 
            hover_color="#c9302c", 
            text_color="#ffffff", 
            corner_radius=6,
            command=self.on_delete
        )
        self.del_btn.pack(side="left", padx=8)
        
        self.clear_btn = ctk.CTkButton(
            btn_frame, 
            text="Clear All Mappings", 
            font=self.bold_font, 
            fg_color="#d9534f", 
            hover_color="#c9302c", 
            text_color="#ffffff", 
            corner_radius=6,
            command=self.on_clear_all
        )
        self.clear_btn.pack(side="right", padx=8)
        
        # Backup Action Buttons Frame
        backup_frame = ctk.CTkFrame(self, fg_color="transparent")
        backup_frame.pack(pady=(0, 20))
        
        self.import_btn = ctk.CTkButton(
            backup_frame, 
            text="Import Backup (JSON)", 
            font=self.bold_font, 
            fg_color=colors["accent"], 
            hover_color=colors["accent"], 
            text_color="#ffffff", 
            corner_radius=6,
            command=self.on_import
        )
        self.import_btn.pack(side="left", padx=8)
        
        self.export_btn = ctk.CTkButton(
            backup_frame, 
            text="Export Backup (JSON)", 
            font=self.bold_font, 
            fg_color=colors["accent"], 
            hover_color=colors["accent"], 
            text_color="#ffffff", 
            corner_radius=6,
            command=self.on_export
        )
        self.export_btn.pack(side="right", padx=8)
        
        self.populate_list()
        
    def populate_list(self):
        self.listbox.delete(0, tk.END)
        words = self.get_words_callback()
        search_q = self.search_var.get().lower().strip()
        
        self.items_list = []
        for key in sorted(words.keys()):
            val = words[key]
            if not search_q or search_q in key.lower() or search_q in val.lower():
                self.listbox.insert(tk.END, f" {key}  -->  {val} ")
                self.items_list.append((key, val))
                
    def on_add(self):
        key = self.key_entry.get().strip().lower()
        val = self.val_entry.get().strip()
        if not key or not val:
            return
        
        self.add_callback(key, val)
        self.key_entry.delete(0, tk.END)
        self.val_entry.delete(0, tk.END)
        self.populate_list()
        
    def on_delete(self):
        sel = self.listbox.curselection()
        if not sel:
            return
        idx = sel[0]
        if idx < len(self.items_list):
            key, val = self.items_list[idx]
            self.remove_callback(key)
            self.populate_list()

    def on_clear_all(self):
        from tkinter import messagebox
        if messagebox.askyesno("Confirm Clear", "Are you sure you want to delete all custom dictionary mappings?", parent=self):
            self.clear_callback()
            self.populate_list()

    def on_import(self):
        from tkinter import filedialog, messagebox
        import json
        file_path = filedialog.askopenfilename(
            parent=self,
            title="Import Custom Dictionary Backup",
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")]
        )
        if not file_path:
            return
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if not isinstance(data, dict):
                raise ValueError("Backup file must be a JSON object containing key-value mappings.")
                
            clean_data = {}
            for k, v in data.items():
                if not isinstance(k, str) or not isinstance(v, str):
                    raise ValueError("All dictionary keys and values must be text strings.")
                clean_data[k.strip().lower()] = v.strip()
                
            if not clean_data:
                messagebox.showinfo("Imported", "No valid mappings found in the backup file.", parent=self)
                return
                
            choice = messagebox.askyesnocancel(
                "Import Options",
                "Do you want to MERGE the imported mappings with your existing ones?\n\n- Click YES to MERGE.\n- Click NO to OVERWRITE (deletes existing first).\n- Click CANCEL to abort.",
                parent=self
            )
            if choice is None:
                return
                
            if choice is False:
                self.clear_callback()
                
            for k, v in clean_data.items():
                self.add_callback(k, v)
                
            self.populate_list()
            messagebox.showinfo("Import Success", f"Successfully imported {len(clean_data)} mappings!", parent=self)
        except Exception as e:
            messagebox.showerror("Import Error", f"Failed to import backup:\n{e}", parent=self)

    def on_export(self):
        from tkinter import filedialog, messagebox
        import json
        words = self.get_words_callback()
        if not words:
            messagebox.showwarning("Export Empty", "Your custom dictionary is empty. Nothing to export.", parent=self)
            return
            
        file_path = filedialog.asksaveasfilename(
            parent=self,
            title="Export Custom Dictionary Backup",
            defaultextension=".json",
            initialfile="custom_dict_backup.json",
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")]
        )
        if not file_path:
            return
        try:
            with open(file_path, "w", encoding="utf-8") as f:
                json.dump(words, f, ensure_ascii=False, indent=4)
            messagebox.showinfo("Export Success", f"Successfully exported {len(words)} mappings to:\n{file_path}", parent=self)
        except Exception as e:
            messagebox.showerror("Export Error", f"Failed to export backup:\n{e}", parent=self)


class MainWindow:
    """Dashboard and Settings Control Panel main GUI."""
    def __init__(self, update_queue, callbacks):
        self.queue = update_queue
        self.callbacks = callbacks
        
        self.lang_map_rev = {v: k for k, v in LANGS.items()}
        
        # Register AppUserModelID on Windows to show the custom taskbar icon
        try:
            import ctypes
            myappid = 'lipi.transliteration.ime.v1'
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)
        except Exception:
            pass

        # Initialize CustomTkinter Window
        self.root = ctk.CTk()
        self.root.title("Lipi IME Dashboard")
        self.root.geometry("580x550")
        self.root.resizable(False, False)
        
        # Load and set application icon
        try:
            import os
            from PIL import Image, ImageTk
            dir_path = os.path.dirname(__file__)
            logo_png_path = os.path.join(dir_path, "LIPI LOGO.png")
            logo_ico_path = os.path.join(dir_path, "logo.ico")
            
            # Generate logo.ico from LIPI LOGO.png if missing (Windows needs .ico for native window/taskbar icon)
            if os.path.exists(logo_png_path) and not os.path.exists(logo_ico_path):
                img = Image.open(logo_png_path)
                img.save(logo_ico_path, format="ICO")
            
            if os.path.exists(logo_ico_path):
                self.root.iconbitmap(logo_ico_path)
            elif os.path.exists(logo_png_path):
                self.icon_image = Image.open(logo_png_path)
                self.icon_photo = ImageTk.PhotoImage(self.icon_image)
                self.root.iconphoto(True, self.icon_photo)
            else:
                import base64
                from io import BytesIO
                ICON_BASE64 = "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"
                icon_data = base64.b64decode(ICON_BASE64)
                self.icon_image = Image.open(BytesIO(icon_data))
                self.icon_photo = ImageTk.PhotoImage(self.icon_image)
                self.root.iconphoto(True, self.icon_photo)
        except Exception:
            pass
            
        self.current_theme = "Dark"
        self.last_status_enabled = False
        
        # Colors
        self.bg_color = "#101014"         # Charcoal background
        self.card_bg = "#181822"          # Lighter box background
        self.border_color = "#2c2c36"     # Slate borders
        self.text_color = "#f0f0f5"       # White text
        self.sub_text_color = "#8b8b9a"   # Muted gray text
        self.accent_color = "#47a7ff"     # Neon blue accent
        self.highlight_bg = "#1f1f2a"     # Menu hover background
        self.enabled_color = "#00ff88"    # Neon green
        self.disabled_color = "#ff3b30"   # Neon red
        
        self.root.configure(fg_color=self.bg_color)
        
        # Fonts (Using CTk fonts)
        self.title_font = ctk.CTkFont(family="Segoe UI", size=14, weight="bold")
        self.main_font = ctk.CTkFont(family="Segoe UI", size=11, weight="normal")
        self.bold_font = ctk.CTkFont(family="Segoe UI", size=11, weight="bold")
        self.small_font = ctk.CTkFont(family="Segoe UI", size=9, weight="normal")
        
        # Apply rounded corners using DWM API
        self.enable_rounded_corners()
        
        # 1. Left Frame - Dashboard & Status Info
        self.left_frame = ctk.CTkFrame(
            self.root, 
            width=240,
            height=510,
            fg_color=self.card_bg, 
            border_color=self.border_color, 
            border_width=1, 
            corner_radius=12
        )
        self.left_frame.pack_propagate(False)
        self.left_frame.place(x=20, y=20)
        
        # Load and display logo image
        self.logo_image = None
        self.logo_lbl = None
        try:
            import os
            logo_path = os.path.join(os.path.dirname(__file__), "LIPI LOGO.png")
            if os.path.exists(logo_path):
                logo_img = Image.open(logo_path)
                self.logo_image = ctk.CTkImage(light_image=logo_img, dark_image=logo_img, size=(80, 80))
                self.logo_lbl = ctk.CTkLabel(self.left_frame, image=self.logo_image, text="")
                self.logo_lbl.pack(pady=(20, 0))
        except Exception:
            pass
            
        # Glowing state canvas (status indicator)
        self.status_canvas = tk.Canvas(self.left_frame, width=150, height=70, bg=self.card_bg, highlightthickness=0)
        self.status_canvas.pack(pady=(10, 10))
        
        self.status_dot = self.status_canvas.create_oval(15, 25, 35, 45, fill=self.disabled_color, outline="")
        self.status_text_lbl = self.status_canvas.create_text(85, 35, text="DISABLED", font=("Segoe UI", 12, "bold"), fill=self.disabled_color, anchor="w")
        
        # Activate/Deactivate Button
        self.toggle_btn = ctk.CTkButton(
            self.left_frame, 
            text="Activate IME", 
            font=self.bold_font, 
            fg_color="#5cb85c", 
            hover_color="#4cae4c",
            text_color="#ffffff",
            corner_radius=8,
            command=self.callbacks["toggle_active"]
        )
        self.toggle_btn.pack(pady=15, padx=20, fill="x")
        
        # Active Language Label Box
        self.lang_title_lbl = ctk.CTkLabel(self.left_frame, text="ACTIVE LANGUAGE", font=self.small_font, text_color=self.sub_text_color)
        self.lang_title_lbl.pack(pady=(25, 5))
        
        self.lang_display_lbl = ctk.CTkLabel(self.left_frame, text="Bengali", font=self.title_font, text_color=self.accent_color)
        self.lang_display_lbl.pack(pady=(0, 25))
        
        # Online Mode Toggle
        self.online_mode_var = tk.BooleanVar(value=True)
        self.online_mode_switch = ctk.CTkSwitch(
            self.left_frame, 
            text="Online Mode", 
            font=self.bold_font,
            text_color=self.text_color,
            progress_color=self.accent_color,
            variable=self.online_mode_var,
            onvalue=True,
            offvalue=False,
            command=self.on_online_mode_change
        )
        self.online_mode_switch.pack(pady=(0, 10))
        
        # Shortcut info
        shortcut_frame = ctk.CTkFrame(self.left_frame, fg_color="transparent")
        shortcut_frame.pack(side="bottom", pady=25)
        
        self.shortcut_lbl = ctk.CTkLabel(shortcut_frame, text="IME Toggle: Alt + T", font=self.small_font, text_color=self.sub_text_color)
        self.shortcut_lbl.pack()
        
        self.shortcut_lang_lbl = ctk.CTkLabel(shortcut_frame, text="Language Cycle: Alt + L", font=self.small_font, text_color=self.sub_text_color)
        self.shortcut_lang_lbl.pack()
        
        # 2. Right Frame - Settings Panel (CTkScrollableFrame to scroll through all options cleanly)
        self.right_frame = ctk.CTkScrollableFrame(
            self.root, 
            width=254, 
            height=510, 
            fg_color="transparent"
        )
        self.right_frame.place(x=280, y=20)
        
        self.settings_title_lbl = ctk.CTkLabel(self.right_frame, text="IME Settings", font=self.title_font, text_color=self.text_color)
        self.settings_title_lbl.pack(anchor="w", pady=(0, 15))
        
        # Target Application Tracking Label
        self.app_title_lbl = ctk.CTkLabel(self.right_frame, text="ACTIVE APPLICATION", font=self.small_font, text_color=self.sub_text_color)
        self.app_title_lbl.pack(anchor="w", pady=(5, 2))
        
        self.app_display_lbl = ctk.CTkLabel(self.right_frame, text="None focused", font=self.bold_font, text_color=self.text_color)
        self.app_display_lbl.pack(anchor="w", pady=(0, 15))
        
        # Dropdowns side-by-side frame
        dropdowns_frame = ctk.CTkFrame(self.right_frame, fg_color="transparent")
        dropdowns_frame.pack(fill="x", pady=(0, 15))
        
        lang_col = ctk.CTkFrame(dropdowns_frame, fg_color="transparent")
        lang_col.pack(side="left", fill="x", expand=True, padx=(0, 8))
        
        self.lang_label_lbl = ctk.CTkLabel(lang_col, text="LANGUAGE", font=self.small_font, text_color=self.sub_text_color)
        self.lang_label_lbl.pack(anchor="w", pady=(0, 4))
        
        self.lang_var = tk.StringVar(value="Bengali")
        self.lang_menu = ctk.CTkOptionMenu(
            lang_col, 
            values=list(LANGS.keys()),
            variable=self.lang_var,
            command=self.on_lang_menu_change,
            font=self.main_font,
            dropdown_font=self.main_font,
            corner_radius=6
        )
        self.lang_menu.pack(fill="x")
        
        # Right dropdown: Theme Select
        theme_col = ctk.CTkFrame(dropdowns_frame, fg_color="transparent")
        theme_col.pack(side="right", fill="x", expand=True, padx=(8, 0))
        
        self.theme_label_lbl = ctk.CTkLabel(theme_col, text="THEME", font=self.small_font, text_color=self.sub_text_color)
        self.theme_label_lbl.pack(anchor="w", pady=(0, 4))
        
        self.theme_var = tk.StringVar(value="Dark")
        self.theme_menu = ctk.CTkOptionMenu(
            theme_col, 
            values=list(THEMES.keys()),
            variable=self.theme_var,
            command=self.on_theme_menu_change,
            font=self.main_font,
            dropdown_font=self.main_font,
            corner_radius=6
        )
        self.theme_menu.pack(fill="x")
        
        # Debounce Delay Config Slider
        debounce_title_frame = ctk.CTkFrame(self.right_frame, fg_color="transparent")
        debounce_title_frame.pack(fill="x", pady=(8, 0))
        
        self.debounce_lbl = ctk.CTkLabel(debounce_title_frame, text="DEBOUNCE DELAY", font=self.small_font, text_color=self.sub_text_color)
        self.debounce_lbl.pack(side="left")
        
        self.debounce_val_lbl = ctk.CTkLabel(debounce_title_frame, text="70 ms", font=self.small_font, text_color=self.accent_color)
        self.debounce_val_lbl.pack(side="right")
        
        self.debounce_slider = ctk.CTkSlider(
            self.right_frame,
            from_=50,
            to=200,
            command=self.on_debounce_slider_change
        )
        self.debounce_slider.set(70) # Default
        self.debounce_slider.pack(fill="x", pady=(4, 10))
        self.debounce_slider.bind("<ButtonRelease-1>", self.on_debounce_slider_release)
        self.debounce_slider.bind("<KeyRelease>", self.on_debounce_slider_release)
        
        # Suggestion Font Size Slider
        font_size_title_frame = ctk.CTkFrame(self.right_frame, fg_color="transparent")
        font_size_title_frame.pack(fill="x", pady=(8, 0))
        
        self.font_size_lbl = ctk.CTkLabel(font_size_title_frame, text="SUGGESTION FONT SIZE", font=self.small_font, text_color=self.sub_text_color)
        self.font_size_lbl.pack(side="left")
        
        self.font_size_val_lbl = ctk.CTkLabel(font_size_title_frame, text="11 px", font=self.small_font, text_color=self.accent_color)
        self.font_size_val_lbl.pack(side="right")
        
        self.font_size_slider = ctk.CTkSlider(
            self.right_frame,
            from_=9,
            to=18,
            command=self.on_font_size_slider_change
        )
        self.font_size_slider.set(11) # Default
        self.font_size_slider.pack(fill="x", pady=(4, 10))
        self.font_size_slider.bind("<ButtonRelease-1>", self.on_font_size_slider_release)
        self.font_size_slider.bind("<KeyRelease>", self.on_font_size_slider_release)
        
        # Suggestion Opacity Slider
        opacity_title_frame = ctk.CTkFrame(self.right_frame, fg_color="transparent")
        opacity_title_frame.pack(fill="x", pady=(8, 0))
        
        self.opacity_lbl = ctk.CTkLabel(opacity_title_frame, text="SUGGESTION OPACITY", font=self.small_font, text_color=self.sub_text_color)
        self.opacity_lbl.pack(side="left")
        
        self.opacity_val_lbl = ctk.CTkLabel(opacity_title_frame, text="90 %", font=self.small_font, text_color=self.accent_color)
        self.opacity_val_lbl.pack(side="right")
        
        self.opacity_slider = ctk.CTkSlider(
            self.right_frame,
            from_=50,
            to=100,
            command=self.on_opacity_slider_change
        )
        self.opacity_slider.set(90) # Default
        self.opacity_slider.pack(fill="x", pady=(4, 10))
        self.opacity_slider.bind("<ButtonRelease-1>", self.on_opacity_slider_release)
        self.opacity_slider.bind("<KeyRelease>", self.on_opacity_slider_release)
        
        # Checkboxes container
        checkbox_frame = ctk.CTkFrame(self.right_frame, fg_color="transparent")
        checkbox_frame.pack(fill="x", pady=(10, 0))
        
        # Checkbox: Enable/Disable inside websites
        self.allow_websites_var = tk.BooleanVar(value=False)
        self.allow_websites_cb = ctk.CTkCheckBox(
            checkbox_frame,
            text="Allow inside Browser Websites",
            variable=self.allow_websites_var,
            onvalue=True,
            offvalue=False,
            font=self.main_font,
            corner_radius=4,
            command=self.on_allow_websites_change
        )
        self.allow_websites_cb.pack(fill="x", pady=5)
        
        # Checkbox: Run on Startup
        self.startup_var = tk.BooleanVar(value=False)
        self.startup_cb = ctk.CTkCheckBox(
            checkbox_frame,
            text="Run on Windows Startup",
            variable=self.startup_var,
            onvalue=True,
            offvalue=False,
            font=self.main_font,
            corner_radius=4,
            command=self.on_startup_change
        )
        self.startup_cb.pack(fill="x", pady=5)
        
        # Checkbox: Enable Offline Mode
        self.offline_enabled_var = tk.BooleanVar(value=True)
        self.offline_enabled_cb = ctk.CTkCheckBox(
            checkbox_frame,
            text="Enable Offline Mode (Cache & Dict)",
            variable=self.offline_enabled_var,
            onvalue=True,
            offvalue=False,
            font=self.main_font,
            corner_radius=4,
            command=self.on_offline_enabled_change
        )
        self.offline_enabled_cb.pack(fill="x", pady=5)
        
        # Checkbox: Enable Sound Alerts
        self.sound_enabled_var = tk.BooleanVar(value=True)
        self.sound_enabled_cb = ctk.CTkCheckBox(
            checkbox_frame,
            text="Enable Sound Beeps / Alerts",
            variable=self.sound_enabled_var,
            onvalue=True,
            offvalue=False,
            font=self.main_font,
            corner_radius=4,
            command=self.on_sound_enabled_change
        )
        self.sound_enabled_cb.pack(fill="x", pady=5)
        
        # Status Label: Offline Support Info
        self.offline_status_lbl = ctk.CTkLabel(
            checkbox_frame,
            text="Offline supported for: bn, hi, ar, ne, ur",
            font=self.small_font,
            text_color=self.sub_text_color,
            anchor="w"
        )
        self.offline_status_lbl.pack(fill="x", pady=(2, 8))
        
        # Button: Manage Custom Dictionary
        self.manage_dict_btn = ctk.CTkButton(
            self.right_frame,
            text="Manage Custom Dictionary",
            font=self.bold_font,
            corner_radius=8,
            command=self.open_dictionary_manager
        )
        self.manage_dict_btn.pack(fill="x", pady=(12, 0))
        
        # Button: About & Help
        self.about_btn = ctk.CTkButton(
            self.right_frame,
            text="About & Help",
            font=self.bold_font,
            corner_radius=8,
            command=self.open_about_window
        )
        self.about_btn.pack(fill="x", pady=(12, 0))
        
        # Initialize Toplevel Suggestion overlay
        self.suggestion_win = SuggestionWindow(self.root, callbacks["gui_select"])
        
        # Initialize Language Notification popup
        self.lang_notifier = LanguageNotificationWindow(self.root)
        
        # Bind close handler to safely exit background threads
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)
        
        # Queue Poller loop
        self.root.after(20, self.poll_queue)

    def enable_rounded_corners(self):
        """Enable rounded corners using Windows DWM API if on Windows 11."""
        try:
            dwmapi = ctypes.WinDLL("dwmapi")
            hwnd = self.root.winfo_id()
            dec = c_int(3)
            dwmapi.DwmSetWindowAttribute(c_int(hwnd), c_int(33), byref(dec), ctypes.sizeof(dec))
        except Exception:
            pass

    def on_lang_menu_change(self, val):
        lang_code = LANGS[val]
        self.callbacks["lang_change"](lang_code)

    def on_theme_menu_change(self, val):
        self.callbacks["theme_change"](val)

    def on_startup_change(self):
        val = self.startup_var.get()
        self.callbacks["startup_change"](val)

    def on_debounce_slider_change(self, val):
        self.debounce_val_lbl.configure(text=f"{int(val)} ms")

    def on_debounce_slider_release(self, event):
        val = int(self.debounce_slider.get())
        self.callbacks["debounce_change"](val, save=True)

    def on_allow_websites_change(self):
        val = self.allow_websites_var.get()
        self.callbacks["allow_websites_change"](val)

    def on_font_size_slider_change(self, val):
        self.font_size_val_lbl.configure(text=f"{int(val)} px")

    def on_font_size_slider_release(self, event):
        val = int(self.font_size_slider.get())
        self.callbacks["font_size_change"](val, save=True)

    def on_opacity_slider_change(self, val):
        self.opacity_val_lbl.configure(text=f"{int(val)} %")

    def on_opacity_slider_release(self, event):
        val = int(self.opacity_slider.get())
        self.callbacks["opacity_change"](val / 100.0, save=True)

    def on_offline_enabled_change(self):
        val = self.offline_enabled_var.get()
        self.callbacks["offline_enabled_change"](val)

    def on_sound_enabled_change(self):
        val = self.sound_enabled_var.get()
        self.callbacks["sound_enabled_change"](val)

    def on_online_mode_change(self):
        val = self.online_mode_var.get()
        self.callbacks["online_mode_change"](val)

    def open_dictionary_manager(self):
        colors = THEMES.get(self.current_theme, THEMES["Dark"])
        DictionaryManagerWindow(
            self.root, 
            colors, 
            add_callback=self.callbacks["add_custom_word"], 
            remove_callback=self.callbacks["remove_custom_word"],
            clear_callback=self.callbacks["clear_custom_words"],
            get_words_callback=self.callbacks["get_custom_words"]
        )

    def open_about_window(self):
        about_win = ctk.CTkToplevel(self.root)
        about_win.title("About & Instructions")
        about_win.geometry("500x400")
        about_win.configure(fg_color=self.bg_color)
        about_win.transient(self.root)
        about_win.grab_set()
        
        try:
            import os
            logo_ico_path = os.path.join(os.path.dirname(__file__), "logo.ico")
            if os.path.exists(logo_ico_path):
                about_win.after(200, lambda: about_win.iconbitmap(logo_ico_path))
        except Exception:
            pass
        
        # Title
        title_lbl = ctk.CTkLabel(about_win, text="Lipi IME - Google Input Tools Alternative", font=self.bold_font, text_color=self.accent_color)
        title_lbl.pack(pady=(20, 10))
        
        # Instructions
        instructions = (
            "Instructions:\n\n"
            "• To activate or deactivate typing, press ALT+T anywhere.\n"
            "• Use the UP/DOWN arrow keys to navigate suggestions.\n"
            "• Press numbers (1-5) or use the mouse to select a specific word.\n"
            "• Press Space or Enter to select the highlighted word.\n"
            "• Add custom words in the Dictionary Manager to prioritize them."
        )
        inst_lbl = ctk.CTkLabel(about_win, text=instructions, font=self.main_font, text_color=self.text_color, justify="left")
        inst_lbl.pack(padx=20, pady=10, anchor="w")
        
        # Report issue
        issue_lbl = ctk.CTkLabel(about_win, text="Found a bug or have suggestions?\nPlease report it to:", font=self.main_font, text_color=self.sub_text_color)
        issue_lbl.pack(pady=(20, 5))
        
        email_lbl = ctk.CTkLabel(about_win, text="savvystaks@gmail.com", font=("Segoe UI", 12, "bold"), text_color="#47a7ff", cursor="hand2")
        email_lbl.pack()
        
        # Click email to copy or open mailto
        def open_email(e):
            import webbrowser
            webbrowser.open("mailto:savvystaks@gmail.com")
            
        email_lbl.bind("<Button-1>", open_email)
        
        # Close button
        close_btn = ctk.CTkButton(about_win, text="Close", font=self.bold_font, corner_radius=8, command=about_win.destroy)
        close_btn.pack(pady=(20, 20))

    def apply_theme(self, theme_name):
        self.current_theme = theme_name
        colors = THEMES.get(theme_name, THEMES["Dark"])
        
        # Set CustomTkinter appearance mode
        if theme_name == "Light":
            ctk.set_appearance_mode("light")
        else:
            ctk.set_appearance_mode("dark")
            
        self.bg_color = colors["bg"]
        self.card_bg = colors["card_bg"]
        self.border_color = colors["border"]
        self.text_color = colors["text"]
        self.sub_text_color = colors["sub_text"]
        self.accent_color = colors["accent"]
        self.highlight_bg = colors["highlight_bg"]
        self.enabled_color = colors["enabled"]
        self.disabled_color = colors["disabled"]
        
        # 1. Main Window Background
        self.root.configure(fg_color=self.bg_color)
        
        # 2. Frames background and border configuration
        self.left_frame.configure(fg_color=self.card_bg, border_color=self.border_color)
        self.right_frame.configure(
            fg_color="transparent",
            scrollbar_button_color=self.highlight_bg,
            scrollbar_button_hover_color=self.accent_color
        )
        
        # 3. Canvas Config
        self.status_canvas.configure(bg=self.card_bg)
        self.update_status_led()
        
        # 4. Label Colors
        self.lang_title_lbl.configure(text_color=self.sub_text_color)
        self.lang_display_lbl.configure(text_color=self.accent_color)
        self.shortcut_lbl.configure(text_color=self.sub_text_color)
        self.shortcut_lang_lbl.configure(text_color=self.sub_text_color)
        self.settings_title_lbl.configure(text_color=self.text_color)
        self.app_title_lbl.configure(text_color=self.sub_text_color)
        self.app_display_lbl.configure(text_color=self.text_color)
        self.lang_label_lbl.configure(text_color=self.sub_text_color)
        self.theme_label_lbl.configure(text_color=self.sub_text_color)
        self.debounce_lbl.configure(text_color=self.sub_text_color)
        self.debounce_val_lbl.configure(text_color=self.accent_color)
        self.font_size_lbl.configure(text_color=self.sub_text_color)
        self.font_size_val_lbl.configure(text_color=self.accent_color)
        self.opacity_lbl.configure(text_color=self.sub_text_color)
        self.opacity_val_lbl.configure(text_color=self.accent_color)
        self.offline_status_lbl.configure(text_color=self.sub_text_color)
        
        # 5. Buttons Styling
        self.manage_dict_btn.configure(
            fg_color=self.highlight_bg,
            hover_color=self.border_color,
            text_color=self.text_color
        )
        
        # 6. OptionMenus Styling
        self.lang_menu.configure(
            fg_color=self.highlight_bg,
            text_color=self.text_color,
            button_color=self.highlight_bg,
            button_hover_color=self.border_color,
            dropdown_fg_color=self.highlight_bg,
            dropdown_text_color=self.text_color,
            dropdown_hover_color=self.accent_color
        )
        self.theme_menu.configure(
            fg_color=self.highlight_bg,
            text_color=self.text_color,
            button_color=self.highlight_bg,
            button_hover_color=self.border_color,
            dropdown_fg_color=self.highlight_bg,
            dropdown_text_color=self.text_color,
            dropdown_hover_color=self.accent_color
        )
        
        # 7. Sliders Styling
        self.debounce_slider.configure(
            fg_color=self.highlight_bg,
            progress_color=self.accent_color,
            button_color=self.accent_color,
            button_hover_color=self.accent_color
        )
        self.font_size_slider.configure(
            fg_color=self.highlight_bg,
            progress_color=self.accent_color,
            button_color=self.accent_color,
            button_hover_color=self.accent_color
        )
        self.opacity_slider.configure(
            fg_color=self.highlight_bg,
            progress_color=self.accent_color,
            button_color=self.accent_color,
            button_hover_color=self.accent_color
        )
        
        # 8. Checkboxes Styling
        self.allow_websites_cb.configure(
            text_color=self.text_color,
            fg_color=self.accent_color,
            hover_color=self.border_color
        )
        self.startup_cb.configure(
            text_color=self.text_color,
            fg_color=self.accent_color,
            hover_color=self.border_color
        )
        self.offline_enabled_cb.configure(
            text_color=self.text_color,
            fg_color=self.accent_color,
            hover_color=self.border_color
        )
        self.sound_enabled_cb.configure(
            text_color=self.text_color,
            fg_color=self.accent_color,
            hover_color=self.border_color
        )
        
        # 9. Suggestion Window Styling
        self.suggestion_win.apply_theme(theme_name)

    def update_status_led(self):
        enabled = self.last_status_enabled
        colors = THEMES.get(self.current_theme, THEMES["Dark"])
        dot_color = colors["enabled"] if enabled else colors["disabled"]
        text_val = "ENABLED" if enabled else "DISABLED"
        
        self.status_canvas.itemconfig(self.status_dot, fill=dot_color)
        self.status_canvas.itemconfig(self.status_text_lbl, text=text_val, fill=dot_color)
        if enabled:
            self.toggle_btn.configure(
                text="Deactivate IME", 
                fg_color="#d9534f",
                hover_color="#c9302c"
            )
        else:
            self.toggle_btn.configure(
                text="Activate IME", 
                fg_color="#5cb85c",
                hover_color="#4cae4c"
            )

    def update_dashboard(self, enabled, lang_code, active_app="", allow_websites=False, font_size=11, startup=False, theme_name="Dark", offline_enabled=True, debounce_delay=70, opacity=0.9, sound_enabled=True, online_mode=True):
        """Updates control panel GUI widgets based on coordinator state changes."""
        self.allow_websites_var.set(allow_websites)
        self.font_size_slider.set(font_size)
        self.suggestion_win.set_font_size(font_size)
        self.startup_var.set(startup)
        self.theme_var.set(theme_name)
        self.offline_enabled_var.set(offline_enabled)
        self.sound_enabled_var.set(sound_enabled)
        self.online_mode_var.set(online_mode)
        self.debounce_slider.set(debounce_delay)
        self.opacity_slider.set(int(opacity * 100))
        self.suggestion_win.set_opacity(opacity)
        
        # Sync values to the option menu displays
        name = self.lang_map_rev.get(lang_code, "Bengali")
        self.lang_var.set(name)
        self.lang_menu.set(name)
        self.theme_menu.set(theme_name)
        
        if self.current_theme != theme_name:
            self.apply_theme(theme_name)
            
        self.last_status_enabled = enabled
        self.update_status_led()
        
        # Update active language text
        self.lang_display_lbl.configure(text=name)
        
        # Update focused app
        if active_app:
            self.app_display_lbl.configure(text=active_app)

    def poll_queue(self):
        """Main queue poller to coordinate UI updates from background threads."""
        try:
            while True:
                task = self.queue.get_nowait()
                action = task.get("action")
                
                if action == "show":
                    self.suggestion_win.show(
                        task["x"], 
                        task["caret_top"], 
                        task["caret_bottom"], 
                        task["buffer"], 
                        task["candidates"], 
                        task.get("highlighted_index", 0)
                    )
                elif action == "hide":
                    self.suggestion_win.hide()
                elif action == "highlight":
                    self.suggestion_win.select_highlight(task["index"])
                elif action == "update_font_size":
                    self.suggestion_win.set_font_size(task["size"])
                elif action == "update_opacity":
                    self.suggestion_win.set_opacity(task["opacity"])
                elif action == "show_lang_notification":
                    lang_name = self.lang_map_rev.get(task["lang_code"], "English")
                    colors = THEMES.get(self.current_theme, THEMES["Dark"])
                    enabled = task.get("enabled", True)
                    self.lang_notifier.show_language(lang_name, colors, enabled)
                elif action == "update_status":
                    self.update_dashboard(
                        task["enabled"], 
                        task["lang_code"], 
                        task.get("active_app", ""),
                        task.get("allow_websites", False),
                        task.get("font_size", 11),
                        task.get("startup", False),
                        task.get("theme_name", "Dark"),
                        task.get("offline_enabled", True),
                        task.get("debounce_delay", 70),
                        task.get("opacity", 0.9),
                        task.get("sound_enabled", True),
                        task.get("online_mode", True)
                    )
                elif action == "show_gui":
                    self.root.deiconify()
                    self.root.lift()
                elif action == "exit":
                    self.root.destroy()
                    return
                self.queue.task_done()
        except queue.Empty:
            pass
        
        self.root.after(20, self.poll_queue)

    def on_close(self):
        """Hides the window to system tray instead of closing."""
        self.root.withdraw()

    def run(self):
        """Starts Tkinter main event loop."""
        self.root.mainloop()
