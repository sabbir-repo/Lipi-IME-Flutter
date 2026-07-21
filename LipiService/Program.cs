using System;
using System.Threading;
using LipiService.Services;

namespace LipiService
{
    class Program
    {
        static Mutex? _mutex;

        static void Main(string[] args)
        {
            const string appName = "Global\\LipiServiceMutex";
            bool createdNew;

            _mutex = new Mutex(true, appName, out createdNew);

            if (!createdNew)
            {
                // App is already running, exit immediately
                return;
            }

            Console.WriteLine("========================================");
            Console.WriteLine(" Lipi IME Background Service ");
            Console.WriteLine("========================================");
            
            var settingsManager = new SettingsManager();
            var cacheManager = new CacheManager();
            var apiService = new ApiService(cacheManager);
            var pipeServer = new NamedPipeServerManager(apiService, settingsManager);
            
            pipeServer.Start();
            
            Console.WriteLine("Service is running in background...");
            
            // Keep the application running without relying on standard input 
            // since we will launch it without a console window.
            Thread.Sleep(Timeout.Infinite);
        }
    }
}
