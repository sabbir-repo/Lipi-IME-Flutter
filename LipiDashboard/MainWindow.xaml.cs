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
            // For now, we only have the General page which is inline.
            // If we added more pages, we'd navigate the ContentFrame here.
        }
    }
}
