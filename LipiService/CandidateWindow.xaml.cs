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
        
        private System.Windows.Media.Brush _defaultBg = new SolidColorBrush(System.Windows.Media.Color.FromRgb(250, 250, 250));
        private System.Windows.Media.Brush _selectedBg = new SolidColorBrush(System.Windows.Media.Color.FromRgb(220, 230, 255));
        public System.Windows.Media.Brush BackgroundBrush => IsSelected ? _selectedBg : _defaultBg;
        public System.Windows.Media.Brush ForegroundBrush => IsSelected ? System.Windows.Media.Brushes.Black : System.Windows.Media.Brushes.Gray;
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

        public void UpdateSuggestions(string[] words, int selectedIndex, string bufferText = "")
        {
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
            for (int i = 0; i < words.Length; i++)
            {
                Suggestions.Add(new CandidateItem
                {
                    IndexText = (i + 1).ToString() + ".",
                    Word = words[i],
                    IsSelected = (i == selectedIndex)
                });
            }
        }
    }
}
