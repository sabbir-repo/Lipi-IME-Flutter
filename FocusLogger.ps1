Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

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
}
"@

Write-Host "Focus Logger Started. Switch to Chrome and type something..."
for ($i = 0; $i -lt 15; $i++) {
    $fg = [Win32]::GetForegroundWindow()
    if ($fg -ne [IntPtr]::Zero) {
        $pid = 0
        $threadId = [Win32]::GetWindowThreadProcessId($fg, [ref]$pid)
        
        $gti = New-Object Win32+GUITHREADINFO
        $gti.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($gti)
        
        if ([Win32]::GetGUIThreadInfo($threadId, [ref]$gti)) {
            $focusHwnd = $gti.hwndFocus
            if ($focusHwnd -ne [IntPtr]::Zero) {
                $sb = New-Object System.Text.StringBuilder 256
                [Win32]::GetClassName($focusHwnd, $sb, 256) | Out-Null
                Write-Host "[$i] Focused Class: $($sb.ToString())"
            } else {
                Write-Host "[$i] No focused child window."
            }
        }
    }
    Start-Sleep -Seconds 1
}
