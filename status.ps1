$bluePath = "C:\wwwroot\mkr_umbraco_blue"
$greenPath = "C:\wwwroot\mkr_umbraco_green"

Import-Module WebAdministration
function GetSite($name){
    $site = @{}
    $site | Add-Member -MemberType NoteProperty -Name SiteName -Value $name
    $status = Get-WebsiteState -Name $site.SiteName
    $site | Add-Member -MemberType NoteProperty -Name Status -Value $status.Value
    $app_pool_status = Get-WebAppPoolState $site.SiteName
    $site | Add-Member -MemberType NoteProperty -Name AppPoolStatus -Value $app_pool_status.Value
    return $site
}

$downsite = $null
$blue_site = GetSite mkr_umbraco_blue
$green_site = GetSite mkr_umbraco_green


Write-Output "IIS STATUS"
Write-Host "$($blue_site.SiteName) Status:  $($blue_site.Status) | App Pool: $($blue_site.AppPoolStatus)"
Write-Host "$($green_site.SiteName) Status:  $($green_site.Status) | App Pool: $($green_site.AppPoolStatus)"

Write-Output "UP STATUS"
$upPath = @($bluePath, $greenPath) | Where-Object {
    (Get-Content "$($_)\up.html") -contains "up"
}

if ($upPath -eq $bluePath) {
    $downPath = $greenPath
    $downsite = $green_site
} else {
    $downPath = $bluePath
    $downsite = $blue_site
}

Write-Host "$($upPath) is up"
Write-Host "$($downPath) is down"
Write-Host "##vso[task.setvariable variable=DOWN_SITE]$($downsite.SiteName)"
