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
        
        public string SuggestionBgColor { get; set; } = "#FAFAFA";
        public string SuggestionTextColor { get; set; } = "#000000";
        public string SuggestionSelectedBgColor { get; set; } = "#DCE6FF";
        public string SuggestionSelectedTextColor { get; set; } = "#000000";
        public double SuggestionFontSize { get; set; } = 18.0;
        public string SuggestionFontFamily { get; set; } = "Segoe UI";

        public System.Collections.Generic.Dictionary<string, System.Collections.Generic.Dictionary<string, string>> UserPreferences { get; set; } = new System.Collections.Generic.Dictionary<string, System.Collections.Generic.Dictionary<string, string>>();
    }

    public class SettingsManager
    {
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
                var options = new JsonSerializerOptions { WriteIndented = true };
                var json = JsonSerializer.Serialize(CurrentSettings, options);
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
