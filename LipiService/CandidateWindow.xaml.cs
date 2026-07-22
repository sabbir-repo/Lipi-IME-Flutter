using System;
using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Media;

namespace LipiService
{
    public class CandidateItem
    {
        public string IndexText { get; set; } = "";
        public string Word { get; set; } = "";
        public bool IsSelected { get; set; }
        
        public System.Windows.Media.Brush BackgroundBrush { get; set; }
        public System.Windows.Media.Brush ForegroundBrush { get; set; }
        public double FontSize { get; set; }
        public System.Windows.Media.FontFamily FontFamily { get; set; }
    }

    public partial class CandidateWindow : Window
    {
        private const int WS_EX_NOACTIVATE = 0x08000000;
        private const int WS_EX_TOOLWINDOW = 0x00000080;

        protected override void OnSourceInitialized(EventArgs e)
        {
            base.OnSourceInitialized(e);
            var helper = new System.Windows.Interop.WindowInteropHelper(this);
            int exStyle = GetWindowLong(helper.Handle, GWL_EXSTYLE);
            SetWindowLong(helper.Handle, GWL_EXSTYLE, exStyle | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW);
        }

        private const int GWL_EXSTYLE = -20;
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern int GetWindowLong(IntPtr hwnd, int index);
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern int SetWindowLong(IntPtr hwnd, int index, int newStyle);

        public ObservableCollection<CandidateItem> Suggestions { get; set; }

        public CandidateWindow()
        {
            InitializeComponent();
            Suggestions = new ObservableCollection<CandidateItem>();
            SuggestionsList.ItemsSource = Suggestions;
        }

        public void UpdateSuggestions(string[] words, int selectedIndex, string bufferText = "", LipiService.Services.Settings settings = null)
        {
            if (settings != null)
            {
                try {
                    RootBorder.Background = (System.Windows.Media.Brush)new BrushConverter().ConvertFromString(settings.SuggestionBgColor);
                } catch { }
            }

            if (string.IsNullOrEmpty(bufferText))
            {
                BufferContainer.Visibility = Visibility.Collapsed;
            }
            else
            {
                BufferContainer.Visibility = Visibility.Visible;
                BufferTextBlock.Text = " " + bufferText.ToUpper() + " ";
            }
            
            Suggestions.Clear();
            System.Windows.Media.Brush normalBg = System.Windows.Media.Brushes.Transparent;
            System.Windows.Media.Brush selectedBg = new SolidColorBrush(System.Windows.Media.Color.FromArgb(255, 60, 60, 60));
            System.Windows.Media.Brush normalFg = new SolidColorBrush(System.Windows.Media.Color.FromArgb(255, 200, 200, 200));
            System.Windows.Media.Brush selectedFg = System.Windows.Media.Brushes.White;
            double fontSize = 18.0;
            System.Windows.Media.FontFamily fontFamily = new System.Windows.Media.FontFamily("Segoe UI");

            if (settings != null)
            {
                try {
                    selectedBg = (System.Windows.Media.Brush)new BrushConverter().ConvertFromString(settings.SuggestionSelectedBgColor);
                    normalFg = (System.Windows.Media.Brush)new BrushConverter().ConvertFromString(settings.SuggestionTextColor);
                    selectedFg = (System.Windows.Media.Brush)new BrushConverter().ConvertFromString(settings.SuggestionSelectedTextColor);
                    fontSize = settings.SuggestionFontSize;
                    fontFamily = new System.Windows.Media.FontFamily(settings.SuggestionFontFamily);
                } catch { }
            }

            for (int i = 0; i < words.Length; i++)
            {
                Suggestions.Add(new CandidateItem
                {
                    IndexText = (i + 1).ToString() + ".",
                    Word = words[i],
                    IsSelected = (i == selectedIndex),
                    BackgroundBrush = (i == selectedIndex) ? selectedBg : normalBg,
                    ForegroundBrush = (i == selectedIndex) ? selectedFg : normalFg,
                    FontSize = fontSize,
                    FontFamily = fontFamily
                });
            }
        }
    }
}
