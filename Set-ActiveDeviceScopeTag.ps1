# Check if the module is already installed
$modules = Get-InstalledModule -Name Microsoft.Graph* -ErrorAction SilentlyContinue

foreach ($module in $modules) {
    # If not installed or installed version is outdated, install or update
    if (-not $module -or $module.Version -lt [Version]"2.26.1") {
        Install-Module -Name $($module.Name) -Force -Verbose
    }
    else {
        Write-Host "$($module.Name) version $($module.Version) is already installed. Skipping installation."
    }
}

# Check if the module is already installed
$modules = Get-InstalledModule -Name Microsoft.Graph.beta* -ErrorAction SilentlyContinue

foreach ($module in $modules) {
    # If not installed or installed version is outdated, install or update
    if (-not $module -or $module.Version -lt [Version]"2.26.1") {
        Install-Module -Name $($module.Name)  -Force -Verbose
    }
    else {
        Write-Host "$($module.Name) version $($module.Version) is already installed. Skipping installation."
    }
}

function Update-DeviceScopeTags {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$updatedTags,

        [Parameter(Mandatory = $true)]
        [string]$deviceId
    )

    # Step 1: Ensure it's a clean array and remove nulls
    $updatedTags = @($updatedTags) | Where-Object { $_ -ne $null }

    # Step 2: Build the request body
    $bodyHash = @{
        roleScopeTagIds = @($updatedTags)
    }

    # Step 3: Convert to JSON with compression
    $bodyJson = $bodyHash | ConvertTo-Json -Compress

    # Optional: Print the body for inspection
    Write-Host "PATCH Body:" $bodyJson

    # Step 4: Send the PATCH request to Graph
    Invoke-MgGraphRequest -Method PATCH `
        -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId" `
        -Body $bodyJson `
        -ContentType "application/json"
}


# Connect to Graph
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All","DeviceManagementRBAC.Read.All"  



# Get the Scope Tag ID by name 
$ActiveDeviceTagName = "Active Device"
$tag = Get-MgBetaDeviceManagementRoleScopeTag | Where-Object { $_.DisplayName -eq $ActiveDeviceTagName }
$scopeTagId = $tag.Id


# Get all managed devices. However, it will not include Rolescope tags in the response.
$devices = Get-MgBetaDeviceManagementManagedDevice  -All


# Remove "Active Device" scope tag from inactive devices
$daysInactive = 14
$cutoffDate = (Get-Date).AddDays(-$daysInactive)

$inactiveDevices = $devices | Where-Object {
    $_.LastSyncDateTime -lt $cutoffDate 
}


# Remove the scope tag from the list
foreach ($device in $inactiveDevices) {
    $devicewithTag = Get-MgBetaDeviceManagementManagedDevice -ManagedDeviceId $($device.id) -Property "id,DeviceName,roleScopeTagIds"
    if ($devicewithTag.RoleScopeTagIds -contains $scopeTagId) {
        $currentTags = $devicewithTag.roleScopeTagIds
        $updatedTags = $currentTags | Where-Object { $_ -ne $scopeTagId }
        $deviceId = $devicewithTag.Id

        Update-DeviceScopeTags -updatedTags $updatedTags -deviceId $deviceId
<#
        $updatedTags = @($updatedTags) | Where-Object { $_ -ne $null }
        # Step 2: Build hashtable
        $bodyHash = @{
            roleScopeTagIds = @($updatedTags)
        }

        # Step 3: Convert to JSON - IMPORTANT: Use -Compress to keep it clean
        $bodyJson = $bodyHash | ConvertTo-Json  -Compress

        # (Optional) Inspect JSON before sending
        Write-Host "PATCH Body:" $bodyJson


        # Step 4: Send PATCH to Graph
        Invoke-MgGraphRequest -Method PATCH `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId" `
            -Body $bodyJson `
            -ContentType "application/json" 
#>

        Write-Host "Removed 'Active Device' scope tag from device: $($devicewithTag.DeviceName)"
    } else {
        Write-Host "Device $($devicewithTag.DeviceName) does not have the 'Active Device' scope tag."
        continue
    }

}


# Assign "Active Device" scope tag for active devices
$daysInactive = 14
$cutoffDate = (Get-Date).AddDays(-$daysInactive)

$activeDevices = $devices | Where-Object {
    $_.LastSyncDateTime -ge $cutoffDate 
}

foreach ($device in $activeDevices){
    $devicewithTag = Get-MgBetaDeviceManagementManagedDevice -ManagedDeviceId $($device.id) -Property "id,DeviceName,roleScopeTagIds"
    if ($devicewithTag.RoleScopeTagIds -notcontains $scopeTagId) {
        $currentTags = $devicewithTag.roleScopeTagIds
        $updatedTags = $currentTags + $scopeTagId
        $deviceId = $devicewithTag.Id

        Update-DeviceScopeTags -updatedTags $updatedTags -deviceId $deviceId
<# 
        $updatedTags = @($updatedTags) | Where-Object { $_ -ne $null }
        # Step 2: Build hashtable
        $bodyHash = @{
            roleScopeTagIds = @($updatedTags)
        }

        # Step 3: Convert to JSON - IMPORTANT: Use -Compress to keep it clean
        $bodyJson = $bodyHash | ConvertTo-Json  -Compress

        # (Optional) Inspect JSON before sending
        Write-Host "PATCH Body:" $bodyJson


        # Step 4: Send PATCH to Graph
        Invoke-MgGraphRequest -Method PATCH `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId" `
            -Body $bodyJson `
            -ContentType "application/json" 
  #>

        Write-Host "Add 'Active Device' scope tag to device: $($devicewithTag.DeviceName)"
    } else {
        Write-Host "Device $($devicewithTag.DeviceName) already has the 'Active Device' scope tag."
        continue
    }
}
