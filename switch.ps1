param (
    [switch]$notransfer = $false
 )

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'

$siteBlue = "http://alwaysup-blue:84"
$siteGreen = "http://alwaysup-green:86"
$siteBlueName = "mkr_umbraco_blue"
$siteGreenName = "mkr_umbraco_green"
$pathBlue = "C:\wwwroot\mkr_umbraco_blue"
$pathGreen = "C:\wwwroot\mkr_umbraco_green"
$serverFarmName = "alwaysup"
$greenServerAddress = "alwaysup-green"
$blueServerAddress = "alwaysup-blue"

$pathBlueContent = (Get-Content $pathBlue\up.html)
$pathGreenContent = (Get-Content $pathGreen\up.html)

$siteToWarm = $siteBlue
$pathToBringDown = $pathGreen
$siteToBringDown = $siteGreenName
$siteToBringUp = $siteBlueName
$pathToBringUp = $pathBlue
$ServerToBringDown = $greenServerAddress
$ServerToBringUp = $blueServerAddress

$pages = '/','/yasi', '/contact', '/yasi/industry.htm', '/yasi/media.htm', 
            '/scholarship/', '/teacher', '/course', '/about', '/ieltsallaspects/speaking.htm',
            '/ieltsallaspects/listening.htm', '/ieltsallaspects/reading.htm','/ieltsallaspects/writing.htm',
            '/teacher/20130515041127.htm', '/course/aquan7.htm', '/faq-2/', '/faq/'

function WarmSite($siteToWarm){
    $time = Measure-Command {
        $res = Invoke-WebRequest $siteToWarm
    }
    $ms = $time.TotalMilliSeconds
    If ($ms -ge 400) {
        Write-Host "$($res.StatusCode) from   $($siteToWarm) in $($ms)ms" -foreground "yellow"
    }
    return $res.StatusCode
}

function Get-ServerFarm {
    param ([string]$webFarmName)

    $assembly = [System.Reflection.Assembly]::LoadFrom("$env:systemroot\system32\inetsrv\Microsoft.Web.Administration.dll")
    $mgr = new-object Microsoft.Web.Administration.ServerManager "$env:systemroot\system32\inetsrv\config\applicationhost.config"
    $conf = $mgr.GetApplicationHostConfiguration()
    $section = $conf.GetSection("webFarms")
    $webFarms = $section.GetCollection()
    $webFarm = $webFarms | Where {
        $_.GetAttributeValue("name") -eq $serverFarmName
    }

    return $webFarm
}

function GetSite($name){
    $site = @{}
    $site | Add-Member -MemberType NoteProperty -Name SiteName -Value $name
    $status = Get-WebsiteState -Name $site.SiteName
    $site | Add-Member -MemberType NoteProperty -Name Status -Value $status.Value
    return $site
}

function GetServer{
    Param ($inputserver)
    $webFarm = Get-ServerFarm
    $servers = $webFarm.GetCollection()

    $server = $servers | Where {
        $_.GetAttributeValue("address") -eq $inputserver
    }
    return $server
}

function GetServerCurrentRequestsCount{
    Param ($inputserver)

    $server = GetServer $inputserver
    $arr = $server.GetChildElement("applicationRequestRouting")
    $counters = $arr.GetChildElement("counters")
    return $counters.GetAttributeValue("currentRequests")
}

function IsServerHealthy{
    Param ($inputserver)

    $server = GetServer $inputserver
    $arr = $server.GetChildElement("applicationRequestRouting")
    $counters = $arr.GetChildElement("counters")
    return $counters.GetAttributeValue("isHealthy")
}

function GetServerTotalRequestsCount{
    Param ($inputserver)

    $server = GetServer $inputserver
    $arr = $server.GetChildElement("applicationRequestRouting")
    $counters = $arr.GetChildElement("counters")
    return $counters.GetAttributeValue("totalRequests")
}

function SetServerState{
    Param ($inputserver, $state)

    $server = GetServer $inputserver
    $arr = $server.GetChildElement("applicationRequestRouting")
    $method = $arr.Methods["SetState"]
    $methodInstance = $method.CreateInstance()

    # 0 = Available
    # 1 = Drain
    # 2 = Unavailable
    # 3 = Unavailable Gracefully
    $methodInstance.Input.Attributes[0].Value = $state
    $methodInstance.Execute()
}

Import-Module WebAdministration


$blue_info = GetSite($siteBlueName)
$green_info = GetSite($siteGreenName)



if ($pathBlueContent -contains 'up' )
{
    if($blue_info.Status -eq "Started" -And $green_info.Status -eq "Stopped" -And $pathGreenContent -contains 'down'){
        Write-Host "The server is already in balanced state"
        exit
    }
    $siteToWarm = $siteGreen
    $pathToBringUp = $pathGreen
    $siteToBringUp = $siteGreenName
    $pathToBringDown = $pathBlue
    $siteToBringDown = $siteBlueName
    $ServerToBringDown = $blueServerAddress
    $ServerToBringUp = $greenServerAddress

}
elseif($blue_info.Status -eq "Stopped" -And $green_info.Status -eq "Started" -And $pathGreenContent -contains 'up'){
    Write-Host "The server is already in balanced state"
    exit
}


Write-Host "Copying media files from $pathToBringDown\media to $pathToBringUp\media "
$Source = "$pathToBringDown\media"
$Destination = "$pathToBringUp\media"
Get-ChildItem $Source -Recurse | ForEach {
    $ModifiedDestination = $($_.FullName).Replace("$Source","$Destination")
    If ((Test-Path $ModifiedDestination) -eq $False) {
        Copy-Item $_.FullName $ModifiedDestination
        }
    }
    

if($notransfer -eq $false){
    # Copy App_Data
    Write-Host "Copying App_Data from $pathToBringDown\App_Data $pathToBringUp\App_Data"
    $exclude_folders = "TEMP", "Logs"
    $exclude_files = "umbraco.config"
    Get-ChildItem "$pathToBringDown\App_Data" -Directory | 
        Where-Object{$_.Name -notin $exclude_folders} | 
        Copy-Item -Destination "$pathToBringUp\App_Data" -Recurse -Force
}



Write-Host "Restart $siteToBringUp"
Stop-WebSite $siteToBringUp
Start-WebSite $siteToBringUp

$sitestatus = Get-WebsiteState -Name $siteToBringUp
if ($sitestatus.Value -eq "Started"){
    Write-Host "Warming up $($siteToWarm)"
    Do {
        $status = WarmSite($siteToWarm)
    } While ($ms -ge 500)
    # Write-Host "$($res.StatusCode) from $($siteToWarm) in $($ms)ms" -foreground "cyan"
    foreach ($page in $pages){
        $item = "$siteToWarm$page"
        $status = WarmSite($item)
        if($status -ne 200){
            Write-Host "$status from $($siteToWarm) " -foreground "cyan"
            Write-Host "Exiting" -foreground "cyan"
            exit
        }
    }
}else{
    Write-Host "$siteToBringUp $($siteToWarm) is stopped" -foreground "red"
    exit 1
}

Write-Host "Bringing $($pathToBringUp) up" -foreground "cyan"
(Get-Content $pathToBringUp\up.html).replace('down', 'up') | Set-Content $pathToBringUp\up.html

# This could fail
Try{
    Write-Host "Setting $ServerToBringUp state to available"
    SetServerState $ServerToBringUp 0
}
Catch [Exception]
{
    Write-Host "Failed to bring $($pathToBringUp) up, reverting changes" -foreground "cyan"
    (Get-Content $pathToBringUp\up.html).replace('up', 'down') | Set-Content $pathToBringUp\up.html
    Write-Output $_.Exception|format-list -force
    exit 1
}




Write-Host "Watting for $ServerToBringUp to become healthy"
$ishealthy = $false
do{
    $ishealthy = IsServerHealthy $ServerToBringUp
}while($ishealthy -eq $false)

Write-Host "Setting $ServerToBringDown state to drain"
SetServerState $ServerToBringDown 1

$currRequest = 0
do{
    $currRequest = GetServerCurrentRequestsCount $ServerToBringDown
    Write-Host "$ServerToBringDown has $currRequest left"
}while($currRequest -gt 0)

Write-Host "Setting $ServerToBringDown state to Unavailble"
SetServerState $ServerToBringDown 2

Write-Host "Bringing $($siteToBringDown) $($pathToBringDown) down"
(Get-Content $pathToBringDown\up.html).replace('up', 'down') | Set-Content $pathToBringDown\up.html
Stop-Website -Name $siteToBringDown
Stop-WebAppPool -Name $siteToBringDown
