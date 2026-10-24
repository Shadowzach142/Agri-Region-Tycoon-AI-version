Add-Type -AssemblyName System.Drawing
$files = "byahero.png","Gensan-seaport.png","Koronadal-Wholesale.png","Tacurong-Grain-mill.png","Cold Storage.png"
foreach ($f in $files) {
  $bmp = [System.Drawing.Bitmap]::FromFile("c:\Users\ADMIN\Documents\agri-region-ai-version\assets\sprites\buildings\$f")
  $w=$bmp.Width; $h=$bmp.Height
  $xmin=$w;$xmax=-1;$ymin=$h;$ymax=-1
  $lefty=0;$righty=0;$botx=0
  for($y=0;$y -lt $h;$y++){ for($x=0;$x -lt $w;$x++){
    if($bmp.GetPixel($x,$y).A -gt 40){
      if($x -lt $xmin){$xmin=$x;$lefty=$y}
      if($x -gt $xmax){$xmax=$x;$righty=$y}
      if($y -lt $ymin){$ymin=$y}
      if($y -ge $ymax){$ymax=$y;$botx=$x}
    }}}
  "{0}: size {1}x{2} bbox x[{3}-{4}] y[{5}-{6}] leftY={7} rightY={8} botX={9}" -f $f,$w,$h,$xmin,$xmax,$ymin,$ymax,$lefty,$righty,$botx
  $bmp.Dispose()
}
