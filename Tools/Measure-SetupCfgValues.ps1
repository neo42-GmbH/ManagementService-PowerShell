<#
	.SYNOPSIS
	Processes all setup.cfg files within a specified folder, extracts key-value pairs,
	and exports them to a CSV.

	.DESCRIPTION
	This script recursively searches for setup.cfg files within the provided folder path.
	It looks for specific markers to identify default values, retrieves current values,
	and compares them. If discrepancies are found between current and default values,
	the data is written to a CSV for further analysis.

	.PARAMETER FolderPath
	The path to the folder where the script should search recursively for setup.cfg files.

	.PARAMETER OutputCsv
	The path (including filename) where the resulting CSV data should be saved.

	.PARAMETER DiffOnly
	A switch parameter that, when present, will only include settings with non-default values in the output.

	.EXAMPLE
	Measure-SetupCfgValues.ps1 -FolderPath "C:\Empirum\Configurator\Packages" -OutputCsv "C:\temp\setupCfgReport.csv" -DiffOnly

	Exports a CSV file containing data from all setup.cfg files found in the specified folder that have non-default values.

	.NOTES
	Author:  Your Name
	Created: 2025-01-16
	Version: 1.0
	This script uses comment-based help to outline functionality and usage.
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[string]
	$FolderPath,
	[string]
	$OutputCsv,
	[switch]
	$DiffOnly
)


# Find all setup.cfg files recursively
[System.IO.FileInfo[]]$cfgFiles = Get-ChildItem -Path $FolderPath -Recurse -Filter "setup.cfg" -File

[PSCustomObject[]]$outputData = @()

foreach ($file in $cfgFiles) {
	try {
		[string[]]$lines = Get-Content -Path $file.FullName -ErrorAction Stop
	} catch {
		Write-Warning "Could not read file '$($file.FullName)'. Skipping."
		continue
	}

	$section = 'Options' # Assume default section
	foreach ($line in $lines) {
		# Match section
		if ($line -match '^\[(?<section>\w+)\]$') {
			$section = $Matches['section']
		}
		# Match default comment
		elseif ($line -match ';\s*Default\s*=(?<default>.*)$') {
			$defaultVal = $Matches['default'].Trim()
		}
		# Match assignment
		elseif ($line -match '^(?!;)(?<key>[^=]+)(?<!\\)=(?<value>.*)') {
			# If no default value was found, skip this setting
			if ($null -eq $defaultVal) { continue }

			# Only add requested data to output
			if ($false -eq $DiffOnly -or $Matches['value'].Trim() -ne $defaultVal) {
				$outputData += [PSCustomObject]::new(
					@{
						Filepath = $file.FullName
						Section = $section
						Key = $Matches['key'].Trim()
						Value = $Matches['value'].Trim()
						Default = $defaultVal
					}
				)
			}

			# Reset defaultVal for detection logic to re-apply
			$defaultVal = $null
		}
	}
}

# Export the data to CSV
if ($true -eq [string]::IsNullOrWhiteSpace($OutputCsv)) {
	$outputData | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
}
else {
	$outputData
}
