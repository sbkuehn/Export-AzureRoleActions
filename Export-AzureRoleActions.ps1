<#
.SYNOPSIS
    Logs into Azure, asks for a role name and an output folder,
    then exports Allowed and NotAllowed operations to CSV files.

.NOTES
    Author: Shannon Eldridge Kuehn
    2025-12-06
    Version: 3.2
#>

function Write-Log {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'HH:mm:ss')  $Message"
}

# -----------------------------------------------------------
# Module installer
# -----------------------------------------------------------
function Ensure-Module {
    param([string]$ModuleName)

    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Log "Installing required module '$ModuleName'..."
        try {
            Install-Module -Name $ModuleName -Scope CurrentUser -Force -ErrorAction Stop
        }
        catch {
            throw "Could not install module $ModuleName. Install it manually and try again."
        }
    }
    else {
        Write-Log "Module '$ModuleName' already installed."
    }
}

try {
    Write-Log "Checking required modules..."
    Ensure-Module -ModuleName Az

    Write-Log "Logging into Azure..."
    Connect-AzAccount -ErrorAction Stop | Out-Null
    Write-Log "Login successful."

    # Prompt for the Azure RBAC role name
    $RoleName = Read-Host "Enter the Azure role you want to evaluate (example: Contributor)"
    if (-not $RoleName) { throw "No role name entered. Script cannot continue." }

    # Prompt for export folder path
    $OutputFolder = Read-Host "Enter the folder path where CSV files should be saved"
    if (-not $OutputFolder) { throw "No folder path entered. Script cannot continue." }

    if (-not (Test-Path $OutputFolder)) {
        Write-Log "Folder does not exist. Creating it now..."
        New-Item -Path $OutputFolder -ItemType Directory | Out-Null
    }

    Write-Log "Retrieving role definition for '$RoleName'..."
    $role = Get-AzRoleDefinition -Name $RoleName
    if (-not $role) { throw "Role '$RoleName' not found. Check spelling and try again." }

    Write-Log "Retrieving provider operations. This may take a moment..."
    $allOps = Get-AzProviderOperation | Select-Object -ExpandProperty Operation

    # Progress bar setup
    $total = $role.NotActions.Count
    $count = 0
    $expandedNotAllowed = @()

    Write-Log "Expanding NotAllowed actions..."
    foreach ($na in $role.NotActions) {
        $count++
        Write-Progress -Activity "Expanding NotAllowed operations" -Status "$count of $total" -PercentComplete (($count / $total) * 100)

        $pattern = "^" + ($na -replace '\*', '.*') + "$"
        $expandedNotAllowed += $allOps | Where-Object { $_ -match $pattern }
    }

    Write-Log "Calculating Allowed operations..."
    $allowedActions = $allOps | Where-Object { $expandedNotAllowed -notcontains $_ }

    Write-Log "Building CSV data..."

    $allowedCsv = $allowedActions | ForEach-Object {
        [PSCustomObject]@{
            RoleName  = $RoleName
            Operation = $_
            Allowed   = $true
        }
    }

    $notAllowedCsv = $expandedNotAllowed | ForEach-Object {
        [PSCustomObject]@{
            RoleName  = $RoleName
            Operation = $_
            Allowed   = $false
        }
    }

    # Output file paths
    $allowedPath = Join-Path $OutputFolder "AllowedActions.csv"
    $notAllowedPath = Join-Path $OutputFolder "NotAllowedActions.csv"

    Write-Log "Exporting Allowed actions to '$allowedPath'..."
    $allowedCsv | Export-Csv -Path $allowedPath -NoTypeInformation -Encoding UTF8

    Write-Log "Exporting NotAllowed actions to '$notAllowedPath'..."
    $notAllowedCsv | Export-Csv -Path $notAllowedPath -NoTypeInformation -Encoding UTF8

    Write-Log "Export complete. Files saved to:"
    Write-Host $OutputFolder
    Write-Log "Process finished successfully."

}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}
