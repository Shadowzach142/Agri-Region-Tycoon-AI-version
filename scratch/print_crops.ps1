Add-Type -AssemblyName System.Drawing
Get-ChildItem -Path "assets/sprites/Field/Crops" -Recurse -Filter "*.png" | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    Write-Output "$($_.Name) : $($img.Width) x $($img.Height)"
    $img.Dispose()
}
