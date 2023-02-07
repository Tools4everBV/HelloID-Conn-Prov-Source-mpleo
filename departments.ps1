$connectionSettings = ConvertFrom-Json $configuration
$username = $connectionSettings.Username
$upassword = $connectionSettings.password
$baseurl = $connectionSettings.BaseUrl

$auth = $username + ':' + $upassword
$Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
$authorizationInfo = [System.Convert]::ToBase64String($Encoded)
$headers = @{
"Authorization"="Basic $($authorizationInfo)"
"accept" = "text/plain"
}

$departments_url = $baseurl + "chartstructure"
Write-Verbose "Starting department import" -Verbose
$chartstructure = Invoke-RestMethod -Uri $departments_url -Method Get -Headers $headers -UseBasicParsing
Write-Verbose "Found $($chartstructure.count) departments"
$chartstructure | Add-Member -MemberType NoteProperty -Name ExternalId -Value $nul
$chartstructure | Add-Member -MemberType NoteProperty -Name DisplayName -Value $nul

for ($i=0;$i -lt $chartstructure.count;$i ++){

$chartstructure[$i].ExternalID = $chartstructure[$i].unitCode
$chartstructure[$i].DisplayName = $chartstructure[$i].unitName

}
Write-Verbose "Department import completed" -Verbose
Write-Output $chartstructure | ConvertTo-Json -Depth 10
