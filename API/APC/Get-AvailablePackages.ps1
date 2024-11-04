#requires -version 5
<#
.SYNOPSIS
	List all known packages.
.DESCRIPTION
	Exports all packages known to the server.
	The data is based on the data of the Application Package Center plug-in.
.PARAMETER ServerName
	The servername of the neo42 Management Service.
.PARAMETER OutputPath
	The path where the csv files should be stored.
	Defaults to the script root.
.OUTPUTS
	none
.NOTES
	Version:        1.0
	Author:         neo42 GmbH
	Creation Date:  04.11.2024
	Purpose/Change: Initial release
.EXAMPLE
	.\Get-AvailablePackages.ps1 -ServerName "https://server.domain:4242"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $false)]	
	[String]
	$OutputPath = "$PSScriptRoot"
)

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath -ChildPath "AvailablePackages.csv"

$dpURL = "$ServerName/api/apc/DefaultPackage/all/0"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$response = Invoke-RestMethod -Method Get -Uri $dpURL -Headers $headers -UseDefaultCredentials -ErrorAction Stop

$packageType = @{
    0 = "Depot"
    1 = "Individual"
    2 = "Other"
}

$response | Select-Object -Property `
    @{
        name='Source'
        expr={$packageType[$_.Type.Kind]}
    },
    @{
        name='ReleaseDate'
        expr={$_.Metadata.DeveloperInformation.ReleaseDate}
    },
    @{
        name='Vendor'
        expr={$_.Metadata.DeveloperInformation.Package.AppVendor}
    },
    @{
        name='Name'
        expr={$_.Metadata.DeveloperInformation.Package.AppName}
    },
    @{
        name='Version'
        expr={$_.Metadata.DeveloperInformation.Package.AppVersion}
    },
    @{
        name='Revision'
        expr={$_.Metadata.DeveloperInformation.Package.Revision}
    },
    @{
        name='SourcesIncluded'
        expr={$_.Metadata.DeveloperInformation.Package.SourcesIntegrated}
    },
    @{
        name='HasUserPart'
        expr={
            $_.Metadata.DeveloperInformation.Package.UserPartOnInstallation -or
            $_.Metadata.DeveloperInformation.Package.UserPartOnUninstallation
        }
    },
    @{
        name='InstallMethod'
        expr={$_.Metadata.DeveloperInformation.Package.InstallMethod}
    },
    @{
        name='UninstallMethod'
        expr={$_.Metadata.DeveloperInformation.Package.UninstallMethod}
    },
    @{
        name='FileSize'
        expr={$_.Metadata.FileInformation.Size}
    } | Export-Csv -Path $filePath -NoTypeInformation