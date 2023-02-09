########################################################################
# HelloID-Conn-Prov-Source-mpleo-Departments
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


    Write-Verbose 'Getting department data from mpleo'
    $splatRestMethodParams = @{
        Uri = "$($config.BaseUrl)/chartstructure"
        Method = 'GET'
        Headers = $headers
        UseBasicParsing = $true

    }
    $responseChartStructure = Invoke-RestMethod @splatRestMethodParams

    foreach ($department in $responseChartStructure) {
        $department | Add-Member -MemberType NoteProperty -Name ExternalId -Value $($department.unitCode)
        $department | Add-Member -MemberType NoteProperty -Name DisplayName -Value $($department.unitCode)

        Write-Output $department | ConvertTo-Json -Depth 10
    }
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-mpleoError -ErrorObject $ex
        Write-Verbose "Could not import mpleo departments. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Throw "Could not import mpleo departments. Error: $($errorObj.FriendlyMessage)"
    } else {
        Write-Verbose "Could not import mpleo departments. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Throw "Could not import mpleo departments. Error: $($errorObj.FriendlyMessage)"
    }
}

