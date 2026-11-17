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
	Purpose/Change: Use the Neo42.MmsApi module instead of raw Invoke-RestMethod
.EXAMPLE
	.\Get-AvailablePackages.ps1 -ServerName "https://server.domain:4242"
#>
[CmdletBinding()]
Param (
	[parameter(Mandatory = $true)]
	[String]
	$ServerName,
	[parameter(Mandatory = $true)]	
	[System.IO.DirectoryInfo]
	$OutputPath
)

# Use an installed Neo42.MmsApi module if there is one, otherwise the copy that
# ships with this repository.
$mmsModule = 'Neo42.MmsApi'
if (-not (Get-Module -ListAvailable -Name $mmsModule)) {
	$mmsModule = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Neo42.MmsApi\Neo42.MmsApi.psd1'
}
Import-Module -Name $mmsModule -ErrorAction Stop

Connect-MmsApi -ServerName $ServerName

# Filename with the collected data
$filePath = Join-Path -Path $OutputPath.FullName -ChildPath "AvailablePackages.csv"

$response = Get-MmsApcDefaultPackage

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