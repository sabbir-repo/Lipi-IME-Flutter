using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace LipiService.Services
{
    public class CacheManager
    {
        private readonly string _cacheFilePath;
        private Dictionary<string, Dictionary<string, List<string>>> _offlineCache = new();
        private readonly object _cacheLock = new object();
        
        // Basic fallback dictionary
        private readonly Dictionary<string, Dictionary<string, List<string>>> _basicOfflineDict = new()
        {
            { "bn-t-i0-und", new Dictionary<string, List<string>>
                {
                    { "amar", new List<string> { "আমার", "আমারে", "আমারও", "আমারই" } },
                    { "tumi", new List<string> { "তুমি", "তুমিও", "তুমিই", "তোমাকে" } },
                    { "ami", new List<string> { "আমি", "আমিও", "আমিই", "আমাকে" } },
                    { "bhalo", new List<string> { "ভালো", "ভাল", "ভালোই", "ভালো লাগছে" } },
                    { "dhaka", new List<string> { "ঢাকা", "ঢাকায়", "ঢাকাই" } },
                    { "bhasha", new List<string> { "ভাষা", "ভাষার", "ভাষায়" } },
                    { "bangla", new List<string> { "বাংলা", "বাংলাদেশ", "বাঙালি", "বাঙला" } },
                    { "nam", new List<string> { "নাম", "নামের", "নামটি" } },
                    { "ki", new List<string> { "কী", "কি", "কিছু", "কিনা" } },
                    { "kemon", new List<string> { "কেমন", "কেমন আছো", "কেমন আছেন" } },
                    { "acho", new List<string> { "আছো", "আছেন", "আছিস" } },
                    { "bari", new List<string> { "বাড়ি", "বাড়িতে", "বাড়ির" } },
                    { "khabar", new List<string> { "খাবার", "খাবো", "খাবার দাবাড়" } },
                    { "desh", new List<string> { "দেশ", "দেশের", "দেশে" } },
                    { "shonar", new List<string> { "সোনার", "সোনা", "সোনার বাংলা" } }
                }
            }
        };

        public CacheManager()
        {
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            var lipiDir = Path.Combine(home, ".lipi_ime");
            if (!Directory.Exists(lipiDir))
            {
                Directory.CreateDirectory(lipiDir);
            }
            
            _cacheFilePath = Path.Combine(lipiDir, "offline_cache.json");
            LoadCache();
        }

        private void LoadCache()
        {
            try
            {
                var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                var oldCachePath = Path.Combine(home, ".lipi_ime_offline_cache.json");

                // Migrate old Python cache if the new one doesn't exist yet
                if (!File.Exists(_cacheFilePath) && File.Exists(oldCachePath))
                {
                    File.Copy(oldCachePath, _cacheFilePath);
                }

                if (File.Exists(_cacheFilePath))
                {
                    var content = File.ReadAllText(_cacheFilePath);
                    var deserialized = JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, List<string>>>>(content);
                    lock (_cacheLock)
                    {
                        _offlineCache = deserialized ?? new Dictionary<string, Dictionary<string, List<string>>>();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to load cache: {ex.Message}");
            }
        }

        private void SaveCache()
        {
            try
            {
                var options = new JsonSerializerOptions { WriteIndented = true };
                var json = JsonSerializer.Serialize(_offlineCache, options);
                File.WriteAllText(_cacheFilePath, json);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to save cache: {ex.Message}");
            }
        }

        public void CacheWord(string langCode, string word, List<string> suggestions)
        {
            if (string.IsNullOrWhiteSpace(word) || suggestions == null || suggestions.Count == 0) return;
            
            lock (_cacheLock)
            {
                if (!_offlineCache.ContainsKey(langCode))
                {
                    _offlineCache[langCode] = new Dictionary<string, List<string>>();
                }
                
                _offlineCache[langCode][word] = suggestions;
            }
            SaveCache();
        }

        public List<string>? GetCachedSuggestions(string langCode, string text)
        {
            var textLower = text.ToLower().Trim();
            
            lock (_cacheLock)
            {
                if (_offlineCache.TryGetValue(langCode, out var langCache))
                {
                    if (langCache.TryGetValue(text, out var suggestions)) return suggestions;
                    if (langCache.TryGetValue(textLower, out var suggestionsLower)) return suggestionsLower;
                }
            }
            
            if (_basicOfflineDict.TryGetValue(langCode, out var basicDict))
            {
                if (basicDict.TryGetValue(textLower, out var basicSuggestions)) return basicSuggestions;
            }

            return null;
        }
    }
}
