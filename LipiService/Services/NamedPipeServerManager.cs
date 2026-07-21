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
        private bool _isRunning = false;

        public NamedPipeServerManager(ApiService apiService, SettingsManager settingsManager)
        {
            _apiService = apiService;
            _settingsManager = settingsManager;
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
                            PipeOptions.Asynchronous);

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
                using (pipeServer) // Ensure pipeServer is disposed when done
                {
                    using var writer = new StreamWriter(pipeServer, Encoding.UTF8) { AutoFlush = true };
                    byte[] buffer = new byte[8192];

                while (pipeServer.IsConnected)
                {
                    int bytesRead = await pipeServer.ReadAsync(buffer, 0, buffer.Length);
                    if (bytesRead == 0) break;

                    string request = Encoding.UTF8.GetString(buffer, 0, bytesRead).TrimEnd('\r', '\n', '\0');
                    if (string.IsNullOrEmpty(request)) continue;

                    Console.WriteLine($"Received request: {request}");

                    // Format expected from C++ TSF Core: "bn-t-i0-und|text"
                    var parts = request.Split('|');
                    if (parts.Length == 2)
                    {
                        var langCode = parts[0];
                        var text = parts[1];
                        
                        bool offline = _settingsManager.CurrentSettings.OfflineMode;
                        bool online = _settingsManager.CurrentSettings.OnlineMode;
                        
                        var suggestions = await _apiService.FetchSuggestionsAsync(text, langCode, offline, online);
                        var responseJson = JsonSerializer.Serialize(suggestions);
                        
                        await writer.WriteLineAsync(responseJson);
                    }
                    else
                    {
                        await writer.WriteLineAsync("[]");
                    }
                }
                } // Close using (pipeServer) block
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Client Error: {ex.Message}");
            }
        }
    }
}
