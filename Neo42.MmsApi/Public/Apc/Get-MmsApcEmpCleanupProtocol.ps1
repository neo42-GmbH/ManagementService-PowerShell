function Get-MmsApcEmpCleanupProtocol {
	<#
	.SYNOPSIS
		Returns the protocol entries of an Empirum cleanup job.
	.DESCRIPTION
		GET /api/apc/EmpirumCleanup/Protocols?jobId=&cultureCode=&fromDateTicks=

		The server expects the start date as UTC ticks, which this function
		derives from -FromDate.
	.PARAMETER JobId
		Job whose protocol should be read.
	.PARAMETER CultureCode
		Language of the entries, 'en' or 'de'.
	.PARAMETER FromDate
		Oldest entry to return. Defaults to 180 days ago.
	.EXAMPLE
		Get-MmsApcEmpCleanupProtocol -JobId $jobId -CultureCode 'de'
	.EXAMPLE
		Get-MmsApcEmpCleanupProtocol -JobId $jobId -FromDate (Get-Date).AddDays(-7)
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true)]
		[guid]
		$JobId,

		[Parameter()]
		[ValidateSet('en', 'de')]
		[string]
		$CultureCode = 'en',

		[Parameter()]
		[datetime]
		$FromDate = (Get-Date).AddDays(-180),

		[Parameter()]
		[object]
		$Session
	)

	$query = @{
		jobId         = $JobId
		cultureCode   = $CultureCode
		fromDateTicks = $FromDate.ToUniversalTime().Ticks
	}

	return Invoke-MmsApiRequest -Path '/api/apc/EmpirumCleanup/Protocols' -Query $query -Session $Session -Unwrap
}
