$siteBlue = "http://alwaysup-blue:84"
$siteGreen = "http://alwaysup-green:86"

$time = Measure-Command {
    $res = Invoke-WebRequest $siteBlue
}
$ms = $time.TotalMilliSeconds
Write-Host "$($res.StatusCode) from $($siteBlue) in $($ms)ms" -foreground "cyan"

$time = Measure-Command {
    $res = Invoke-WebRequest $siteGreen
}
$ms = $time.TotalMilliSeconds
Write-Host "$($res.StatusCode) from $($siteGreen) in $($ms)ms" -foreground "cyan"