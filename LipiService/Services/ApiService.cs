using System;
using System.Collections.Concurrent;
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
        private readonly SettingsManager _settingsManager;

        // In-memory memo of recent API results so a slow fetch never blocks typing twice.
        private readonly ConcurrentDictionary<string, List<string>> _recentFetches = new ConcurrentDictionary<string, List<string>>();
        private const int RecentFetchLimit = 300;
        // Max time a normal keystroke is allowed to wait for the online API.
        private const int OnlineBudgetMs = 350;

        public ApiService(CacheManager cacheManager, SettingsManager settingsManager)
        {
            _httpClient = new HttpClient();
            _httpClient.Timeout = TimeSpan.FromMilliseconds(2500);
            _cacheManager = cacheManager;
            _settingsManager = settingsManager;
        }

        public async Task<List<string>> FetchSuggestionsAsync(string text, string langCode, bool offlineEnabled, bool onlineMode, bool forceFetch = false)
        {
            if (string.IsNullOrWhiteSpace(text)) return new List<string>();

            string memoKey = langCode + "|" + text;

            // 1. Check Offline Cache
            if (offlineEnabled && !forceFetch)
            {
                var cached = _cacheManager.GetCachedSuggestions(langCode, text);
                if (cached != null)
                {
                    return cached;
                }
            }

            // 1b. Check in-memory results of recently completed background fetches
            if (!forceFetch && _recentFetches.TryGetValue(memoKey, out var recent))
            {
                return recent;
            }

            // 2. Fetch Online
            if (onlineMode)
            {
                var apiTask = FetchFromGoogleAsync(text, langCode);

                if (forceFetch)
                {
                    // Alt+R: user explicitly asked for a fresh fetch, so wait for it fully.
                    var forced = await apiTask;
                    if (forced != null)
                    {
                        if (offlineEnabled)
                        {
                            _cacheManager.CacheWord(langCode, text, forced);
                        }
                        return forced;
                    }
                }
                else
                {
                    // Normal typing: never block the keystroke for longer than OnlineBudgetMs.
                    var completed = await Task.WhenAny(apiTask, Task.Delay(OnlineBudgetMs));
                    if (completed == apiTask && apiTask.Status == TaskStatus.RanToCompletion && apiTask.Result != null)
                    {
                        MemoizeRecent(memoKey, apiTask.Result);
                        return apiTask.Result;
                    }

                    // API is slow right now: let it finish in the background and
                    // memoize the result so the very next keystroke gets it instantly.
                    _ = apiTask.ContinueWith(t =>
                    {
                        if (t.Status == TaskStatus.RanToCompletion && t.Result != null)
                        {
                            MemoizeRecent(memoKey, t.Result);
                        }
                    }, TaskScheduler.Default);
                }
            }

            // 3. Fallback to Avro Phonetic
            try
            {
                string avroResult = AvroPhonetic.Parse(text);
                if (!string.IsNullOrEmpty(avroResult))
                {
                    return new List<string> { avroResult, text };
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Avro parsing failed: {ex.Message}");
            }

            return new List<string> { text };
        }

        private void MemoizeRecent(string key, List<string> suggestions)
        {
            if (_recentFetches.Count >= RecentFetchLimit)
            {
                _recentFetches.Clear();
            }
            _recentFetches[key] = suggestions;
        }

        private async Task<List<string>> FetchFromGoogleAsync(string text, string langCode)
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

                        if (!suggestions.Contains(text))
                        {
                            suggestions.Add(text);
                        }

                        return suggestions;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"API Request failed: {ex.Message}");
            }

            return null;
        }
    }
}
