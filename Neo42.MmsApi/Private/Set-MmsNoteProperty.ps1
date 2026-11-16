function Set-MmsNoteProperty {
	<#
	.SYNOPSIS
		Sets a property on a PSCustomObject, adding it when it does not exist yet.
	.DESCRIPTION
		Assigning to a property a PSCustomObject does not have throws instead of
		creating it, so building a request body out of an object that came back
		from the server needs this guard: a field the server happened to omit
		would otherwise turn into a runtime error in the middle of a write path.
	.PARAMETER InputObject
		The object to change. Changed in place.
	.PARAMETER Name
		Property name.
	.PARAMETER Value
		Property value. $null is a valid value and clears the property.
	.OUTPUTS
		None. The object is changed in place.
	#>
	[CmdletBinding()]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true)]
		[psobject]
		$InputObject,

		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[Parameter()]
		[AllowNull()]
		[object]
		$Value
	)

	if ($null -ne $InputObject.PSObject.Properties[$Name]) {
		$InputObject.PSObject.Properties[$Name].Value = $Value
	}
	else {
		Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $Name -Value $Value
	}
}
