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
        public Thickness ItemPadding { get; set; }
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
            this.SizeChanged += CandidateWindow_SizeChanged;
        }

        private double _targetX = double.NaN;
        private double _targetY = double.NaN;

        public void SetPosition(double x, double y)
        {
            _targetX = x;
            _targetY = y;
            UpdatePosition();
        }

        private void CandidateWindow_SizeChanged(object sender, SizeChangedEventArgs e)
        {
            UpdatePosition();
        }

        // Win32 replacement for System.Windows.Forms.Screen.FromPoint(...).WorkingArea
        // (WinForms was removed from this project to reduce memory usage).
        [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
        private struct NativePoint { public int X; public int Y; }

        [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
        private struct NativeRect { public int Left; public int Top; public int Right; public int Bottom; }

        [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
        private struct NativeMonitorInfo { public int cbSize; public NativeRect rcMonitor; public NativeRect rcWork; public uint dwFlags; }

        private const uint MONITOR_DEFAULTTONEAREST = 2;

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern IntPtr MonitorFromPoint(NativePoint pt, uint dwFlags);

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern bool GetMonitorInfo(IntPtr hMonitor, ref NativeMonitorInfo lpmi);

        // --- Blur-behind (Win10/11 SetWindowCompositionAttribute) support ---
        private const int ACCENT_DISABLED = 0;
        private const int ACCENT_ENABLE_BLURBEHIND = 3;
        private const int ACCENT_ENABLE_ACRYLICBLURBEHIND = 4;
        private const int WCA_ACCENT_POLICY = 19;

        [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
        private struct AccentPolicy { public int AccentState; public int AccentFlags; public uint GradientColor; public int AnimationId; }

        [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
        private struct WindowCompositionAttributeData { public int Attribute; public IntPtr Data; public int SizeOfData; }

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

        // Track the last applied accent so redundant Win32 calls are skipped on every SHOW
        private int _appliedAccentState = -1;
        private uint _appliedGradient = 0xDEADBEEF;

        private void ApplyBackdrop(int accentState, uint gradientColor)
        {
            if (_appliedAccentState == accentState && _appliedGradient == gradientColor) return;

            var helper = new System.Windows.Interop.WindowInteropHelper(this);
            IntPtr hwnd = helper.Handle;
            if (hwnd == IntPtr.Zero) return; // window not created yet; retried on next update

            try
            {
                var accent = new AccentPolicy
                {
                    AccentState = accentState,
                    AccentFlags = 2,
                    GradientColor = gradientColor, // AABBGGRR; used as tint by the acrylic effect
                    AnimationId = 0
                };

                int size = System.Runtime.InteropServices.Marshal.SizeOf<AccentPolicy>();
                IntPtr pAccent = System.Runtime.InteropServices.Marshal.AllocHGlobal(size);
                try
                {
                    System.Runtime.InteropServices.Marshal.StructureToPtr(accent, pAccent, false);
                    var data = new WindowCompositionAttributeData
                    {
                        Attribute = WCA_ACCENT_POLICY,
                        Data = pAccent,
                        SizeOfData = size
                    };
                    SetWindowCompositionAttribute(hwnd, ref data);
                    _appliedAccentState = accentState;
                    _appliedGradient = gradientColor;
                }
                finally
                {
                    System.Runtime.InteropServices.Marshal.FreeHGlobal(pAccent);
                }
            }
            catch { /* unsupported OS: silently ignore */ }
        }

        private void UpdatePosition()
        {
            if (double.IsNaN(_targetX) || double.IsNaN(_targetY)) return;

            // Find the work area of the monitor containing the caret point
            // (same behavior as the old Screen.FromPoint on multi-monitor setups).
            var pt = new NativePoint { X = (int)_targetX, Y = (int)_targetY };
            var mi = new NativeMonitorInfo { cbSize = System.Runtime.InteropServices.Marshal.SizeOf<NativeMonitorInfo>() };
            NativeRect workArea;
            IntPtr hMonitor = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
            if (hMonitor != IntPtr.Zero && GetMonitorInfo(hMonitor, ref mi))
            {
                workArea = mi.rcWork;
            }
            else
            {
                // Fallback: primary monitor work area
                workArea = new NativeRect
                {
                    Left = (int)SystemParameters.WorkArea.Left,
                    Top = (int)SystemParameters.WorkArea.Top,
                    Right = (int)SystemParameters.WorkArea.Right,
                    Bottom = (int)SystemParameters.WorkArea.Bottom
                };
            }
            
            double w = this.ActualWidth;
            double h = this.ActualHeight;
            if (w == 0 || h == 0) return;

            double newLeft = _targetX;
            double newTop = _targetY;

            if (newLeft + w > workArea.Right) {
                newLeft = workArea.Right - w;
            }
            
            if (newTop + h > workArea.Bottom) {
                newTop = _targetY - h - 35; // 35 is approx text height + padding to push above cursor
            }

            if (newLeft < workArea.Left) newLeft = workArea.Left;
            if (newTop < workArea.Top) newTop = workArea.Top;

            this.Left = newLeft;
            this.Top = newTop;
        }

        public void UpdateSuggestions(string[] words, int selectedIndex, string bufferText = "", LipiService.Services.Settings settings = null)
        {
            if (settings != null)
            {
                try {
                    var bgColor = (System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(settings.SuggestionBgColor);

                    if (settings.SuggestionLiquidGlass)
                    {
                        // --- Liquid glass: acrylic blur-behind + colour tint + edge highlight ---
                        double tintPct = Math.Max(0.0, Math.Min(100.0, settings.SuggestionGlassTintOpacity));
                        byte tintAlpha = (byte)Math.Round(tintPct / 100.0 * 255.0);
                        // Acrylic gradient colour is AABBGGRR
                        uint tint = ((uint)tintAlpha << 24) | ((uint)bgColor.B << 16) | ((uint)bgColor.G << 8) | bgColor.R;
                        ApplyBackdrop(ACCENT_ENABLE_ACRYLICBLURBEHIND, tint);

                        // Nearly-transparent WPF background so the acrylic glass shows through
                        RootBorder.Background = new SolidColorBrush(System.Windows.Media.Color.FromArgb(1, bgColor.R, bgColor.G, bgColor.B));

                        // Glass parameters: rounded corners + subtle white edge highlight
                        double radius = Math.Max(0.0, settings.SuggestionGlassCornerRadius);
                        RootBorder.CornerRadius = new CornerRadius(radius);
                        double hlPct = Math.Max(0.0, Math.Min(100.0, settings.SuggestionGlassHighlightOpacity));
                        byte hlAlpha = (byte)Math.Round(hlPct / 100.0 * 255.0);
                        RootBorder.BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromArgb(hlAlpha, 255, 255, 255));
                    }
                    else
                    {
                        // --- Solid / simple transparent+blur mode (original behavior) ---
                        double opacityPct = settings.SuggestionBgOpacity;
                        if (double.IsNaN(opacityPct)) opacityPct = 100.0;
                        opacityPct = Math.Max(0.0, Math.Min(100.0, opacityPct));
                        bgColor.A = (byte)Math.Round(opacityPct / 100.0 * 255.0);
                        RootBorder.Background = new SolidColorBrush(bgColor);
                        RootBorder.CornerRadius = new CornerRadius(8);
                        RootBorder.BorderBrush = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString("#2c2c36"));
                        ApplyBackdrop(settings.SuggestionBlurEnabled ? ACCENT_ENABLE_BLURBEHIND : ACCENT_DISABLED, 0x00FFFFFF);
                    }
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

            double itemPadV = 5.0;
            double itemPadH = 10.0;

            if (settings != null)
            {
                try {
                    selectedBg = (System.Windows.Media.Brush)new BrushConverter().ConvertFromString(settings.SuggestionSelectedBgColor);
                    normalFg = (System.Windows.Media.Brush)new BrushConverter().ConvertFromString(settings.SuggestionTextColor);
                    selectedFg = (System.Windows.Media.Brush)new BrushConverter().ConvertFromString(settings.SuggestionSelectedTextColor);
                    fontSize = settings.SuggestionFontSize;
                    fontFamily = new System.Windows.Media.FontFamily(settings.SuggestionFontFamily);
                    itemPadV = settings.SuggestionItemPaddingV;
                    itemPadH = settings.SuggestionItemPaddingH;
                    RootBorder.Padding = new Thickness(settings.SuggestionWindowPadding);
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
                    FontFamily = fontFamily,
                    ItemPadding = new Thickness(itemPadH, itemPadV, itemPadH, itemPadV)
                });
            }
        }
    }
}
