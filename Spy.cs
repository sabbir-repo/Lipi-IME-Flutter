using System;
using System.Runtime.InteropServices;
using System.Text;

class Spy {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool EnumChildWindows(IntPtr hwndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool GetGUIThreadInfo(uint idThread, ref GUITHREADINFO lpgui);

    [StructLayout(LayoutKind.Sequential)]
    public struct GUITHREADINFO {
        public uint cbSize;
        public uint flags;
        public IntPtr hwndActive;
        public IntPtr hwndFocus;
        public IntPtr hwndCapture;
        public IntPtr hwndMenuOwner;
        public IntPtr hwndMoveSize;
        public IntPtr hwndCaret;
        public RECT rcCaret;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int left;
        public int top;
        public int right;
        public int bottom;
    }

    static void Main() {
        Console.WriteLine("Focus Logger Started. Switch to Chrome and type something in 5 seconds...");
        System.Threading.Thread.Sleep(5000);

        IntPtr fg = GetForegroundWindow();
        if (fg != IntPtr.Zero) {
            StringBuilder sbClass = new StringBuilder(256);
            StringBuilder sbText = new StringBuilder(256);
            GetClassName(fg, sbClass, 256);
            GetWindowText(fg, sbText, 256);
            Console.WriteLine($"Foreground Window: HWND={fg}, Class={sbClass}, Text={sbText}");

            uint pid;
            uint threadId = GetWindowThreadProcessId(fg, out pid);
            
            GUITHREADINFO gti = new GUITHREADINFO();
            gti.cbSize = (uint)Marshal.SizeOf(typeof(GUITHREADINFO));
            
            if (GetGUIThreadInfo(threadId, ref gti)) {
                Console.WriteLine($"GUIThreadInfo: hwndFocus={gti.hwndFocus}, hwndActive={gti.hwndActive}");
                if (gti.hwndFocus != IntPtr.Zero) {
                    GetClassName(gti.hwndFocus, sbClass, 256);
                    Console.WriteLine($"Focused Class: {sbClass}");
                }
            } else {
                Console.WriteLine("GetGUIThreadInfo failed.");
            }

            Console.WriteLine("Child Windows:");
            EnumChildWindows(fg, (hWnd, lParam) => {
                GetClassName(hWnd, sbClass, 256);
                GetWindowText(hWnd, sbText, 256);
                Console.WriteLine($"  Child HWND={hWnd}, Class={sbClass}, Text={sbText}");
                return true;
            }, IntPtr.Zero);
        }
    }
}
