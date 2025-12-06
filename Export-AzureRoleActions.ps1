<#
.SYNOPSIS
    Generates full expanded Allowed and NotAllowed Azure RBAC actions for a given built in or custom Azure role.

.DESCRIPTION
    Azure RBAC roles that use wildcard based Actions or NotActions can be difficult to understand. 
    This script resolves all permitted and denied operations by expanding all Azure provider operations 
    and applying the role definition filters. It exports the results into CSV files for reporting or audit purposes.

.PARAMETER RoleName
    The Azure RBAC role name to analyze. For example "Contributor" or "Reader" or a custom role.

.PARAMETER OutputPath
    Path where CSV files should be saved. The script will create the folder if it does not exist.

.EXAMPLE
    .\Export-AzureRoleActions.ps1 -RoleName Contributor -OutputPath "C:\Reports\RBAC"

.EXAMPLE
    .\Export-AzureRoleActions.ps1 -RoleName "Custom Billing Role" -OutputPath ".\Exports"

.NOTES
    Author: Shannon Eldridge Kuehn (your name as requested)
    Version: 1.0
    Azure PowerShell modules required:
        Az.Accounts
        Az.Resources

    You must be logged into Azure with Connect-AzAccount prior to running this script.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RoleName,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][$Level] $Message"
}

try {
    Write-Log "Validating Azure connection..."

    if (-not (Get-AzContext)) {
        throw "No Azure context found. Please run Connect-AzAccount before executing this script."
    }

    Write-Log "Fetching role definition for '$RoleName'..."
    $role = Get-AzRoleDefinition -Name $RoleName

    Write-Log "Fetching all Azure provider operations. This may take some time..."
    $allOps = Get-AzProviderOperation | Select-Object -ExpandProperty Operation

    Write-Log "Expanding NotActions for role '$RoleName'..."

    $expandedNotAllowed = foreach ($na in $role.NotActions) {
        $pattern = "^" + ($na -replace '\*', '.*') + "$"
        $allOps | Where-Object { $_ -match $pattern }
    }

    Write-Log "Calculating Allowed and NotAllowed operations..."
    $allowedActions = $allOps | Where-Object { $expandedNotAllowed -notcontains $_ }

    Write-Log "Preparing output folder at '$OutputPath'..."
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory | Out-Null
    }

    $allowedCsv = $allowedActions | ForEach-Object {
        [PSCustomObject]@{
            RoleName   = $RoleName
            Operation  = $_
            Allowed    = $true
        }
    }

    $notAllowedCsv = $expandedNotAllowed | ForEach-Object {
        [PSCustomObject]@{
            RoleName   = $RoleName
            Operation  = $_
            Allowed    = $false
        }
    }

    $allowedPath = Join-Path $OutputPath "AllowedActions.csv"
    $notAllowedPath = Join-Path $OutputPath "NotAllowedActions.csv"

    Write-Log "Exporting Allowed actions to '$allowedPath'..."
    $allowedCsv | Export-Csv -Path $allowedPath -NoTypeInformation -Encoding UTF8

    Write-Log "Exporting NotAllowed actions to '$notAllowedPath'..."
    $notAllowedCsv | Export-Csv -Path $notAllowedPath -NoTypeInformation -Encoding UTF8

    Write-Log "Export complete. Role analysis finished successfully." "SUCCESS"
}
catch {
    Write-Log $_.Exception.Message "ERROR"
    exit 1
}
