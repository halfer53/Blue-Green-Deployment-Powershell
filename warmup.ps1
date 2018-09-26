$siteBlue = "http://alwaysup-blue:84"
$siteGreen = "http://alwaysup-green:86"
$siteBlueName = "mkr_umbraco_blue"
$siteGreenName = "mkr_umbraco_green"
$pathBlue = "D:\wwwroot\mkr_umbraco_blue"
$pathGreen = "D:\wwwroot\mkr_umbraco_green"
$pathBlueContent = (Get-Content $pathBlue\up.html)

$siteToWarm = $siteBlue
$pathToBringDown = $pathGreen
$siteToBringDown = $siteGreenName
$siteToBringUp = $siteBlueName
$pathToBringUp = $pathBlue

$pages = '/yasi', '/contact', '/yasi/industry.htm', '/yasi/media.htm', 
            '/scholarship/', '/teacher', '/course', '/about', '/ieltsallaspects/speaking.htm',
            '/ieltsallaspects/listening.htm', '/ieltsallaspects/reading.htm','/ieltsallaspects/writing.htm'

function WarmSite($siteToWarm){
    $time = Measure-Command {
        $res = Invoke-WebRequest $siteToWarm
    }
    $ms = $time.TotalMilliSeconds
    If ($ms -ge 400) {
        Write-Host "$($res.StatusCode) from   $($siteToWarm) in $($ms)ms" -foreground "yellow"
    }
    return $ms
}

Import-Module WebAdministration

if ($pathBlueContent -contains 'up')
{
    $siteToWarm = $siteGreen
    $pathToBringUp = $pathGreen
    $siteToBringUp = $siteGreenName
    $pathToBringDown = $pathBlue
    $siteToBringDown = $siteBlueName
}

# Copy media
Write-Host "Copying media files from $pathToBringDown\media to $pathToBringUp\media "
Copy-Item -Path "$pathToBringDown\media" -Recurse -Destination "$pathToBringUp\media"

# Copy App_Data
Write-Host "Copying App_Data from $pathToBringDown\App_Data $pathToBringUp\App_Data"
$exclude_folders = "TEMP","Logs"
$exclude_files = "umbraco.config"
Get-ChildItem "$pathToBringDown\App_Data" -Directory | 
    Where-Object{$_.Name -notin $excludes} | 
    Copy-Item -Destination "$pathToBringUp\App_Data" -Recurse -Force

$sitestatus = Get-WebsiteState -Name $siteToBringUp
if ($sitestatus.Value -eq "Started"){
    Write-Host "Warming up $($siteToWarm)"
    Do {
        $ms = WarmSite($siteToWarm)
    } While ($ms -ge 500)
    Write-Host "$($res.StatusCode) from $($siteToWarm) in $($ms)ms" -foreground "cyan"

    Write-Host "Bringing $($pathToBringUp) up" -foreground "cyan"
    (Get-Content $pathToBringUp\up.html).replace('down', 'up') | Set-Content $pathToBringUp\up.html
}else{
    Write-Host "$siteToBringUp $($siteToWarm) is stopped" -foreground "red"
}


Write-Host "Bringing $($siteToBringDown) $($pathToBringDown) down"
    (Get-Content $pathToBringDown\up.html).replace('up', 'down') | Set-Content $pathToBringDown\up.html
Stop-Website -Name $siteToBringDown
Stop-WebAppPool -Name $siteToBringDown

foreach ($page in $pages){
    $item = "$siteToWarm$page"
    $ms = WarmSite($item)
}
