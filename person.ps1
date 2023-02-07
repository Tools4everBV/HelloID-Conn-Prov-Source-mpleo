$configuration = @{
    username = ''
    password = ''
    baseurl = 'https://demoapi.mpleo.net/ws/'
    daysBeforeStartContract = ''
    daysAfterEndContract = ''
} | ConvertTo-Json



function SplitLastName () {
    Param ($lastname)
    $insertion = $null
    $insertions = @("aan", "af", "bij", "van", "de", "den", "der", "het", "'s", "'t", "in", "onder", "op", "over", "te", "ten", "ter", "tot", "uit", "uijt", "ver", "voor", "la", "les", "da", "el", "aus", "von", "dem", "unter", "vor", "zu", "zum", "zur")
    $splitname = [PSObject]::new()
    $GivenCheck = $false
    $Name = $lastname -split " "
    if ($Name.count -lt 2) { $surname = $lastname }
    else {
        for ($i = 0; $i -lt $Name.count; $i ++) {
            if ($insertions -contains $name[$i] -and $GivenCheck -eq $false) { $insertion += $name[$i] + " " }
            else { $surname += $name[$i] + " "; $GivenCheck = $true }
        }
    }
    if (!([string]::IsNullOrEmpty($insertion))) { $insertion = $insertion.Trim().ToLower() }
    $surname = $surname.Trim()
    $splitname | Add-Member -MemberType NoteProperty -Name Insertion -value $Insertion
    $splitname | Add-Member -MemberType NoteProperty -Name surname -value $surname
    return $splitname
}

#reading configuration Settings
$connectionSettings = ConvertFrom-Json $configuration
$username = $connectionSettings.Username
$upassword = $connectionSettings.password
$baseurl = $connectionSettings.BaseUrl
$daysBeforeStartContract = $connectionSettings.daysBeforeStartContract
$daysAfterEndContract = $connectionSettings.daysAfterEndContract

#Url's per attribute
$employee_url = $baseurl + "employee"
$contract_url = $baseurl + "employee/contract"
$taxdata_url = $baseurl + "employee/taxdata"
$employer_url = $baseurl + "employee/Employer"
$analyticalsplit_url = $baseurl + "employee/analyticalsplit"
$Job_url = $baseurl + "employee/Job"
$agreement_url = $baseurl + "agreement"
$chartstructure_url = $baseurl + "chartstructure"
$function_url = $baseurl + "function"
$site_url = $baseurl + "site"
$role_url = $baseurl + "role"
$titles_url = $baseurl + "jobs/title"

#create standard Header
$auth = $username + ':' + $upassword
$Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
$authorizationInfo = [System.Convert]::ToBase64String($Encoded)
$headers = @{
    "Authorization" = "Basic $($authorizationInfo)"
    "accept"        = "text/plain"
}

$employee = Invoke-RestMethod -Uri $employee_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($employee.count) Employees"
$Emp_contract = Invoke-RestMethod -Uri $contract_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($Emp_contract.count) Employments"
$Emp_taxdata = Invoke-RestMethod -Uri $taxdata_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($Emp_taxdata.count) Partner informations"
$Emp_Employer = Invoke-RestMethod -Uri $employer_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($Emp_Employer.count) Employer"
$Emp_analyticalsplit = Invoke-RestMethod -Uri $analyticalsplit_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($Emp_analyticalsplit.count) OE"
$Emp_Job = Invoke-RestMethod -Uri $Job_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($Emp_Job.count) Jobs"
$agreement = Invoke-RestMethod -Uri $agreement_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($agreement.count) agreements"
$chartstructure = Invoke-RestMethod -Uri $chartstructure_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($chartstructure.count) Departments"
$function = Invoke-RestMethod -Uri $function_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($function.count) JobTitles"
$site = Invoke-RestMethod -Uri $site_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($site.count) Locations"
$role = Invoke-RestMethod -Uri $role_url -Method Get -Headers $headers -UseBasicParsing
Write-information "Found $($role.count) Roles"
$titles = Invoke-RestMethod -Uri $titles_url -Headers $headers
Write-information "Found $($titles.count) salutation titles"

#Convert Job field to complete Employments (Contracts)
$Employments = [System.Collections.ArrayList]$Emp_Job
$Employments | Add-Member -MemberType NoteProperty -Name FunctionStartDate -Value $null
$Employments | Add-Member -MemberType NoteProperty -Name FunctionEndDate -Value $null
$Employments | Add-Member -MemberType NoteProperty -Name ContractStartDate -Value $null
$Employments | Add-Member -MemberType NoteProperty -Name ContractEndDate -Value $null
$Employments | Add-Member -MemberType NoteProperty -Name Company -Value $null
$Employments | Add-Member -MemberType NoteProperty -Name Departmentname -Value $null
$Employments | Add-Member -MemberType NoteProperty -Name parentDepartment -Value $null
$Employments | Add-Member -MemberType NoteProperty -Name FunctionCode -Value $null
$Employments | Add-Member -MemberType NoteProperty -Name functionGroupTitle -Value $null
$Employments | Add-Member -MemberType NoteProperty -Name SequenceNumber -Value $null
$Employments | Add-Member -MemberType NoteProperty -Name ExternalId -Value $null

#contractnumber is created to make a unique employmentID
$ContractNumber = 1
for ($i = 0; $i -lt $Employments.count; $i ++) {
    if ($lastEmployeeCode -eq $Employments[$i].employeeCode) { $ContractNumber ++ }
    else { $ContractNumber = 1 }
    if (!([string]::IsNullOrEmpty($Employments[$i].StartDate))) { $Employments[$i].FunctionStartDate = [datetime]$Employments[$i].StartDate }
    if (!([string]::IsNullOrEmpty($Employments[$i].EndDate))) { $Employments[$i].FunctionEndDate = [datetime]$Employments[$i].EndDate }
    $Employments[$i].ContractStartDate = [datetime]($Emp_contract | Where-Object { $_.employeeCode -eq $Employments[$i].employeeCode } | select -last $true).BeginContractDate
    if (!([string]::IsNullOrEmpty(($Emp_contract | Where-Object { $_.employeeCode -eq $Employments[$i].employeeCode } | select -last $true).EndContractDate))) {
        $Employments[$i].ContractEndDate = [datetime](($Emp_contract | Where-Object { $_.employeeCode -eq $Employments[$i].employeeCode } | select -last $true).EndContractDate)
    }
    $Employments[$i].ExternalId = "$($Employments[$i].employeeCode)-$contractNumber"
    $Employments[$i].SequenceNumber = $contractNumber

    #company Info
    $Company = $Emp_Employer | Where-Object { ("0" + $_.orgCode) -eq [string]$Employments[$i].employerCode }
    $Employments[$i].Company = $Company.orgName
    # $Employments[$i].StreetAddress = $Company.Address.street + " " + $Company.Address.number
    # $Employments[$i].PostalCode = $Company.Address.postalCode
    # $Employments[$i].City = $Company.Address.cityName
    # $Employments[$i].Countrycode = $Company.Address.CountryCode
    #Organization
    $OU = $chartstructure | Where-Object { $_.unitcode -eq [string]$Employments[$i].departmentCode }
    $Employments[$i].Departmentname = $OU.unitName
    $Employments[$i].DepartmentCode = $Employments[$i].departmentCode
    $Employments[$i].parentDepartment = $OU.parentUnitName
    #function
    $function = $functions | Where-Object { $_.title -eq [string]$Employments[$i].function }
    $Employments[$i].FunctionCode = $function.code
    $Employments[$i].functionGroupTitle = $function.functionGroupTitle


    $lastEmployeeCode = $Employments[$i].employeeCode

}

#filter only required Contracts -1 Month and +2 month
$employments = $Employments | Where-Object { $_.FunctionStartDate -lt (Get-date).AddDays($daysBeforeStartContract) }
$employments = $Employments | Where-Object { $_.FunctionEndDate -eq $null -or $_.FunctionEndDate -gt (Get-date).AddDays($daysAfterEndContract) }

#$Employments
#break

#<#>#>
$persons = [System.Collections.ArrayList]$employee
$persons | Add-Member -MemberType NoteProperty -Name Contracts -Value $null
$persons | Add-Member -MemberType NoteProperty -Name orgName -Value $null
$persons | Add-Member -MemberType NoteProperty -Name DisplayName -Value $null
$persons | Add-Member -MemberType NoteProperty -Name ExternalId -Value $null
$persons | Add-Member -MemberType NoteProperty -Name Initials -Value $null
$persons | Add-Member -MemberType NoteProperty -Name surname -Value $null
$persons | Add-Member -MemberType NoteProperty -Name Insertion -Value $null
$persons | Add-Member -MemberType NoteProperty -Name PartnerName -Value $null
$persons | Add-Member -MemberType NoteProperty -Name NamingConvention -Value "B"
$persons | Add-Member -MemberType NoteProperty -Name StreetAddress -Value $null
$persons | Add-Member -MemberType NoteProperty -Name Zipcode -Value $null
$persons | Add-Member -MemberType NoteProperty -Name City -Value $null
$persons | Add-Member -MemberType NoteProperty -Name Countrycode -Value $null


for ($i = 0; $i -lt $persons.count; $i ++) {

    $persons[$i].contracts = @($Employments | Where-Object { $_.EmployeeCode -eq $persons[$i].EmployeeCode })
    $persons[$i].PartnerName = ($Emp_taxdata | Where-Object { $_.EmployeeCode -eq $persons[$i].EmployeeCode }).partnerLastName
    $persons[$i].orgName = ($Emp_Employer | Where-Object { $_.EmployeeCode -eq $persons[$i].EmployeeCode }).orgName
    $persons[$i].orgName = ($Emp_Employer | Where-Object { $_.EmployeeCode -eq $persons[$i].EmployeeCode }).orgName
    $persons[$i].ExternalId = "BE-" + $persons[$i].EmployeeCode
    $persons[$i].Displayname = $persons[$i].firstName + " " + $persons[$i].lastname + " (" + $persons[$i].EmployeeCode + ")"
    if (!([string]::IsNullOrEmpty($persons[$i].birthDate))) { $persons[$i].birthDate = [datetime]$persons[$i].birthDate }
    if (!([string]::IsNullOrEmpty($persons[$i].creationDate))) { $persons[$i].creationDate = [datetime]$persons[$i].creationDate }
    if (!([string]::IsNullOrEmpty($persons[$i].lastUpdateDate))) { $persons[$i].lastUpdateDate = [datetime]$persons[$i].lastUpdateDate }
    $persons[$i].Insertion = (SplitLastname -lastname $persons[$i].lastname).Insertion
    $persons[$i].surname = (SplitLastname -lastname $persons[$i].lastname).surname
    $AddressInfo = ($Emp_Employer | Where-Object { ("0" + $_.orgCode) -eq (($Emp_contract | Where-Object { $_.employeeCode -eq $persons[$i].EmployeeCode }).employerCode) }).address
    $persons[$i].StreetAddress = $AddressInfo.street + " " + $AddressInfo.number
    $persons[$i].ZipCode = $AddressInfo.postalCode
    $persons[$i].City = $AddressInfo.cityName
    $persons[$i].Countrycode = $AddressInfo.CountryCode

}


#$persons | Where-Object {$_.contracts -ne $null}

#$persons | ConvertTo-Json -Depth 10


foreach ($obj in $persons) {
    write-output $obj | Convertto-json -Depth 3 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) }
}

Write-Verbose "Employee import completed" -Verbose
