# Azure RBAC Role Action Exporter

This repository contains a simple Azure PowerShell tool that helps users understand what an Azure RBAC role can and cannot do. Azure role definitions often include wildcard based actions which makes it hard to see the full list of allowed or blocked operations. This script expands those wildcards and exports the fully evaluated actions into two CSV files.

The script is designed for beginners. It prompts for the role name, prompts for the export folder, and logs into Azure interactively. It will install the required Az module automatically if it is missing.

## What the Script Does

- Logs the user into Azure through Connect-AzAccount  
- Prompts the user for the Azure RBAC role to evaluate  
- Prompts for a folder path where CSV files will be saved  
- Installs the Az module if it is not already installed  
- Retrieves all Azure provider operations  
- Expands NotActions into real Azure operations  
- Calculates Allowed actions by subtracting the expanded NotActions  
- Exports two CSV files:
  - `AllowedActions.csv`
  - `NotAllowedActions.csv`

This gives a clear picture of what the role truly allows and what it blocks.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7.x  
- Internet access  
- An Azure account with rights to read role definitions and provider operations

The script will install the Az module automatically as part of the run.

## How to Use

1. Open PowerShell
2. Run the script:
   ```powershell
   .\Export-AzureRoleActions.ps1
