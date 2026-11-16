function Get-MmsApcPipelineProtocol {
	<#
	.SYNOPSIS
		Returns the protocol entries of a pipeline run.
	.DESCRIPTION
		GET /api/apc/PipelineProtocol/GetMany/{runId}/{cultureCode}/{fromDateTicks}

		This is where the reason for a failed run shows up. The server expects the
		start date as UTC ticks, which this function derives from -FromDate.
	.PARAMETER RunId
		Run id (guid) whose protocol should be read.
	.PARAMETER CultureCode
		Language of the entries, 'en' or 'de'.
	.PARAMETER FromDate
		Oldest entry to return. Defaults to 7 days ago.
	.EXAMPLE
		Get-MmsApcPipelineProtocol -RunId $runId -CultureCode de
	.EXAMPLE
		Get-MmsApcPipelineProtocol -RunId $runId -FromDate (Get-Date).AddHours(-1) | Format-Table
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[guid]
		$RunId,

		[Parameter()]
		[ValidateSet('en', 'de')]
		[string]
		$CultureCode = 'en',

		[Parameter()]
		[datetime]
		$FromDate = (Get-Date).AddDays(-7),

		[Parameter()]
		[object]
		$Session
	)

	$path = '/api/apc/PipelineProtocol/GetMany/{0}/{1}/{2}' -f $RunId, $CultureCode, $FromDate.ToUniversalTime().Ticks

	return Invoke-MmsApiRequest -Path $path -Session $Session
}
