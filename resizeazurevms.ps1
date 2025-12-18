# --- Configuration ---
 
$csvPath = "C:\scripts\powershell\azure_resize_powershell\resizevms.csv"
 
$logFile = "C:\scripts\powershell\azure_resize_powershell\VmResizeLog.txt"
 
 
# --- Logger Function ---
 
function Write-Log {
 
    param([string]$message)
 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
 
    $entry = "$timestamp $message"
 
    Write-Host $entry
 
    Add-Content -Path $logFile -Value $entry
 
}
 
 
Write-Log "========== Starting Azure VM Resize Script =========="
 
 
# --- Prompt for Azure Service Principal Credentials ---
 
$TenantId  = Read-Host "Enter your Tenant ID"
$SubscriptionId = Read-Host "Enter your Subscription ID"
 
# --- Install and Import Necessary Modules ---
 
$requiredModules = @("Az.Accounts", "Az.Compute")
 
 
foreach ($module in $requiredModules) {
 
    try {
 
        if (-not (Get-Module -ListAvailable -Name $module)) {
 
            Write-Log "${module} not found. Installing..."
 
            Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue | Out-Null
 
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
 
            Write-Log "${module} installed successfully."
 
        } else {
 
            Write-Log "${module} already installed."
 
        }
 
        Import-Module $module -Force -ErrorAction Stop
 
        Write-Log "Imported ${module} successfully."
 
    } catch {
 
        Write-Log "ERROR installing or importing ${module}: $_"
 
        exit 1
 
    }
 
}
 
 
# --- Login to Azure using service principal ---
 
try {
 
    Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId -ErrorAction Stop
 
    Write-Log "Connected to Azure using service principal."
 
} catch {
 
    Write-Log "ERROR during login: $_"
 
    exit 1
 
}
 
# --- Load VM List from CSV ---
 
if (-not (Test-Path $csvPath)) {
 
    Write-Log "ERROR: CSV file not found at $csvPath"
 
    exit 1
 
}
 
 
try {
 
    $vmList = Import-Csv -Path $csvPath
 
    Write-Log "Loaded VM list from CSV successfully."
 
} catch {
 
    Write-Log "ERROR loading CSV: $_"
 
    exit 1
 
}
 
 
# --- Resize VMs ---
 
Write-Log "========== Processing VM Resize Operations =========="
 
 
foreach ($vmItem in $vmList) {
 
    $vmName = $vmItem.VMName
 
    $resourceGroup = $vmItem.ResourceGroup
 
    $newSize = $vmItem.TargetSize
 
 
    Write-Log "-----"
 
    Write-Log "Processing VM: '$vmName' in RG: '$resourceGroup' Resize to: '$newSize'"
 
 
    try {
 
        Write-Log "Stopping VM..."
 
        Stop-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force -ErrorAction Stop
 
 
        Write-Log "Retrieving VM properties..."
 
        $vm = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName -ErrorAction Stop
 
 
        $vm.HardwareProfile.VmSize = $newSize
 
 
        Write-Log "Updating VM configuration..."
 
        Update-AzVM -ResourceGroupName $resourceGroup -VM $vm -ErrorAction Stop
 
 
        Write-Log "Starting VM..."
 
        Start-AzVM -ResourceGroupName $resourceGroup -Name $vmName -ErrorAction Stop
 
 
        Write-Log "SUCCESS: '$vmName' resized to '$newSize'"
 
    } catch
 
     {
 
        Write-Log "ERROR resizing VM '$vmName': $_"
 
 
     }
 
}
 
 
Write-Log "========== VM Resize Process Completed =========="

