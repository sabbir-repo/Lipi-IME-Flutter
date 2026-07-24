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
            
            try {
                SugBgColorPicker.Color = Microsoft.UI.ColorHelper.FromArgb(255, 
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionBgColor.Substring(1, 2), 16),
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionBgColor.Substring(3, 2), 16),
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionBgColor.Substring(5, 2), 16));
                
                SugTextColorPicker.Color = Microsoft.UI.ColorHelper.FromArgb(255, 
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionTextColor.Substring(1, 2), 16),
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionTextColor.Substring(3, 2), 16),
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionTextColor.Substring(5, 2), 16));

                SugSelBgColorPicker.Color = Microsoft.UI.ColorHelper.FromArgb(255, 
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionSelectedBgColor.Substring(1, 2), 16),
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionSelectedBgColor.Substring(3, 2), 16),
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionSelectedBgColor.Substring(5, 2), 16));

                SugSelTextColorPicker.Color = Microsoft.UI.ColorHelper.FromArgb(255, 
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionSelectedTextColor.Substring(1, 2), 16),
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionSelectedTextColor.Substring(3, 2), 16),
                    Convert.ToByte(_settingsManager.CurrentSettings.SuggestionSelectedTextColor.Substring(5, 2), 16));
            } catch { }

            SugFontSizeInput.Value = _settingsManager.CurrentSettings.SuggestionFontSize;
            SugFontFamilyInput.Text = _settingsManager.CurrentSettings.SuggestionFontFamily;
            SugItemPadVInput.Value = _settingsManager.CurrentSettings.SuggestionItemPaddingV;
            SugItemPadHInput.Value = _settingsManager.CurrentSettings.SuggestionItemPaddingH;
            SugWinPadInput.Value = _settingsManager.CurrentSettings.SuggestionWindowPadding;
            SugBgOpacitySlider.Value = _settingsManager.CurrentSettings.SuggestionBgOpacity;
            SugBlurSwitch.IsOn = _settingsManager.CurrentSettings.SuggestionBlurEnabled;
            SugLiquidGlassSwitch.IsOn = _settingsManager.CurrentSettings.SuggestionLiquidGlass;
            SugGlassTintSlider.Value = _settingsManager.CurrentSettings.SuggestionGlassTintOpacity;
            SugGlassCornerSlider.Value = _settingsManager.CurrentSettings.SuggestionGlassCornerRadius;
            SugGlassHighlightSlider.Value = _settingsManager.CurrentSettings.SuggestionGlassHighlightOpacity;
            
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



        private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
        {
            if (args.IsSettingsSelected)
            {
                GeneralPanel.Visibility = Visibility.Collapsed;
                AboutPanel.Visibility = Visibility.Collapsed;
                CustomDictionaryPanel.Visibility = Visibility.Collapsed;
                TypingRulesPanel.Visibility = Visibility.Collapsed;
                SuggestionUIScroller.Visibility = Visibility.Collapsed;
                SettingsPanel.Visibility = Visibility.Visible;
            }
            else
            {
                var selectedItem = args.SelectedItem as NavigationViewItem;
                string tag = selectedItem?.Tag?.ToString();

                GeneralPanel.Visibility = tag == "General" ? Visibility.Visible : Visibility.Collapsed;
                TypingRulesPanel.Visibility = tag == "TypingRules" ? Visibility.Visible : Visibility.Collapsed;
                CustomDictionaryPanel.Visibility = tag == "CustomDictionary" ? Visibility.Visible : Visibility.Collapsed;
                SuggestionUIScroller.Visibility = tag == "SuggestionUI" ? Visibility.Visible : Visibility.Collapsed;
                SettingsPanel.Visibility = Visibility.Collapsed;
                AboutPanel.Visibility = tag == "About" ? Visibility.Visible : Visibility.Collapsed;

                if (tag == "CustomDictionary")
                {
                    LoadDictionary();
                }
            }
        }

        private string ColorToHex(Windows.UI.Color color)
        {
            return $"#{color.R:X2}{color.G:X2}{color.B:X2}";
        }

        private async void SugUI_ColorPickerChanged(ColorPicker sender, ColorChangedEventArgs args)
        {
            if (!_isLoaded) return;
            if (sender == SugBgColorPicker) _settingsManager.CurrentSettings.SuggestionBgColor = ColorToHex(args.NewColor);
            if (sender == SugTextColorPicker) _settingsManager.CurrentSettings.SuggestionTextColor = ColorToHex(args.NewColor);
            if (sender == SugSelBgColorPicker) _settingsManager.CurrentSettings.SuggestionSelectedBgColor = ColorToHex(args.NewColor);
            if (sender == SugSelTextColorPicker) _settingsManager.CurrentSettings.SuggestionSelectedTextColor = ColorToHex(args.NewColor);
            
            _settingsManager.SaveSettings();
            await NotifyServiceConfigUpdate();
        }

        private async void SugUI_NumberBoxChanged(NumberBox sender, NumberBoxValueChangedEventArgs args)
        {
            if (!_isLoaded || double.IsNaN(args.NewValue)) return;
            if (sender == SugFontSizeInput) _settingsManager.CurrentSettings.SuggestionFontSize = args.NewValue;
            if (sender == SugItemPadVInput) _settingsManager.CurrentSettings.SuggestionItemPaddingV = args.NewValue;
            if (sender == SugItemPadHInput) _settingsManager.CurrentSettings.SuggestionItemPaddingH = args.NewValue;
            if (sender == SugWinPadInput) _settingsManager.CurrentSettings.SuggestionWindowPadding = args.NewValue;
            
            _settingsManager.SaveSettings();
            await NotifyServiceConfigUpdate();
        }

        private async void SugUI_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (!_isLoaded) return;
            _settingsManager.CurrentSettings.SuggestionFontFamily = SugFontFamilyInput.Text;
            _settingsManager.SaveSettings();
            await NotifyServiceConfigUpdate();
        }

        private async void SugUI_OpacityChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
        {
            if (!_isLoaded) return;
            _settingsManager.CurrentSettings.SuggestionBgOpacity = e.NewValue;
            _settingsManager.SaveSettings();
            await NotifyServiceConfigUpdate();
        }

        private async void SugBlurSwitch_Toggled(object sender, RoutedEventArgs e)
        {
            if (!_isLoaded) return;
            _settingsManager.CurrentSettings.SuggestionBlurEnabled = SugBlurSwitch.IsOn;
            _settingsManager.SaveSettings();
            await NotifyServiceConfigUpdate();
        }

        private async void SugLiquidGlassSwitch_Toggled(object sender, RoutedEventArgs e)
        {
            if (!_isLoaded) return;
            _settingsManager.CurrentSettings.SuggestionLiquidGlass = SugLiquidGlassSwitch.IsOn;
            _settingsManager.SaveSettings();
            await NotifyServiceConfigUpdate();
        }

        private async void SugGlass_ValueChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
        {
            if (!_isLoaded) return;
            if (sender == SugGlassTintSlider) _settingsManager.CurrentSettings.SuggestionGlassTintOpacity = e.NewValue;
            else if (sender == SugGlassCornerSlider) _settingsManager.CurrentSettings.SuggestionGlassCornerRadius = e.NewValue;
            else if (sender == SugGlassHighlightSlider) _settingsManager.CurrentSettings.SuggestionGlassHighlightOpacity = e.NewValue;
            _settingsManager.SaveSettings();
            await NotifyServiceConfigUpdate();
        }

        private async void ClearCacheButton_Click(object sender, RoutedEventArgs e)
        {
            ClearCacheButton.IsEnabled = false;
            try
            {
                using (var client = new System.IO.Pipes.NamedPipeClientStream(".", "LipiImePipe", System.IO.Pipes.PipeDirection.InOut))
                {
                    await client.ConnectAsync(2000); // 2 second timeout
                    using (var writer = new System.IO.StreamWriter(client, new System.Text.UTF8Encoding(false), 1024, true))
                    using (var reader = new System.IO.StreamReader(client, new System.Text.UTF8Encoding(false), true, 1024, true))
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
                    if (dict != null && dict.ContainsKey("custom_dictionary"))
                    {
                        foreach (var kvp in dict["custom_dictionary"])
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
                
                if (!dict.ContainsKey("custom_dictionary")) dict["custom_dictionary"] = new Dictionary<string, List<string>>();
                
                if (dict["custom_dictionary"].ContainsKey(eng))
                {
                    dict["custom_dictionary"][eng].Remove(bn);
                    dict["custom_dictionary"][eng].Insert(0, bn);
                }
                else
                {
                    dict["custom_dictionary"][eng] = new List<string> { bn };
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
                        
                        if (dict != null && dict.ContainsKey("custom_dictionary") && dict["custom_dictionary"].ContainsKey(eng))
                        {
                            dict["custom_dictionary"].Remove(eng);
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
                    using (var writer = new System.IO.StreamWriter(client, new System.Text.UTF8Encoding(false), 1024, true))
                    using (var reader = new System.IO.StreamReader(client, new System.Text.UTF8Encoding(false), true, 1024, true))
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
                    using (var writer = new System.IO.StreamWriter(client, new System.Text.UTF8Encoding(false), 1024, true))
                    using (var reader = new System.IO.StreamReader(client, new System.Text.UTF8Encoding(false), true, 1024, true))
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
