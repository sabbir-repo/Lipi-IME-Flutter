using System;
using System.IO;
using System.Text.Json;

namespace LipiService.Services
{
    public class Settings
    {
        public bool OfflineMode { get; set; } = true;
        public bool OnlineMode { get; set; } = true;
        public string Theme { get; set; } = "System";
    }

    public class SettingsManager
    {
        private readonly string _settingsFilePath;
        public Settings CurrentSettings { get; private set; } = new Settings();

        public SettingsManager()
        {
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            var lipiDir = Path.Combine(home, ".lipi_ime");
            if (!Directory.Exists(lipiDir))
            {
                Directory.CreateDirectory(lipiDir);
            }
            
            _settingsFilePath = Path.Combine(lipiDir, "settings.json");
            LoadSettings();
        }

        public void LoadSettings()
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
                var options = new JsonSerializerOptions { WriteIndented = true };
                var json = JsonSerializer.Serialize(CurrentSettings, options);
                File.WriteAllText(_settingsFilePath, json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to save settings: {ex.Message}");
            }
        }
    }
}
