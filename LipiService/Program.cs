using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Windows;
using LipiService.Services;
using Hardcodet.Wpf.TaskbarNotification;

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
            var apiService = new ApiService(cacheManager, settingsManager);
            var pipeServer = new NamedPipeServerManager(apiService, settingsManager, cacheManager);
            
            var app = new System.Windows.Application();
            app.ShutdownMode = System.Windows.ShutdownMode.OnExplicitShutdown;
            CandidateUI = new CandidateWindow();
            
            var trayIcon = new TaskbarIcon();
            trayIcon.Icon = System.Drawing.SystemIcons.Information;
            trayIcon.ToolTipText = "Lipi IME Service";
            trayIcon.Visibility = Visibility.Visible;

            var contextMenu = new System.Windows.Controls.ContextMenu();
            var dashboardItem = new System.Windows.Controls.MenuItem { Header = "Open Dashboard" };
            dashboardItem.Click += (s, e) => {
                string processName = "LipiDashboard";
                var running = Process.GetProcessesByName(processName);
                if (running.Length == 0)
                {
                    string dir = AppDomain.CurrentDomain.BaseDirectory;
                    string possiblePath1 = Path.Combine(dir, "LipiDashboard.exe");
                    string possiblePath2 = Path.GetFullPath(Path.Combine(dir, @"..\..\..\..\LipiDashboard\bin\Debug\net8.0-windows10.0.19041.0\win-x64\LipiDashboard.exe"));
                    string possiblePath3 = Path.GetFullPath(Path.Combine(dir, @"..\..\..\..\LipiDashboard\bin\x64\Debug\net8.0-windows10.0.19041.0\win-x64\LipiDashboard.exe"));
                    
                    if (File.Exists(possiblePath1))
                        Process.Start(possiblePath1);
                    else if (File.Exists(possiblePath2))
                        Process.Start(possiblePath2);
                    else if (File.Exists(possiblePath3))
                        Process.Start(possiblePath3);
                    else
                        System.Windows.MessageBox.Show("Could not find LipiDashboard.exe");
                }
            };
            
            var exitItem = new System.Windows.Controls.MenuItem { Header = "Exit Lipi IME" };
            exitItem.Click += (s, e) => {
                cacheManager.SaveCacheNow();
                trayIcon.Visibility = Visibility.Collapsed;
                trayIcon.Dispose();
                app.Shutdown();
            };

            contextMenu.Items.Add(dashboardItem);
            contextMenu.Items.Add(new System.Windows.Controls.Separator());
            contextMenu.Items.Add(exitItem);

            trayIcon.ContextMenu = contextMenu;

            pipeServer.Start();
            
            Console.WriteLine("Service is running in background. System tray icon added.");
            
            app.Run();
        }
    }
}
