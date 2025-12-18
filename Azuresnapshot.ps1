# Basic Write-Log function definition with timestamp and log level
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

Write-Log "===== Script started ====="

# Required Az modules
$requiredModules = @("Az.Accounts", "Az.Compute")

foreach ($module in $requiredModules) {
    try {
        Write-Log "Checking if module '$module' is installed..."
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Log "$module not found. Installing..."
            Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue | Out-Null
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Log "$module installed successfully."
        }
        else {
            Write-Log "$module already installed."
        }

        Import-Module $module -Force -ErrorAction Stop
        Write-Log "Imported module: $module"
    }
    catch {
        Write-Log "ERROR installing or importing module '$module': $_" "ERROR"
        Write-Log "===== Script terminated due to error =====" "ERROR"
        exit 1
    }
}

# Prompt user for Subscription ID and Tenant ID
$subscriptionId = Read-Host "Please enter your Azure Subscription ID"
Write-Log "Subscription ID entered."

$tenantId = Read-Host "Please enter your Azure Tenant ID"
Write-Log "Tenant ID entered."

try {
    Write-Log "Connecting to Azure with Tenant ID: $tenantId"
    Connect-AzAccount -TenantId $tenantId -ErrorAction Stop
    Write-Log "Connected successfully."

    Write-Log "Setting Azure context to Subscription ID: $subscriptionId"
    Set-AzContext -SubscriptionId $subscriptionId -ErrorAction Stop
    Write-Log "Azure context set to subscription."
}
catch {
    Write-Log "ERROR during Azure login or context setting: $_" "ERROR"
    Write-Log "===== Script terminated due to error =====" "ERROR"
    exit 1
}

# Set CSV file path and change request
$csvPath = "C:\scripts\powershell\azure_snapshot_powershell\azuresnapshot.csv"
$changeRequestId = "CHG0270711"
Write-Log "Using CSV file path: $csvPath"
Write-Log "Using Change Request ID: $changeRequestId"

try {
    Write-Log "Importing VM list from CSV..."
    $vms = Import-Csv -Path $csvPath -ErrorAction Stop
    Write-Log "CSV file imported successfully. Found $($vms.Count) VM entries."
}
catch {
    Write-Log "ERROR importing CSV file '$csvPath': $_" "ERROR"
    Write-Log "===== Script terminated due to error =====" "ERROR"
    exit 1
}

foreach ($vmEntry in $vms) {
    $vmName = $vmEntry.VMName
    $resourceGroupName = $vmEntry.ResourceGroupName

    Write-Log "Processing VM '$vmName' in Resource Group '$resourceGroupName'..."

    try {
        Write-Log "Fetching VM details..."
        $vm = Get-AzVM -Name $vmName -ResourceGroupName $resourceGroupName -ErrorAction Stop

        $osDiskId = $vm.StorageProfile.OsDisk.ManagedDisk.Id
        $location = $vm.Location
        Write-Log "Retrieved VM OS disk ID and location."

        $timestamp = Get-Date -Format "ddMMyyyy-HHmm"
        $snapshotName = "$vmName-OSDiskSnapshot-$timestamp-$changeRequestId"
        Write-Log "Generated snapshot name: $snapshotName"

        Write-Log "Creating snapshot configuration..."
        $snapshotConfig = New-AzSnapshotConfig `
            -SourceUri $osDiskId `
            -Location $location `
            -CreateOption Copy `
            -SkuName Standard_LRS

        Write-Log "Creating snapshot..."
        New-AzSnapshot `
            -Snapshot $snapshotConfig `
            -SnapshotName $snapshotName `
            -ResourceGroupName $resourceGroupName `
            -ErrorAction Stop

        Write-Log "Snapshot created successfully: $snapshotName"
    }
    catch {
        Write-Log "Failed to create snapshot for VM '$vmName' in RG '$resourceGroupName': $_" "ERROR"
    }
}

Write-Log "===== Script completed ====="
