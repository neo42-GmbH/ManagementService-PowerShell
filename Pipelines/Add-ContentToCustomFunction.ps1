<#
	.SYNOPSIS
		Add content to a custom function.
	.DESCRIPTION
		Adds content to a custom function in a Deploy-Application.ps1 file.
		The position of the content can be specified to be at the beginning or end of the custom function.
		If the custom function is not found or any of the specified content is not valid PowerShell code, an error is thrown.
		The content can be specified as a string or as a file containing the content.
	.PARAMETER DeployApplicationFile
		The Deploy-Application.ps1 file.
	.PARAMETER Content
		The content to add to the custom function. Must be valid PowerShell script.
	.PARAMETER ContentFile
		The file containing the content to add to the custom function. Must be valid PowerShell script.
	.PARAMETER FunctionName
		The name of the custom function to add content to.
	.PARAMETER InsertAtEnd
		Insert the content at the end of the custom function. Default is to insert at the beginning.
	.EXAMPLE
		Add-ContentToCustomFunction -DeployApplicationFile '$PWD\Deploy-Application.ps1' -Content 'Write-Host "Hello, World!"' -FunctionName 'CustomInstallAndReinstallAndSoftMigrationEnd' -InsertAtEnd
	.EXAMPLE
		Add-ContentToCustomFunction -DeployApplicationFile 'Deploy-Application.ps1' -ContentFile 'C:\PSLibrary\Content.ps1' -FunctionName 'CustomBegin'
	.Outputs
		None
	.NOTES
		Author:					julian.behr@neo42.de
		Creation Date:			12.04.2024
		Tested on:				MMS Server 4.1.16
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[ValidateScript({ $_.Exists -and $_.Name -eq 'Deploy-Application.ps1' })]
	[System.IO.FileInfo]
	$DeployApplicationFile,
	[Parameter(Mandatory = $true, ParameterSetName = 'Content')]
	[string[]]
	$Content,
	[Parameter(Mandatory = $true, ParameterSetName = 'File')]
	[ValidateScript({ $_.Exists })]
	[System.IO.FileInfo]
	$ContentFile,
	[Parameter(Mandatory = $true)]
	[ValidatePattern('Custom.*')]
	[string]
	$FunctionName,
	[Parameter(Mandatory = $false)]
	[switch]
	$InsertAtEnd
)
try {
	## If the content is specified as a file, read the content from the file and use the content parameter
	if ($PSCmdlet.ParameterSetName -eq 'File') {
		$Content = Get-Content -Path $ContentFile
	}
	## Import the Deploy-Application.ps1 file and validate it
	[System.Management.Automation.Language.ParseError[]]$errors = @()
	[System.Management.Automation.Language.Token[]]$tokens = @()
	[System.Management.Automation.Language.Ast]$ast = [System.Management.Automation.Language.Parser]::ParseFile($DeployApplicationFile.FullName, [ref]$tokens, [ref]$errors)
	if ($errors.Count -gt 0) {
		throw "The file '$DeployApplicationFile' contains syntax errors: `n$($errors -join "`n")"
	}
	## Check if the content is valid PowerShell code
	[System.Management.Automation.Language.Parser]::ParseInput(($Content -join "`r`n"), [ref]$null, [ref]$errors) | Out-Null
	if ($errors.Count -gt 0) {
		throw "The specified content has syntax errors. Please verify the input: `n$($errors -join "`n")"
	}
	## Find the custom function in the Deploy-Application.ps1 file
	[System.Management.Automation.Language.FunctionDefinitionAst]$customFunction = $ast.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq $FunctionName }, $false)
	if ($null -eq $customFunction) {
		throw "Custom function '$FunctionName' not found in '$DeployApplicationFile'"
	}
	## Insert the content at the specified position
	[string]$outputText = $ast.Extent.Text
	[string]$insertContent = "`r`n`t" + ($Content -join "`r`n`t") + "`r`n"
	if ($true -eq $InsertAtEnd) {
		[scriptblock[]]$detectionBlocks = @(
			{($tokens | Where-Object { $_.Kind -eq 'Comment' -and $_.Extent.Text -match "\s*\#endregion $($customFunction.Name) content\s*"} | Select-Object -First 1 -ExpandProperty Extent).StartOffset - 1},
			{$customFunction.Body.Extent.EndOffset - 1}
		)
	}
	else {
		## Determine the extend after which to insert the content
		[scriptblock[]]$detectionBlocks = @(
			{($tokens | Where-Object { $_.Kind -eq 'Comment' -and $_.Extent.Text -match "\s*\#region $($customFunction.Name) content\s*"} | Select-Object -First 1 -ExpandProperty Extent).EndOffset},
			{$customFunction.Find({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] -and $args[0].Left.Child.VariablePath.UserPath -eq 'script:installPhase' }, $true).Extent.EndOffset},
			{$customFunction.Body.ParamBlock.Extent.EndOffset},
			{$customFunction.Body.Extent.StartOffset + 1}
		)
	}

	foreach ($block in $detectionBlocks) {
		[int]$offset = . $block
		if ($offset -gt 0) {
			break
		}
	}
	if ($offset -eq 0) {
		throw "Could not determine the position to insert the content in the custom function '$FunctionName'"
	}

	$outputText = $outputText.Insert($offset, $insertContent)
	Set-Content -Path $DeployApplicationFile.FullName -Value $outputText -Encoding UTF8 -NoNewline
}
catch {
	Write-Error $_.Exception.Message
	exit 1
}
