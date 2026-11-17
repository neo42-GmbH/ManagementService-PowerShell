function ConvertTo-MmsFilterTypeValue {
	<#
	.SYNOPSIS
		Maps an MMS filter (criteria) type name to the numeric API value.
	.DESCRIPTION
		The API expects an int in the path of /api/criteriastorev3/create/{type}
		and in the Type property of a stored filter:
			ActiveDirectoryGroup            = 0
			ActiveDirectoryOrganizationalUnit = 1
			Computername                    = 2
			ComputernameList                = 3
			OperatingSystem                 = 4
			Common                          = 5
			EmpirumGroup                    = 6

		The names are the ones the server itself uses in the template returned by
		/api/criteriastorev3/create/{type} ('New <name> Criteria').

		Common and EmpirumGroup are listed for completeness. The server reports
		them through /api/criteriastorev3/cancreate/{type}: Common exists once and
		cannot be created again, EmpirumGroup only when an Empirum connector is
		configured.

		Deliberately not implemented as an Add-Type enum: a type added that way
		cannot be unloaded and would occupy a very generic name for the whole
		AppDomain.
	#>
	[CmdletBinding()]
	[OutputType([int])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet(
			'ActiveDirectoryGroup',
			'ActiveDirectoryOrganizationalUnit',
			'Computername',
			'ComputernameList',
			'OperatingSystem',
			'Common',
			'EmpirumGroup')]
		[string]
		$Type
	)

	switch ($Type) {
		'ActiveDirectoryGroup' { return 0 }
		'ActiveDirectoryOrganizationalUnit' { return 1 }
		'Computername' { return 2 }
		'ComputernameList' { return 3 }
		'OperatingSystem' { return 4 }
		'Common' { return 5 }
		'EmpirumGroup' { return 6 }
	}
}
