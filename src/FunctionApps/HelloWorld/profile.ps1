# Authenticate with Azure PowerShell using MSI.
if ($env:MSI_SECRET) {
    Disable-AzContextAutosave -Scope Process > $null
    Connect-AzAccount -Identity > $null
}

$DebugPreference = $env:DebugPreference
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = $env:VerbosePreference
