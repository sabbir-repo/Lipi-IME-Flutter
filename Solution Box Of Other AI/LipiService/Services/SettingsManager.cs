using System;
using System.IO;
using System.Text.Json;
using System.Threading;

namespace LipiService.Services
{
    public class Settings
    {
        public bool OfflineMode { get; set; } = true;
        public bool OnlineMode { get; set; } = true;
        public bool BrowserBypass { get; set; } = true;
        public string Theme { get; set; } = "System";
        
        public string SuggestionBgColor { get; set; } = "#111113";
        public string SuggestionTextColor { get; set; } = "#c8c8c8";
        public string SuggestionSelectedBgColor { get; set; } = "#3c3c3c";
        public string SuggestionSelectedTextColor { get; set; } = "#ffffff";
        public double SuggestionFontSize { get; set; } = 18.0;
        public string SuggestionFontFamily { get; set; } = "Segoe UI";
        public double SuggestionItemPaddingV { get; set; } = 5.0;
        public double SuggestionItemPaddingH { get; set; } = 10.0;
        public double SuggestionWindowPadding { get; set; } = 5.0;
        public double SuggestionBgOpacity { get; set; } = 100.0;   // 0-100 (%), 100 = fully opaque
        public bool SuggestionBlurEnabled { get; set; } = false;   // blur-behind effect for the popup
        public bool SuggestionLiquidGlass { get; set; } = false;            // acrylic "liquid glass" effect (overrides plain blur)
        public double SuggestionGlassTintOpacity { get; set; } = 40.0;      // 0-100 (%), colour tint strength over the glass
        public double SuggestionGlassCornerRadius { get; set; } = 12.0;     // rounded corner radius of the glass panel
        public double SuggestionGlassHighlightOpacity { get; set; } = 25.0; // 0-100 (%), white edge highlight of the glass

        public double OnlineLatencyBudgetMs { get; set; } = 350.0;          // 100-1000 ms: max time a keystroke waits for the online API
        public System.Collections.Generic.List<string> ExcludedApps { get; set; } = new System.Collections.Generic.List<string>(); // process names where the IME stays disabled

        public System.Collections.Generic.Dictionary<string, System.Collections.Generic.Dictionary<string, string>> UserPreferences { get; set; } = new System.Collections.Generic.Dictionary<string, System.Collections.Generic.Dictionary<string, string>>();
    }

    public class SettingsManager
    {
        private static readonly JsonSerializerOptions _jsonOptions = new JsonSerializerOptions { WriteIndented = true };
        private readonly string _settingsFilePath;
        private readonly string _lipiDir;
        private FileSystemWatcher? _watcher;
        public Settings CurrentSettings { get; private set; } = new Settings();

        public SettingsManager()
        {
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            _lipiDir = Path.Combine(home, ".lipi_ime");
            if (!Directory.Exists(_lipiDir))
            {
                Directory.CreateDirectory(_lipiDir);
            }
            
            _settingsFilePath = Path.Combine(_lipiDir, "settings.json");
            LoadSettings();
            InitializeWatcher();
        }

        private void InitializeWatcher()
        {
            try
            {
                _watcher = new FileSystemWatcher(_lipiDir, "settings.json")
                {
                    NotifyFilter = NotifyFilters.LastWrite,
                    EnableRaisingEvents = true
                };
                
                _watcher.Changed += OnSettingsChanged;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to initialize FileSystemWatcher: {ex.Message}");
            }
        }

        private void OnSettingsChanged(object sender, FileSystemEventArgs e)
        {
            // Add a small delay to avoid reading while the file is still being written to by the Dashboard
            Thread.Sleep(100);
            LoadSettings();
            Console.WriteLine("Settings reloaded automatically.");
        }

        public void ReloadSettings()
        {
            LoadSettings();
        }

        private void LoadSettings()
        {
            try
            {
                if (File.Exists(_settingsFilePath))
                {
                    var content = File.ReadAllText(_settingsFilePath);
                    CurrentSettings = JsonSerializer.Deserialize<Settings>(content) ?? new Settings();
                }
                else
                {
                    CurrentSettings = new Settings();
                    SaveSettings();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to load settings: {ex.Message}");
                CurrentSettings = new Settings();
            }
        }

        public void SaveSettings()
        {
            try
            {
                if (_watcher != null) _watcher.EnableRaisingEvents = false; // Prevent circular trigger
                var json = JsonSerializer.Serialize(CurrentSettings, _jsonOptions);
                File.WriteAllText(_settingsFilePath, json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to save settings: {ex.Message}");
            }
            finally
            {
                if (_watcher != null) _watcher.EnableRaisingEvents = true;
            }
        }
    }
}
