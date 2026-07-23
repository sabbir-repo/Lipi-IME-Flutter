Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Write-Host "UI Automation Logger Started. Switch to Chrome and type something..."
for ($i = 0; $i -lt 15; $i++) {
    try {
        $focusedElement = [System.Windows.Automation.AutomationElement]::FocusedElement
        if ($focusedElement) {
            Write-Host "[$i] Focused ClassName: $($focusedElement.Current.ClassName)"
            Write-Host "    ControlType: $($focusedElement.Current.ControlType.ProgrammaticName)"
            Write-Host "    Name: $($focusedElement.Current.Name)"
        }
    } catch {
        Write-Host "[$i] Error getting focused element"
    }
    Start-Sleep -Seconds 1
}
