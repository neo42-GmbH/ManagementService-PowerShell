function Get-MmsSchemaName {
	<#
	.SYNOPSIS
		Turns a swagger schema node into a short readable type name.
	.DESCRIPTION
		Swagger references contain the full .NET type name
		(UseFullTypeNameInSchemaIds), which is far too long for a catalog line.
		Every namespace qualified name is reduced to its last segment, including
		the type arguments of generics:

			Neo42.MMS.Shared.Model.ResultModel[Neo42.Bitlocker.Shared.BitlockerReportV2,...]
			-> ResultModel[BitlockerReportV2,ErrorMessageEntry,String]

		A return type of ResultModel[...] means the endpoint answers with the
		{ Success, Item, Error } envelope, so -Unwrap is useful there.
		Arrays are marked with '[]'.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter()]
		[psobject]
		$Schema
	)

	if ($null -eq $Schema) {
		return $null
	}

	$reference = $Schema.'$ref'
	if (-not [string]::IsNullOrWhiteSpace($reference)) {
		$fullName = ($reference -split '/')[-1]
		$shortName = [regex]::Replace(
			$fullName,
			'[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+',
			{ param($match) $match.Value.Split('.')[-1] })
		return $shortName
	}

	if ($Schema.type -eq 'array') {
		$itemName = Get-MmsSchemaName -Schema $Schema.items
		if ([string]::IsNullOrWhiteSpace($itemName)) {
			return 'object[]'
		}
		return "$itemName[]"
	}

	if (-not [string]::IsNullOrWhiteSpace($Schema.type)) {
		return $Schema.type
	}

	return $null
}
