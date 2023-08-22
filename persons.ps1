########################################################################
# HelloID-Conn-Prov-Source-mpleo-Persons
#
# Version: 1.0.0
########################################################################
# Initialize default value's
$config = $Configuration | ConvertFrom-Json

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Split-LastName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $LastName
    )

    $insertion = $null
    $insertions = @("aan", "af", "bij", "van", "de", "den", "der", "het", "'s", "'t", "in", "onder", "op", "over", "te", "ten", "ter", "tot", "uit", "uijt", "ver", "voor", "la", "les", "da", "el", "aus", "von", "dem", "unter", "vor", "zu", "zum", "zur")

    $splitName = [PSObject]::new()
    $givenCheck = $false
    $Name = $LastName -split ' '
    if ($Name.count -lt 2) {
        $surname = $LastName
    } else {
        for ($i = 0; $i -lt $Name.count; $i ++) {
            if ($insertions -contains $name[$i] -and $givenCheck -eq $false) {
                $insertion += $name[$i] + ' '
            } else {
                $surname += $name[$i] + ' '; $givenCheck = $true
            }
        }
    }
    if (!([string]::IsNullOrEmpty($insertion))) {
        $insertion = $insertion.Trim().ToLower()
    }

    $surname = $surname.Trim()
    $splitName | Add-Member -MemberType NoteProperty -Name Insertion -Value $insertion
    $splitName | Add-Member -MemberType NoteProperty -Name Surname -Value $surname
    Write-Output $splitName
}

function Resolve-mpleoError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = ''
            FriendlyMessage  = ''
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -eq $ErrorObject.Exception.Response) {
                $httpErrorObj.ErrorDetails = $ErrorObject.Exception.Message
                $httpErrorObj.FriendlyMessage = $ErrorObject.Exception.Message
            }
            $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
            $httpErrorObj.ErrorDetails = $streamReaderResponse
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    Write-Verbose 'Creating authentication header'
    $auth = $($config.UserName) + ':' + $($config.Password)
    $encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
    $authorizationInfo = [System.Convert]::ToBase64String($Encoded)
    $headers = @{
        'Authorization' = "Basic $($authorizationInfo)"
    }

    $splatRestMethodParams = @{
        Method = 'GET'
        Headers = $headers
        UseBasicParsing = $true
    }

    Write-Verbose 'Getting employment data from mpleo'
    $responseEmployee = Invoke-RestMethod -Uri "$($config.BaseUrl)/employee" @splatRestMethodParams
    $responseContracts = Invoke-RestMethod -Uri "$($config.BaseUrl)/employee/contract" @splatRestMethodParams
    $responseTaxdata = Invoke-RestMethod -Uri "$($config.BaseUrl)/employee/taxdata" @splatRestMethodParams
    $responseEmployer = Invoke-RestMethod -Uri "$($config.BaseUrl)/employee/employer" @splatRestMethodParams
    $responseJobs = Invoke-RestMethod -Uri "$($config.BaseUrl)/employee/Job" @splatRestMethodParams
    $responseChartStructures = Invoke-RestMethod -Uri "$($config.BaseUrl)/chartstructure" @splatRestMethodParams
    $responseFunctions = Invoke-RestMethod -Uri "$($config.BaseUrl)/function" @splatRestMethodParams


    Write-Verbose 'Converting job field to complete employment'
    $employments = [System.Collections.ArrayList]$responseJobs
    $employments | Add-Member -MemberType NoteProperty -Name FunctionStartDate -Value $null
    $employments | Add-Member -MemberType NoteProperty -Name FunctionEndDate -Value $null
    $employments | Add-Member -MemberType NoteProperty -Name ContractStartDate -Value $null
    $employments | Add-Member -MemberType NoteProperty -Name ContractEndDate -Value $null
    $employments | Add-Member -MemberType NoteProperty -Name Company -Value $null
    $employments | Add-Member -MemberType NoteProperty -Name DepartmentName -Value $null
    $employments | Add-Member -MemberType NoteProperty -Name ParentDepartment -Value $null
    $employments | Add-Member -MemberType NoteProperty -Name FunctionCode -Value $null
    $employments | Add-Member -MemberType NoteProperty -Name FunctionGroupTitle -Value $null
    $employments | Add-Member -MemberType NoteProperty -Name SequenceNumber -Value $null
    $employments | Add-Member -MemberType NoteProperty -Name ExternalId -Value $null

    $contractNumber = 1
    for ($i = 0; $i -lt $employments.count; $i ++) {
        if ($lastEmployeeCode -eq $employments[$i].employeeCode) {
            $contractNumber ++
        } else {
            $contractNumber = 1
        }

        if (!([string]::IsNullOrEmpty($employments[$i].StartDate))) {
            $employments[$i].FunctionStartDate = [DateTime]$employments[$i].StartDate
        }

        if (!([string]::IsNullOrEmpty($employments[$i].EndDate))) {
            $employments[$i].FunctionEndDate = [DateTime]$employments[$i].EndDate
        }

        $employments[$i].ContractStartDate = [DateTime]($responseContracts | Where-Object { $_.employeeCode -eq $employments[$i].employeeCode } | select -last $true).BeginContractDate

        if (!([string]::IsNullOrEmpty(($responseContracts | Where-Object { $_.employeeCode -eq $employments[$i].employeeCode } | select -last $true).EndContractDate))) {
            $employments[$i].ContractEndDate = [DateTime](($responseContracts | Where-Object { $_.employeeCode -eq $employments[$i].employeeCode } | select -last $true).EndContractDate)
        }

        $employments[$i].ExternalId = "$($employments[$i].employeeCode)-$contractNumber"
        $employments[$i].SequenceNumber = $contractNumber

        # Company Info
        $company = $responseEmployer | Where-Object { ("0" + $_.orgCode) -eq [string]$employments[$i].employerCode }
        $employments[$i].Company = $company.orgName

        # Organization
        $ou = $responseChartstructures | Where-Object { $_.unitcode -eq [string]$employments[$i].departmentCode }
        $employments[$i].DepartmentName = $ou.unitName
        $employments[$i].DepartmentCode = $employments[$i].departmentCode
        $employments[$i].ParentDepartment = $ou.parentUnitName

        # Function
        $function = $responseFunctions | Where-Object { $_.title -eq [string]$employments[$i].function }
        $employments[$i].FunctionCode = $function.code
        $employments[$i].functionGroupTitle = $function.functionGroupTitle

        $lastEmployeeCode = $employments[$i].employeeCode
    }

    # filter only required Contracts -1 Month and +2 month
    $employments = $employments | Where-Object { $_.FunctionStartDate -lt (Get-Date).AddDays($daysBeforeStartContract) }
    $employments = $employments | Where-Object { $_.FunctionEndDate -eq $null -or $_.FunctionEndDate -gt (Get-Date).AddDays($daysAfterEndContract) }

    $persons = [System.Collections.ArrayList]$responseEmployee
    $persons | Add-Member -MemberType NoteProperty -Name Contracts -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name OrgName -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name DisplayName -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name ExternalId -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name Initials -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name Surname -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name Insertion -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name PartnerName -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name NamingConvention -Value "B"
    $persons | Add-Member -MemberType NoteProperty -Name StreetAddress -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name ZipCode -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name City -Value $null
    $persons | Add-Member -MemberType NoteProperty -Name CountryCode -Value $null

    for ($i = 0; $i -lt $persons.count; $i ++) {
        $persons[$i].contracts = @($employments | Where-Object { $_.EmployeeCode -eq $persons[$i].EmployeeCode })
        $persons[$i].PartnerName = ($responseTaxdata | Where-Object { $_.EmployeeCode -eq $persons[$i].EmployeeCode }).partnerLastName
        $persons[$i].orgName = ($responseEmployer | Where-Object { $_.EmployeeCode -eq $persons[$i].EmployeeCode }).orgName
        $persons[$i].orgName = ($responseEmployer | Where-Object { $_.EmployeeCode -eq $persons[$i].EmployeeCode }).orgName
        $persons[$i].ExternalId = "BE-" + $persons[$i].EmployeeCode
        $persons[$i].Displayname = $persons[$i].firstName + " " + $persons[$i].lastname + " (" + $persons[$i].EmployeeCode + ")"

        if (!([string]::IsNullOrEmpty($persons[$i].birthDate))) {
            $persons[$i].birthDate = [DateTime]$persons[$i].birthDate
        }
        if (!([string]::IsNullOrEmpty($persons[$i].creationDate))) {
            $persons[$i].creationDate = [DateTime]$persons[$i].creationDate
        }
        if (!([string]::IsNullOrEmpty($persons[$i].lastUpdateDate))) {
            $persons[$i].lastUpdateDate = [DateTime]$persons[$i].lastUpdateDate
        }

        $persons[$i].Insertion = (Split-LastName -lastname $persons[$i].lastname).Insertion
        $persons[$i].surname = (Split-LastName -lastname $persons[$i].lastname).surname
        $AddressInfo = ($responseEmployer | Where-Object { ("0" + $_.orgCode) -eq (($Emp_contract | Where-Object { $_.employeeCode -eq $persons[$i].EmployeeCode }).employerCode) }).address
        $persons[$i].StreetAddress = $AddressInfo.street + " " + $AddressInfo.number
        $persons[$i].ZipCode = $AddressInfo.postalCode
        $persons[$i].City = $AddressInfo.cityName
        $persons[$i].Countrycode = $AddressInfo.CountryCode
    }

    Write-Verbose 'Importing raw data in HelloID'
    foreach ($person in $persons) {
        $person | ConvertTo-Json -Depth 3 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
    }
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-mpleoError -ErrorObject $ex
        Write-Verbose "Could not import mpleo persons. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import mpleo persons. Error: $($errorObj.FriendlyMessage)"
    } else {
        Write-Verbose "Could not import mpleo persons. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import mpleo persons. Error: $($errorObj.FriendlyMessage)"
    }
}
