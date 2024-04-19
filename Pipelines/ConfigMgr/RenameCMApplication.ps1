param(
    $AppName,
    $ModelName,
    $SiteServer,
    $SiteCode
)

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

# Uncomment for Logging next to the Scriptfile
#Add-Content -Path "$PSScriptRoot\log.txt" -Value "$(Get-Date -Format '[dd.MM.yyyy HH:mm:ss]'): Rename App with ModelID $($ModelName) to $($AppName)"
Set-CMApplication -ModelName $ModelName -NewName $AppName
