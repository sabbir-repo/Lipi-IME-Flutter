using System;
using System.Threading;
using LipiService.Services;

namespace LipiService
{
    class Program
    {
        static Mutex? _mutex;
        public static CandidateWindow? CandidateUI { get; private set; }

        [STAThread]
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
            
            var app = new System.Windows.Application();
            app.ShutdownMode = System.Windows.ShutdownMode.OnExplicitShutdown;
            CandidateUI = new CandidateWindow();
            // Don't show it yet, just initialize it.
            
            pipeServer.Start();
            
            Console.WriteLine("Service is running in background...");
            
            app.Run();
        }
    }
}
