param(
  [Parameter(Mandatory=$true)][string]$Path,
  [string]$Printer = "",
  [int]$Copies = 1,
  [string]$Pages = "",
  [switch]$Mono,
  [switch]$Duplex,
  [int]$Dpi = 300
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Drawing
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]

$ext = [System.WindowsRuntimeSystemExtensions].GetMethods()
$asTaskOp = $ext | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
$asTaskAct = $ext | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | Select-Object -First 1
function AwaitOp($op, [Type]$t) { $task = $asTaskOp.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait() | Out-Null; $task.Result }
function AwaitAct($op) { $task = $asTaskAct.Invoke($null, @($op)); $task.Wait() | Out-Null }

$file = AwaitOp ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Path)) ([Windows.Storage.StorageFile])
$doc = AwaitOp ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
$count = [int]$doc.PageCount

$want = New-Object 'System.Collections.Generic.HashSet[int]'
if ([string]::IsNullOrWhiteSpace($Pages)) { 1..$count | ForEach-Object { [void]$want.Add($_) } }
else {
  foreach ($part in $Pages.Split(',')) {
    $p = $part.Trim(); if (-not $p) { continue }
    if ($p -match '^(\d+)-(\d+)$') { [int]$Matches[1]..[int]$Matches[2] | ForEach-Object { [void]$want.Add($_) } }
    elseif ($p -match '^\d+$') { [void]$want.Add([int]$p) }
    else { throw "Bad page range: $p" }
  }
}

$images = New-Object 'System.Collections.Generic.List[System.Drawing.Image]'
for ($i = 0; $i -lt $count; $i++) {
  if (-not $want.Contains($i + 1)) { continue }
  $page = $doc.GetPage([uint32]$i)
  $opt = New-Object Windows.Data.Pdf.PdfPageRenderOptions
  $opt.DestinationWidth = [uint32][math]::Round($page.Size.Width * $Dpi / 96)
  $opt.DestinationHeight = [uint32][math]::Round($page.Size.Height * $Dpi / 96)
  $ras = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
  AwaitAct ($page.RenderToStreamAsync($ras, $opt))
  $ras.Seek(0)
  $net = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($ras)
  $ms = New-Object System.IO.MemoryStream
  $net.CopyTo($ms); $ms.Position = 0
  $images.Add([System.Drawing.Image]::FromStream($ms))
  $page.Dispose()
}
if ($images.Count -eq 0) { throw "No pages selected (document has $count pages)" }

$pd = New-Object System.Drawing.Printing.PrintDocument
if ($Printer) { $pd.PrinterSettings.PrinterName = $Printer }
if (-not $pd.PrinterSettings.IsValid) { throw "Printer not found: $Printer" }
$pd.PrinterSettings.Copies = [int16]$Copies
$pd.DefaultPageSettings.Color = -not $Mono
if ($Duplex) { $pd.PrinterSettings.Duplex = [System.Drawing.Printing.Duplex]::Vertical }
$pd.DocumentName = [IO.Path]::GetFileName($Path)
$pd.PrintController = New-Object System.Drawing.Printing.StandardPrintController
$script:idx = 0
$pd.add_PrintPage({
  param($s, $e)
  $img = $images[$script:idx]
  $pb = $e.PageBounds
  $e.Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $e.Graphics.DrawImage($img, [float](-$e.PageSettings.HardMarginX), [float](-$e.PageSettings.HardMarginY), [float]$pb.Width, [float]$pb.Height)
  $script:idx++
  $e.HasMorePages = ($script:idx -lt $images.Count)
})
$pd.Print()
Write-Output ("OK pages={0} printer={1} copies={2}" -f $images.Count, $pd.PrinterSettings.PrinterName, $Copies)
