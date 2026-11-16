function Get-MmsBitLockerPolicy {
	<#
	.SYNOPSIS
		Returns the BitLocker policies configured in the MMS.
	.DESCRIPTION
		Wraps the documented routes of the 'BitLocker Plug-in - Policies' group:
			GET /api/BitlockerPolicy        all policies
			GET /api/BitlockerPolicy/{id}   one policy

		A BitLocker report references its policy through
		CurrentPolicyInfo.Id / TargetConfigurationInfo, so this is how the
		readable policy name behind a report id is resolved.
	.PARAMETER Id
		Id of the policy.
	.EXAMPLE
		Get-MmsBitLockerPolicy
	.EXAMPLE
		Get-MmsBitLockerPolicy -Id $report.CurrentPolicyInfo.Id
	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(ParameterSetName = 'ById', Mandatory = $true, Position = 0)]
		[guid]
		$Id,

		[Parameter()]
		[object]
		$Session
	)

	$path = if ($PSCmdlet.ParameterSetName -eq 'ById') {
		'/api/BitlockerPolicy/{0}' -f $Id
	}
	else {
		'/api/BitlockerPolicy'
	}

	return Invoke-MmsApiRequest -Path $path -Session $Session
}
