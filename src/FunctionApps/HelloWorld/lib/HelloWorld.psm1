using namespace System.Net

function Get-PublicIPAddress
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Functions.PowerShellWorker.HttpRequestContext]
        $Request,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $TriggerMetadata
    )

    $result = Invoke-WebRequest -Uri 'https://ifconfig.me'
    Write-Verbose -Message "$($result | Out-String)"

    Push-OutputBinding -Name Response -Value (
        [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $result.Content | ConvertTo-Json
        }
    )
}
