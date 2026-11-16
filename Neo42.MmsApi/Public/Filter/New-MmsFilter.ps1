function New-MmsFilter {
	<#
	.SYNOPSIS
		Creates a new MMS filter (criteria) in the criteria store.
	.DESCRIPTION
		Wraps the documented routes of the 'MMS Filter' group:
			GET  /api/criteriastorev3/cancreate/{type}   may this type be created
			GET  /api/criteriastorev3/create/{type}      empty server side template
			POST /api/criteriastorev3                    store the filled template

		The template is always fetched from the server rather than built here, so
		the filter carries the Id and the property set the server expects. -Name
		and -Data are written into it, then it is stored.

		-Data must match the Data block of the template for that type, for example:
			ActiveDirectoryOrganizationalUnit  DistinguishedName, Name, Recursive
			ActiveDirectoryGroup               DistinguishedName, Name
			ComputernameList                   ComputernameList
			Computername                       Filter, Name
			OperatingSystem                    ClientType, Filter, Version

		Use -PassThru to get the created filter back, for example to hand its Id
		to a plug-in configuration.

		This adds a dynamic computer group to the MMS. Run it with -WhatIf first.
	.PARAMETER Type
		Filter type to create, for example 'ActiveDirectoryOrganizationalUnit'.
	.PARAMETER Name
		Display name of the new filter.
	.PARAMETER Data
		Hashtable with the type specific Data properties. A key the template does
		not know is rejected here before anything is sent, and the error names the
		properties the template does have.
	.PARAMETER PassThru
		Returns the created filter object.
	.EXAMPLE
		New-MmsFilter -Type ActiveDirectoryOrganizationalUnit -Name 'Notebooks' -Data @{
			DistinguishedName = 'OU=Notebooks,DC=corp,DC=example,DC=com'
			Name              = 'Notebooks'
			Recursive         = $true
		} -WhatIf

		Shows what would be created without touching the server.
	.EXAMPLE
		New-MmsFilter -Type ComputernameList -Name 'Pilot' -Data @{ ComputernameList = @('PC0815', 'PC0816') } -PassThru
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateSet(
			'ActiveDirectoryGroup',
			'ActiveDirectoryOrganizationalUnit',
			'Computername',
			'ComputernameList',
			'OperatingSystem',
			'Common',
			'EmpirumGroup')]
		[string]
		$Type,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Name,

		[Parameter(Position = 2)]
		[hashtable]
		$Data,

		[Parameter()]
		[switch]
		$PassThru,

		[Parameter()]
		[object]
		$Session
	)

	$request = @{
		Session = $Session
	}

	$typeValue = ConvertTo-MmsFilterTypeValue -Type $Type

	$canCreate = Invoke-MmsApiRequest -Path ('/api/criteriastorev3/cancreate/{0}' -f $typeValue) @request
	if ($canCreate -ne $true) {
		throw "The server does not allow creating a filter of type '$Type'. A connector it depends on may be missing or not ready."
	}

	$template = Invoke-MmsApiRequest -Path ('/api/criteriastorev3/create/{0}' -f $typeValue) @request
	if ($null -eq $template) {
		throw "The server returned no template for filter type '$Type'."
	}

	$criteria = $template.Criteria | ConvertFrom-Json
	$criteria.Name = $Name

	foreach ($key in @($Data.Keys)) {
		# The template carries the full Data shape, so an unknown key is a typo
		# and would silently create a filter that never matches.
		if ($null -eq $criteria.Data -or -not ($criteria.Data.PSObject.Properties.Name -contains $key)) {
			throw "The template for '$Type' has no Data property '$key'. Known properties: $(($criteria.Data.PSObject.Properties.Name | Sort-Object) -join ', ')."
		}
		$criteria.Data.$key = $Data[$key]
	}

	$body = $template | Select-Object -Property * -ExcludeProperty CriteriaObject
	$body.Criteria = ConvertTo-Json -InputObject $criteria -Depth 20 -Compress

	if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target "filter '$Name' ($Type)" -Action 'Create the filter in the MMS criteria store')) {
		return
	}

	$null = Invoke-MmsApiRequest -Path '/api/criteriastorev3' -Method POST -Body $body @request -Confirm:$false

	if ($PassThru) {
		return Get-MmsFilter -Id $template.Id @request
	}
}
