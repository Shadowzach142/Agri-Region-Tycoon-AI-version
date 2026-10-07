Add-Type -AssemblyName System.Drawing

function Analyze-Png($path) {
    $img = New-Object System.Drawing.Bitmap($path)
    $w = $img.Width
    $h = $img.Height
    $minX = $w; $maxX = -1; $minY = $h; $maxY = -1
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = $img.GetPixel($x, $y)
            if ($c.A -gt 10) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    $img.Dispose()
    Write-Output "$([System.IO.Path]::GetFileName($path)): ${w}x${h}, bounds: X[$minX..$maxX], Y[$minY..$maxY]"
}

Analyze-Png "assets/sprites/ground/GROUND-Bare/Bare1.png"
Analyze-Png "assets/sprites/ground/GROUND-Light-Grass/LightGrass1.png"
