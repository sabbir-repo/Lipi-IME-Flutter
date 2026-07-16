using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;

namespace LipiService.Services
{
    public class ApiService
    {
        private readonly HttpClient _httpClient;
        private readonly CacheManager _cacheManager;

        public ApiService(CacheManager cacheManager)
        {
            _httpClient = new HttpClient();
            _httpClient.Timeout = TimeSpan.FromMilliseconds(2500);
            _cacheManager = cacheManager;
        }

        public async Task<List<string>> FetchSuggestionsAsync(string text, string langCode, bool offlineEnabled, bool onlineMode)
        {
            if (string.IsNullOrWhiteSpace(text)) return new List<string>();

            // 1. Check Offline Cache
            if (offlineEnabled)
            {
                var cached = _cacheManager.GetCachedSuggestions(langCode, text);
                if (cached != null) return cached;
            }

            // 2. Fetch Online
            if (onlineMode)
            {
                try
                {
                    var values = new Dictionary<string, string>
                    {
                        { "text", text },
                        { "itc", langCode },
                        { "num", "5" },
                        { "cp", "0" },
                        { "cs", "1" },
                        { "ie", "utf-8" },
                        { "oe", "utf-8" },
                        { "app", "demomode" }
                    };

                    var content = new FormUrlEncodedContent(values);
                    var response = await _httpClient.PostAsync("https://inputtools.google.com/request", content);

                    if (response.IsSuccessStatusCode)
                    {
                        var responseString = await response.Content.ReadAsStringAsync();
                        using var doc = JsonDocument.Parse(responseString);
                        var root = doc.RootElement;
                        
                        if (root.GetArrayLength() > 0 && root[0].GetString() == "SUCCESS")
                        {
                            var suggestions = new List<string>();
                            var resultsArray = root[1][0][1];
                            foreach (var element in resultsArray.EnumerateArray())
                            {
                                suggestions.Add(element.GetString());
                            }
                            
                            // Cache the result for future offline use
                            _cacheManager.CacheWord(langCode, text, suggestions);
                            
                            return suggestions;
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"API Request failed: {ex.Message}");
                }
            }

            return new List<string>();
        }
    }
}
