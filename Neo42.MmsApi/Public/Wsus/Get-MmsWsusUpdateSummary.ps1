function Get-MmsWsusUpdateSummary {
	<#
	.SYNOPSIS
		Returns the WSUS update summary per computer.
	.DESCRIPTION
		Wraps the documented routes of the 'WSUS Plug-in - Updates' group:
			GET /api/WsusUpdateSummariesPerComputerV2        all computers
			GET /api/WsusUpdateSummariesPerComputerV2/{id}   one computer

		The summary counts installed, needed, failed and pending updates. The id of
		the single form is the FullDomainName of a computer target, not a guid -
		take it from Get-MmsWsusComputerTarget.
	.PARAMETER ComputerTarget
		FullDomainName of the computer target, as delivered by
		Get-MmsWsusComputerTarget.
	.EXAMPLE
		Get-MmsWsusUpdateSummary
	.EXAMPLE
		$target = Get-MmsWsusComputerTarget -NetBiosName 'CORP\PC0815'
		Get-MmsWsusUpdateSummary -ComputerTarget $target.FullDomainName
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ByTarget', Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
		[Alias('FullDomainName')]
		[ValidateNotNullOrEmpty()]
		[string]
		$ComputerTarget,

		[Parameter()]
		[object]
		$Session
	)

	process {
		$path = if ($PSCmdlet.ParameterSetName -eq 'ByTarget') {
			'/api/WsusUpdateSummariesPerComputerV2/{0}' -f [System.Uri]::EscapeDataString($ComputerTarget)
		}
		else {
			'/api/WsusUpdateSummariesPerComputerV2'
		}

		return Invoke-MmsApiRequest -Path $path -Session $Session
	}
}
