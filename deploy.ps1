$bluePath = "C:\wwwroot\mkr_umbraco_blue"
$greenPath = "C:\wwwroot\mkr_umbraco_green"

Import-Module WebAdministration
function GetSite($name){
    $site = @{}
    $site | Add-Member -MemberType NoteProperty -Name SiteName -Value $name
    $status = Get-WebsiteState -Name $site.SiteName
    $site | Add-Member -MemberType NoteProperty -Name Status -Value $status.Value
    return $site
}

$blue_site = GetSite mkr_umbraco_blue
$green_site = GetSite mkr_umbraco_green
$downsite = $blue_site


If ($green_site.Status -eq "Stopped"){
    $downsite = $green_site
}elseif($blue_site.Status -eq "Stopped"){
    $downsite = $blue_site    
}else{
    $upPath = @($bluePath, $greenPath) | Where {
        (Get-Content "$($_)\up.html") -contains "up"
    }
    
    $downPath = if ($upPath -eq $bluePath) {
        $greenPath
    } else {
        $bluePath
    }
    
    Write-Host "Both sites are started, fromz up.html"
    Write-Host "$($upPath) is up"
    Write-Host "$($downPath) is down"
    Exit
}

Write-Host "$($downsite.SiteName) is down"

Write-Host "bringing $($downsite.SiteName) site up"
Write-Host "\n$($downsite.SiteName) is the site to deploy\n" -foreground "yellow"

Start-WebAppPool -name $downsite.SiteName
Start-WebSite -Name $downsite.SiteName


