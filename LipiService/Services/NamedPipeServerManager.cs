using System;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace LipiService.Services
{
    public class NamedPipeServerManager
    {
        private const string PipeName = "LipiImePipe";
        private readonly ApiService _apiService;
        private readonly SettingsManager _settingsManager;
        private readonly CacheManager _cacheManager;
        private bool _isRunning = false;

        public NamedPipeServerManager(ApiService apiService, SettingsManager settingsManager, CacheManager cacheManager)
        {
            _apiService = apiService;
            _settingsManager = settingsManager;
            _cacheManager = cacheManager;
        }

        public void Start()
        {
            _isRunning = true;
            Task.Run(async () =>
            {
                while (_isRunning)
                {
                    try
                    {
                        var pipeServer = new NamedPipeServerStream(
                            PipeName, PipeDirection.InOut, 
                            NamedPipeServerStream.MaxAllowedServerInstances, 
                            PipeTransmissionMode.Byte, 
                            PipeOptions.Asynchronous,
                            8192, 8192);

                        Console.WriteLine("Named Pipe Server started. Waiting for TSF client connection...");
                        await pipeServer.WaitForConnectionAsync();
                        Console.WriteLine("Client connected!");

                        // Process the client concurrently so the server can accept more connections
                        _ = HandleClientAsync(pipeServer);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Pipe Server Error: {ex.Message}");
                    }
                }
            });
        }

        private async Task HandleClientAsync(NamedPipeServerStream pipeServer)
        {
            try
            {
                using (pipeServer)
                {
                    using (var reader = new StreamReader(pipeServer, Encoding.UTF8, leaveOpen: true))
                    using (var writer = new StreamWriter(pipeServer, Encoding.UTF8, leaveOpen: true) { AutoFlush = true })
                    {
                        Console.WriteLine("Entering while loop...");
                        while (pipeServer.IsConnected)
                        {
                            Console.WriteLine("Calling ReadLineAsync...");
                            string request = await reader.ReadLineAsync();
                            if (request == null) break;

                            Console.WriteLine($"Received request: {request}");

                            if (request.StartsWith("LEARN|"))
                            {
                                var parts = request.Split('|');
                                if (parts.Length >= 5)
                                {
                                    var langCode = parts[1];
                                    var engWord = parts[2];
                                    if (int.TryParse(parts[3], out int selectedIndex))
                                    {
                                        var suggestions = new System.Collections.Generic.List<string>();
                                        for (int i = 4; i < parts.Length; i++)
                                        {
                                            suggestions.Add(parts[i]);
                                        }
                                        
                                        if (selectedIndex >= 0 && selectedIndex < suggestions.Count)
                                        {
                                            var selectedWord = suggestions[selectedIndex];
                                            suggestions.RemoveAt(selectedIndex);
                                            suggestions.Insert(0, selectedWord);
                                            _cacheManager.CacheWord(langCode, engWord, suggestions);
                                        }
                                    }
                                }
                                continue;
                            }

                            
                            if (request == "CLEAR_CACHE")
                            {
                                _cacheManager.ClearCache();
                                await writer.WriteLineAsync("OK");
                                continue;
                            }

                            if (request == "RELOAD_CACHE")
                            {
                                _cacheManager.ReloadCache();
                                await writer.WriteLineAsync("OK");
                                continue;
                            }

                            if (request == "RELOAD_CONFIG")
                            {
                                _settingsManager.ReloadSettings();
                                await writer.WriteLineAsync("OK");
                                continue;
                            }

                            if (request == "GET_CONFIG")
                            {
                                int browserBypass = _settingsManager.CurrentSettings.BrowserBypass ? 1 : 0;
                                await writer.WriteLineAsync($"{browserBypass}");
                                continue;
                            }

                            if (request.StartsWith("SHOW|"))
                            {
                                var parts = request.Split('|');
                                if (parts.Length >= 5)
                                {
                                    if (double.TryParse(parts[1], out double x) && double.TryParse(parts[2], out double y) && int.TryParse(parts[3], out int selectedIndex))
                                    {
                                        string bufferText = parts[4];
                                        string[] words = new string[parts.Length - 5];
                                        Array.Copy(parts, 5, words, 0, words.Length);
                                        
                                        System.Windows.Application.Current.Dispatcher.Invoke(() => {
                                            if (Program.CandidateUI != null) {
                                                Program.CandidateUI.UpdateSuggestions(words, selectedIndex, bufferText, _settingsManager.CurrentSettings);
                                                Program.CandidateUI.Left = x;
                                                Program.CandidateUI.Top = y + 25;
                                                Program.CandidateUI.Show();
                                            }
                                        });
                                    }
                                }
                                continue;
                            }
                            else if (request == "HIDE")
                            {
                                System.Windows.Application.Current.Dispatcher.Invoke(() => {
                                    if (Program.CandidateUI != null) {
                                        Program.CandidateUI.Hide();
                                    }
                                });
                                continue;
                            }

                            // Format expected from C++ TSF Core: "bn-t-i0-und|text" or "FORCE_FETCH_API|text"
                            var reqParts = request.Split('|');
                            if (reqParts.Length == 2)
                            {
                                var langCode = reqParts[0];
                                var text = reqParts[1];
                                
                                bool offline = _settingsManager.CurrentSettings.OfflineMode;
                                bool online = _settingsManager.CurrentSettings.OnlineMode;
                                bool forceFetch = false;
                                
                                if (langCode == "FORCE_FETCH_API") {
                                    forceFetch = true;
                                    langCode = "bn-t-i0-und"; // default language
                                }
                                
                                var suggestions = await _apiService.FetchSuggestionsAsync(text, langCode, offline, online, forceFetch);
                                string responseStr = string.Join("|", suggestions);
                                
                                await writer.WriteLineAsync(responseStr);
                            }
                            else
                            {
                                await writer.WriteLineAsync("");
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Client Error: {ex.Message}");
            }
        }
    }
}
