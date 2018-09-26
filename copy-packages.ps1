$bluePath = "D:\wwwroot\mkr_umbraco_blue"
$greenPath = "D:\wwwroot\mkr_umbraco_green"

Import-Module WebAdministration

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

Write-Output "Copying packages"
$Source = "$upPath\packages"
$Destination = "$downPath\packages"
Get-ChildItem $Source -Recurse | ForEach {
    $ModifiedDestination = $($_.FullName).Replace("$Source","$Destination")
    If ((Test-Path $ModifiedDestination) -eq $False) {
        Copy-Item $_.FullName $ModifiedDestination
        }
    }