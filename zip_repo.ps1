$tempDir = "D:\PortableDev\Temp\LipiIME_Zip_Temp"
if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Path $tempDir
Copy-Item -Path "e:\Python Projects\Google Input Tools to Flutter desktop\*" -Destination $tempDir -Recurse
Get-ChildItem -Path $tempDir -Include ".git", ".vs", "bin", "obj", "packages", "Solution Box Of Other AI" -Recurse -Force | Remove-Item -Recurse -Force
$zipPath = "C:\Users\Sabbir Ahmmed\Desktop\LipiIME_Source_Latest.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
Remove-Item -Recurse -Force $tempDir
Write-Host "Zip created at $zipPath"
