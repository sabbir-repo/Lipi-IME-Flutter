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
            ReloadCache();
            AppDomain.CurrentDomain.ProcessExit += (_, _) => SaveCacheNow();
        }

        public void ReloadCache()
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

        private System.Threading.Timer? _saveTimer;
        private void ScheduleSave()
        {
            // coalesce bursts of learned words into one disk write, 2s after idle
            _saveTimer ??= new System.Threading.Timer(_ => SaveCacheNow(), null, System.Threading.Timeout.Infinite, System.Threading.Timeout.Infinite);
            _saveTimer.Change(TimeSpan.FromSeconds(2), System.Threading.Timeout.InfiniteTimeSpan);
        }

        public void SaveCacheNow()
        {
            try
            {
                var options = new JsonSerializerOptions { 
                    WriteIndented = true,
                    Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
                };
                string json;
                lock (_cacheLock)
                {
                    json = JsonSerializer.Serialize(_offlineCache, options);
                }
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
            
            var sanitizedSuggestions = new List<string>();
            foreach (var s in suggestions)
            {
                if (string.IsNullOrWhiteSpace(s)) continue;
                var cleaned = s.Replace("\uFEFF", "").Replace("\u200B", "").Trim();
                if (!string.IsNullOrWhiteSpace(cleaned) && !sanitizedSuggestions.Contains(cleaned))
                {
                    sanitizedSuggestions.Add(cleaned);
                }
            }
            if (sanitizedSuggestions.Count == 0) return;
            
            lock (_cacheLock)
            {
                if (!_offlineCache.ContainsKey(langCode))
                {
                    _offlineCache[langCode] = new Dictionary<string, List<string>>();
                }
                
                _offlineCache[langCode][word] = sanitizedSuggestions;
            }
            ScheduleSave();
        }

        public List<string>? GetCachedSuggestions(string langCode, string text)
        {
            var textLower = text.ToLower().Trim();
            
            lock (_cacheLock)
            {
                if (_offlineCache.TryGetValue("custom_dictionary", out var customCache))
                {
                    if (customCache.TryGetValue(text, out var customSuggestions)) return customSuggestions;
                    if (customCache.TryGetValue(textLower, out var customSuggestionsLower)) return customSuggestionsLower;
                }
                
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
        public void PromoteWord(string langCode, string word, string suggestion)
        {
            if (string.IsNullOrWhiteSpace(word) || string.IsNullOrWhiteSpace(suggestion)) return;
            var wordLower = word.ToLower().Trim();

            lock (_cacheLock)
            {
                if (_offlineCache.TryGetValue(langCode, out var langCache))
                {
                    List<string>? suggestions = null;
                    if (langCache.TryGetValue(word, out var s1)) suggestions = s1;
                    else if (langCache.TryGetValue(wordLower, out var s2)) suggestions = s2;

                    if (suggestions != null)
                    {
                        if (suggestions.Contains(suggestion))
                        {
                            suggestions.Remove(suggestion);
                            suggestions.Insert(0, suggestion);
                            SaveCacheNow();
                            return;
                        }
                    }
                }
                
                if (_basicOfflineDict.TryGetValue(langCode, out var basicDict))
                {
                    if (basicDict.TryGetValue(wordLower, out var basicSuggestions))
                    {
                        if (basicSuggestions.Contains(suggestion))
                        {
                            if (!_offlineCache.ContainsKey(langCode)) _offlineCache[langCode] = new Dictionary<string, List<string>>();
                            
                            var newSuggestions = new List<string>(basicSuggestions);
                            newSuggestions.Remove(suggestion);
                            newSuggestions.Insert(0, suggestion);
                            
                            _offlineCache[langCode][wordLower] = newSuggestions;
                            SaveCacheNow();
                        }
                    }
                }
            }
        }

        public void ClearCache()
        {
            lock (_cacheLock)
            {
                _offlineCache.Clear();
            }
            SaveCacheNow();
        }
    }
}
