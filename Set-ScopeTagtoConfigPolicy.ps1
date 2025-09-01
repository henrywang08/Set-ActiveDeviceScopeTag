# Check if the module is already installed
# $modules = Get-InstalledModule -Name Microsoft.Graph* -ErrorAction SilentlyContinue
  $moduleNames = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.DeviceManagement",
    "Microsoft.Graph.Beta.DeviceManagement",
    "Microsoft.Graph.Beta.Authentication",
    "Microsoft.Graph.Beta.DeviceManagement.Administration"
  )

  $modules = @()

  foreach ($moduleName in $moduleNames) {
      $module = Get-InstalledModule -Name $moduleName -ErrorAction SilentlyContinue
      $modules += $module
  }

  

foreach ($module in $modules) {
    # If not installed or installed version is outdated, install or update
    if (-not $module -or $module.Version -lt [Version]"2.30.0") {
        Install-Module -Name $($module.Name) -Force -Verbose
    }
    else {
        Write-Host "$($module.Name) version $($module.Version) is already installed. Skipping installation."
        Remove-Module $($module.Name)  -Force -ErrorAction SilentlyContinue
    }
}

  foreach ($moduleName in $moduleNames) {
    "Loading $moduleName..."  
    Import-Module -Name $moduleName -ErrorAction SilentlyContinue
  }


function Update-ScopeTagsforDeviceConfigPolicy {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$updatedTags,

        [Parameter(Mandatory = $true)]
        [string]$policyId
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
        -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$policyId" `
        -Body $bodyJson `
        -ContentType "application/json"
}


# Connect to Graph
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All","DeviceManagementRBAC.Read.All"



# Get the Scope Tag ID by name 
$ActiveDeviceTagName = "Country - AU"
$tag = Get-MgBetaDeviceManagementRoleScopeTag | Where-Object { $_.DisplayName -eq $ActiveDeviceTagName }
$scopeTagId = $tag.Id


# Get Intune Device Configuration based on naming conversion, such as find all policies end with "*AU Admin"
$policyNamePattern = '*AU Admin'

# Prefer MS Graph PowerShell cmdlets when available
try {
    # Use Beta cmdlet to enumerate all configuration policies
    $allPolicies = Get-MgBetaDeviceManagementConfigurationPolicy -All -ErrorAction Stop
} catch {
    Write-Error "Failed to retrieve configuration policies using Get-MgBetaDeviceManagementConfigurationPolicy: $_"
    $allPolicies = @()
}

# Filter by display name (case-insensitive -like)
$matchingPolicies = $allPolicies | Where-Object {
    $display = $_.Name
    if (-not $display) { $display = $_.Name }
    $display -like $policyNamePattern
}

Write-Host "Found $($matchingPolicies.Count) matching configuration policy(ies):"
foreach ($p in $matchingPolicies) {
    $pName = $p.Name 
    Write-Host "- $pName ($($p.id))"
}

# Set the matching configuration policy with specific scope tags
foreach ($policy in $matchingPolicies) {
     $policyId = $p.id
   # $policyId = $policy.I
    $updatedTags = @($scopeTagId)
    Write-Host "The current Scope Tags for policy '$($p.Name)' ($policyId): $($p.roleScopeTagIds -join ', ')"
    Update-ScopeTagsforDeviceConfigPolicy -updatedTags $updatedTags -policyId $policyId

}

