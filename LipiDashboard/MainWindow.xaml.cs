using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Data;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Foundation;
using Windows.Foundation.Collections;

// To learn more about WinUI, the WinUI project structure,
// and more about our project templates, see: http://aka.ms/winui-project-info.

namespace LipiDashboard
{
    /// <summary>
    /// An empty window that can be used on its own or navigated to within a Frame.
    /// </summary>
    public sealed partial class MainWindow : Window
    {
        private SettingsManager _settingsManager;
        private bool _isLoaded = false;

        public MainWindow()
        {
            this.InitializeComponent();
            this.ExtendsContentIntoTitleBar = true; // Modern Win11 look
            
            // Set fixed window size
            IntPtr hWnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
            Microsoft.UI.WindowId windowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hWnd);
            Microsoft.UI.Windowing.AppWindow appWindow = Microsoft.UI.Windowing.AppWindow.GetFromWindowId(windowId);
            
            appWindow.Resize(new Windows.Graphics.SizeInt32(945, 600));

            if (appWindow.Presenter is Microsoft.UI.Windowing.OverlappedPresenter presenter)
            {
                presenter.IsResizable = false;
                presenter.IsMaximizable = false;
            }
            
            _settingsManager = new SettingsManager();
            LoadSettingsIntoUI();
            
            NavView.SelectedItem = NavView.MenuItems.First();
        }

        private void LoadSettingsIntoUI()
        {
            _isLoaded = false;
            OnlineModeSwitch.IsOn = _settingsManager.CurrentSettings.OnlineMode;
            OfflineModeSwitch.IsOn = _settingsManager.CurrentSettings.OfflineMode;
            BrowserBypassSwitch.IsOn = _settingsManager.CurrentSettings.BrowserBypass;
            _isLoaded = true;
        }

        private void OnlineModeSwitch_Toggled(object sender, RoutedEventArgs e)
        {
            if (!_isLoaded) return;
            _settingsManager.CurrentSettings.OnlineMode = OnlineModeSwitch.IsOn;
            _settingsManager.SaveSettings();
        }

        private void OfflineModeSwitch_Toggled(object sender, RoutedEventArgs e)
        {
            if (!_isLoaded) return;
            _settingsManager.CurrentSettings.OfflineMode = OfflineModeSwitch.IsOn;
            _settingsManager.SaveSettings();
        }

        private async void BrowserBypassSwitch_Toggled(object sender, RoutedEventArgs e)
        {
            if (!_isLoaded) return;
            _settingsManager.CurrentSettings.BrowserBypass = BrowserBypassSwitch.IsOn;
            _settingsManager.SaveSettings();
            await NotifyServiceConfigUpdate();
        }

        private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
        {
            if (args.IsSettingsSelected)
            {
                GeneralPanel.Visibility = Visibility.Collapsed;
                AboutPanel.Visibility = Visibility.Collapsed;
                CustomDictionaryPanel.Visibility = Visibility.Collapsed;
                TypingRulesPanel.Visibility = Visibility.Collapsed;
                SettingsPanel.Visibility = Visibility.Visible;
            }
            else
            {
                var selectedItem = args.SelectedItem as NavigationViewItem;
                string tag = selectedItem?.Tag?.ToString();

                GeneralPanel.Visibility = tag == "General" ? Visibility.Visible : Visibility.Collapsed;
                TypingRulesPanel.Visibility = tag == "TypingRules" ? Visibility.Visible : Visibility.Collapsed;
                CustomDictionaryPanel.Visibility = tag == "CustomDictionary" ? Visibility.Visible : Visibility.Collapsed;
                SettingsPanel.Visibility = Visibility.Collapsed;
                AboutPanel.Visibility = tag == "About" ? Visibility.Visible : Visibility.Collapsed;

                if (tag == "CustomDictionary")
                {
                    LoadDictionary();
                }
            }
        }

        private async void ClearCacheButton_Click(object sender, RoutedEventArgs e)
        {
            ClearCacheButton.IsEnabled = false;
            try
            {
                using (var client = new System.IO.Pipes.NamedPipeClientStream(".", "LipiImePipe", System.IO.Pipes.PipeDirection.InOut))
                {
                    await client.ConnectAsync(2000); // 2 second timeout
                    using (var writer = new System.IO.StreamWriter(client, System.Text.Encoding.UTF8, 1024, true))
                    using (var reader = new System.IO.StreamReader(client, System.Text.Encoding.UTF8, true, 1024, true))
                    {
                        writer.AutoFlush = true;
                        await writer.WriteLineAsync("CLEAR_CACHE");
                        await reader.ReadLineAsync(); // Wait for OK
                    }
                }
                
                ContentDialog successDialog = new ContentDialog
                {
                    Title = "Cache Cleared",
                    Content = "Offline cache has been successfully cleared from memory and disk.",
                    CloseButtonText = "OK",
                    XamlRoot = this.Content.XamlRoot
                };
                await successDialog.ShowAsync();
            }
            catch (Exception ex)
            {
                ContentDialog errorDialog = new ContentDialog
                {
                    Title = "Error",
                    Content = $"Failed to clear cache: {ex.Message}\nMake sure the service is running.",
                    CloseButtonText = "OK",
                    XamlRoot = this.Content.XamlRoot
                };
                await errorDialog.ShowAsync();
            }
            finally
            {
                ClearCacheButton.IsEnabled = true;
            }
        }

        private string GetCacheFilePath()
        {
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            return System.IO.Path.Combine(home, ".lipi_ime", "offline_cache.json");
        }

        private void LoadDictionary()
        {
            try
            {
                string path = GetCacheFilePath();
                if (System.IO.File.Exists(path))
                {
                    var content = System.IO.File.ReadAllText(path);
                    var dict = System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, List<string>>>>(content);
                    
                    var wordsList = new System.Collections.ObjectModel.ObservableCollection<DictItem>();
                    if (dict != null && dict.ContainsKey("bn-t-i0-und"))
                    {
                        foreach (var kvp in dict["bn-t-i0-und"])
                        {
                            if (kvp.Value != null && kvp.Value.Count > 0)
                            {
                                wordsList.Add(new DictItem { EnglishWord = kvp.Key, BengaliWord = kvp.Value[0] });
                            }
                        }
                    }
                    DictionaryListView.ItemsSource = wordsList;
                }
            }
            catch { }
        }

        public class DictItem
        {
            public string EnglishWord { get; set; }
            public string BengaliWord { get; set; }
        }

        private async void AddDictWordButton_Click(object sender, RoutedEventArgs e)
        {
            string eng = DictEnglishInput.Text.Trim();
            string bn = DictBengaliInput.Text.Trim();
            if (string.IsNullOrEmpty(eng) || string.IsNullOrEmpty(bn)) return;

            try
            {
                string path = GetCacheFilePath();
                var dict = new Dictionary<string, Dictionary<string, List<string>>>();
                if (System.IO.File.Exists(path))
                {
                    var content = System.IO.File.ReadAllText(path);
                    dict = System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, List<string>>>>(content) ?? dict;
                }
                
                if (!dict.ContainsKey("bn-t-i0-und")) dict["bn-t-i0-und"] = new Dictionary<string, List<string>>();
                
                if (dict["bn-t-i0-und"].ContainsKey(eng))
                {
                    dict["bn-t-i0-und"][eng].Remove(bn);
                    dict["bn-t-i0-und"][eng].Insert(0, bn);
                }
                else
                {
                    dict["bn-t-i0-und"][eng] = new List<string> { bn };
                }
                
                System.IO.File.WriteAllText(path, System.Text.Json.JsonSerializer.Serialize(dict, new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
                
                DictEnglishInput.Text = "";
                DictBengaliInput.Text = "";
                LoadDictionary();
                
                await NotifyServiceCacheReload();
            }
            catch { }
        }

        private async void DeleteDictWordButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is string eng)
            {
                try
                {
                    string path = GetCacheFilePath();
                    if (System.IO.File.Exists(path))
                    {
                        var content = System.IO.File.ReadAllText(path);
                        var dict = System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, List<string>>>>(content);
                        
                        if (dict != null && dict.ContainsKey("bn-t-i0-und") && dict["bn-t-i0-und"].ContainsKey(eng))
                        {
                            dict["bn-t-i0-und"].Remove(eng);
                            System.IO.File.WriteAllText(path, System.Text.Json.JsonSerializer.Serialize(dict, new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
                            LoadDictionary();
                            await NotifyServiceCacheReload();
                        }
                    }
                }
                catch { }
            }
        }
        
        private async System.Threading.Tasks.Task NotifyServiceCacheReload()
        {
            try
            {
                using (var client = new System.IO.Pipes.NamedPipeClientStream(".", "LipiImePipe", System.IO.Pipes.PipeDirection.InOut))
                {
                    await client.ConnectAsync(1000);
                    using (var writer = new System.IO.StreamWriter(client, System.Text.Encoding.UTF8, 1024, true))
                    using (var reader = new System.IO.StreamReader(client, System.Text.Encoding.UTF8, true, 1024, true))
                    {
                        writer.AutoFlush = true;
                        await writer.WriteLineAsync("RELOAD_CACHE");
                        await reader.ReadLineAsync(); // Wait for OK
                    }
                }
            }
            catch { }
        }

        private async System.Threading.Tasks.Task NotifyServiceConfigUpdate()
        {
            try
            {
                using (var client = new System.IO.Pipes.NamedPipeClientStream(".", "LipiImePipe", System.IO.Pipes.PipeDirection.InOut))
                {
                    await client.ConnectAsync(1000);
                    using (var writer = new System.IO.StreamWriter(client, System.Text.Encoding.UTF8, 1024, true))
                    using (var reader = new System.IO.StreamReader(client, System.Text.Encoding.UTF8, true, 1024, true))
                    {
                        writer.AutoFlush = true;
                        await writer.WriteLineAsync("RELOAD_CONFIG");
                        await reader.ReadLineAsync(); // Wait for OK
                    }
                }
            }
            catch { }
        }
    }
}
