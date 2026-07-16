using System;
using LipiService.Services;

namespace LipiService
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("========================================");
            Console.WriteLine(" Lipi IME Background Service ");
            Console.WriteLine("========================================");
            
            var settingsManager = new SettingsManager();
            var cacheManager = new CacheManager();
            var apiService = new ApiService(cacheManager);
            var pipeServer = new NamedPipeServerManager(apiService, settingsManager);
            
            pipeServer.Start();
            
            Console.WriteLine("Service is running...");
            Console.WriteLine("Press Enter to exit.");
            Console.ReadLine();
        }
    }
}
