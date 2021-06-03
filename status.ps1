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

$blue_site = GetSite mkr_umbraco_blue
$green_site = GetSite mkr_umbraco_green


echo "IIS STATUS"
Write-Host "$($blue_site.SiteName) Status:  $($blue_site.Status) | App Pool: $($blue_site.AppPoolStatus)"
Write-Host "$($green_site.SiteName) Status:  $($green_site.Status) | App Pool: $($green_site.AppPoolStatus)"

echo "UP STATUS"
$upPath = @($bluePath, $greenPath) | Where {
    (Get-Content "$($_)\up.html") -contains "up"
}

$downPath = if ($upPath -eq $bluePath) {
    $greenPath
} else {
    $bluePath
}

Write-Host "$($upPath) is up"
Write-Host "$($downPath) is down"
