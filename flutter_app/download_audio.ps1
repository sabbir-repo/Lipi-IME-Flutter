$urls = @(
"https://cdn.freesound.org/previews/766/766640_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766639_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766638_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766637_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766635_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766634_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766633_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766632_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766631_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766630_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766629_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766628_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766627_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766626_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766625_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766624_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766622_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766623_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766621_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766620_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766619_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766618_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766617_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766616_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766614_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766613_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766612_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766611_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766610_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766609_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766608_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766607_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766606_7862587-lq.mp3"
"https://cdn.freesound.org/previews/766/766605_7862587-lq.mp3"
)

$outDir = "E:\Python Projects\Google Input Tools to Flutter desktop\flutter_app\assets\audio"
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir
}

$i = 1
foreach ($url in $urls) {
    # Extract filename from URL
    $filename = $url.Split('/')[-1]
    # Optionally we can name them key_1.mp3, key_2.mp3 etc.
    $outFile = Join-Path -Path $outDir -ChildPath "key_$i.mp3"
    Write-Host "Downloading $url to $outFile"
    Invoke-WebRequest -Uri $url -OutFile $outFile
    $i++
}
Write-Host "All downloads complete."
