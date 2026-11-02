<#
	.SYNOPSIS
		Add content to a custom function.
	.DESCRIPTION
		Adds content to a custom function in a Deploy-Application.ps1 file of a PSADT v3 or v4 based neo42 package.
		The position of the content can be specified to be at the beginning or end of the custom function.
		If the custom function is not found or any of the specified content is not valid PowerShell code, an error is thrown.
		The content can be specified as a string or as a file containing the content.
		Code written for PSADT v3 does not run in a PSADT v4 package and vice versa, so a content file is resolved per package framework:
		- 3.0: the ContentFile itself, e.g. 'C:\PSLibrary\Google Chrome\Content.ps1'
		- 4.0: the file with the same name in a '4.0' subfolder next to the ContentFile, e.g. 'C:\PSLibrary\Google Chrome\4.0\Content.ps1'
		There is no fallback from one package framework to the other. Content specified as a string is inserted as is for every package framework.
		The content is only checked for syntax errors. It is not checked whether the commands it uses exist in the toolkit of the package.
	.PARAMETER DeployApplicationFile
		The Deploy-Application.ps1 file.
	.PARAMETER Content
		The content to add to the custom function. Must be valid PowerShell script.
	.PARAMETER ContentFile
		The file containing the content to add to the custom function for PSADT v3 packages. Must be valid PowerShell script.
		For PSADT v4 packages the file with the same name in the '4.0' subfolder next to it is used, see the description.
	.PARAMETER FunctionName
		The name of the custom function to add content to.
	.PARAMETER PackageFramework
		The package framework of the package as provided by the pipeline variable <Run.PackageFramework>. Supported values are 3.0 and 4.0.
		For 0.1, a package without toolkit such as a neo42 tool, nothing is done and the task succeeds.
	.PARAMETER InsertAtEnd
		Insert the content at the end of the custom function. Default is to insert at the beginning.
	.EXAMPLE
		Add-ContentToCustomFunction -DeployApplicationFile "$PWD\Deploy-Application.ps1" -Content 'Write-Host "Hello, World!"' -FunctionName 'CustomInstallAndReinstallAndSoftMigrationEnd' -PackageFramework '4.0' -InsertAtEnd
	.EXAMPLE
		Add-ContentToCustomFunction -DeployApplicationFile 'Deploy-Application.ps1' -ContentFile 'C:\PSLibrary\Google Chrome\Content.ps1' -FunctionName 'CustomBegin' -PackageFramework '3.0'
	.EXAMPLE
		APC specific example
		-DeployApplicationFile "<Phase.PackagePath>\<Run.Version>\Deploy-Application.ps1" -FunctionName "CustomInstallAndReinstallAndSoftMigrationEnd" -ContentFile "<GLOBAL.MYSCRIPTSTORAGE>\Google Chrome\CustomCode.ps1" -PackageFramework "<Run.PackageFramework>"
	.Outputs
		Protocol lines as strings
	.NOTES
		Creation Date:			12.04.2024
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true)]
	[System.IO.FileInfo]
	$DeployApplicationFile,
	[Parameter(Mandatory = $true, ParameterSetName = 'Content')]
	[string[]]
	$Content,
	[Parameter(Mandatory = $true, ParameterSetName = 'File')]
	[System.IO.FileInfo]
	$ContentFile,
	[Parameter(Mandatory = $true)]
	[ValidatePattern('^Custom')]
	[string]
	$FunctionName,
	[Parameter(Mandatory = $true)]
	[version]
	$PackageFramework,
	[Parameter(Mandatory = $false)]
	[switch]
	$InsertAtEnd
)
## -ErrorAction Stop or SilentlyContinue in the task arguments would otherwise turn the Write-Error below into a reported success
$ErrorActionPreference = 'Continue'
## The pipeline task only fails on records in the error stream, a terminating error alone is reported as success
try {
	## A tool carries no Deploy-Application.ps1, so the file is only validated for packages built on the toolkit
	if ($PackageFramework -eq [version]'0.1') {
		Write-Output "PackageFramework $PackageFramework is a package without toolkit, nothing to do."
		return
	}
	if ($PackageFramework -notin @([version]'3.0', [version]'4.0')) {
		throw "PackageFramework Version $PackageFramework is not supported."
	}
	if (($DeployApplicationFile.Name -ne 'Deploy-Application.ps1') -or ($false -eq $DeployApplicationFile.Exists)) {
		throw "The file '$($DeployApplicationFile.FullName)' is not an existing Deploy-Application.ps1."
	}
	## If the content is specified as a file, read the content from the file of the package framework and use the content parameter
	if ($PSCmdlet.ParameterSetName -eq 'File') {
		switch ($PackageFramework) {
			([version]'3.0') {
				[System.IO.FileInfo]$frameworkContentFile = $ContentFile.FullName
				break
			}
			([version]'4.0') {
				## Plain string path math, DirectoryInfo would drop trailing spaces and dots from the folder name and point to a different folder
				[System.IO.FileInfo]$frameworkContentFile = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($ContentFile.FullName), $PackageFramework.ToString(), $ContentFile.Name)
				break
			}
		}
		if ($false -eq $frameworkContentFile.Exists) {
			throw "The content file '$($frameworkContentFile.FullName)' for PackageFramework $PackageFramework does not exist."
		}
		## Editors save UTF-8 without a BOM by default, which Get-Content would read as ANSI. A byte order mark still wins, and ANSI stays the fallback for files that are not valid UTF-8.
		[System.Text.Encoding]$contentEncoding = [System.Text.Encoding]::Default
		try {
			[System.Text.UTF8Encoding]::new($false, $true).GetString([System.IO.File]::ReadAllBytes($frameworkContentFile.FullName)) | Out-Null
			$contentEncoding = [System.Text.UTF8Encoding]::new($false)
		}
		catch [System.Text.DecoderFallbackException] {
		}
		[System.IO.StreamReader]$contentReader = [System.IO.StreamReader]::new($frameworkContentFile.FullName, $contentEncoding, $true)
		try {
			$Content = @(while ($null -ne ($line = $contentReader.ReadLine())) { $line })
		}
		finally {
			$contentReader.Dispose()
		}
	}
	## A byte order mark in the middle of the content, e.g. from concatenated files, would end up inside a command name
	$Content = @(foreach ($contentLine in @($Content)) { $contentLine.Replace([string][char]0xFEFF, '') })
	## Import the Deploy-Application.ps1 file and validate it
	[System.Management.Automation.Language.ParseError[]]$errors = @()
	[System.Management.Automation.Language.Token[]]$tokens = @()
	[System.Management.Automation.Language.Ast]$ast = [System.Management.Automation.Language.Parser]::ParseFile($DeployApplicationFile.FullName, [ref]$tokens, [ref]$errors)
	if ($errors.Count -gt 0) {
		throw "The file '$DeployApplicationFile' contains syntax errors: `n$($errors -join "`n")"
	}
	## Check if the content is valid PowerShell code
	[System.Management.Automation.Language.Token[]]$contentTokens = @()
	[System.Management.Automation.Language.ScriptBlockAst]$contentAst = [System.Management.Automation.Language.Parser]::ParseInput(($Content -join "`r`n"), [ref]$contentTokens, [ref]$errors)
	if ($errors.Count -gt 0) {
		throw "The specified content has syntax errors. Please verify the input: `n$($errors -join "`n")"
	}
	## A #Requires statement applies to the whole script, wherever it stands, and could keep the package from starting at all
	if ($null -ne $contentAst.ScriptRequirements) {
		throw "The specified content contains a #Requires statement, which would apply to the whole '$DeployApplicationFile'. Please remove it."
	}
	## Find the custom function in the Deploy-Application.ps1 file
	[System.Management.Automation.Language.FunctionDefinitionAst]$customFunction = $ast.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq $FunctionName }, $false)
	if ($null -eq $customFunction) {
		throw "Custom function '$FunctionName' not found in '$DeployApplicationFile'"
	}
	## Insert the content at the specified position
	[string]$outputText = $ast.Extent.Text
	## Lines that continue a multi-line string are not indented, a tab would change the string value and breaks the terminator of a here-string.
	## Bareword arguments are string tokens as well. The tokens are ordered and do not overlap, so one sweep over them is enough.
	[System.Management.Automation.Language.Token[]]$multiLineStrings = @($contentTokens | Where-Object { $_ -is [System.Management.Automation.Language.StringToken] -and $_.Extent.StartLineNumber -lt $_.Extent.EndLineNumber })
	[int]$tokenIndex = 0
	[int]$lineOffset = 0
	[string[]]$contentLines = if (@($Content).Count -gt 0) { @($Content) } else { @('') }
	[string[]]$indentedContent = foreach ($contentLine in $contentLines) {
		[int]$currentOffset = $lineOffset
		$lineOffset += $contentLine.Length + 2
		while (($tokenIndex -lt $multiLineStrings.Count) -and ($multiLineStrings[$tokenIndex].Extent.EndOffset -le $currentOffset)) {
			$tokenIndex++
		}
		if (($tokenIndex -lt $multiLineStrings.Count) -and ($multiLineStrings[$tokenIndex].Extent.StartOffset -lt $currentOffset)) {
			$contentLine
		}
		else {
			"`t$contentLine"
		}
	}
	[string]$insertContent = "`r`n" + ($indentedContent -join "`r`n") + "`r`n"
	## Only the region markers of the function itself count, so marker text in previously inserted content cannot redirect the insertion
	[System.Management.Automation.Language.Token[]]$functionComments = @($tokens | Where-Object { $_.Kind -eq 'Comment' -and $_.Extent.StartOffset -ge $customFunction.Extent.StartOffset -and $_.Extent.EndOffset -le $customFunction.Extent.EndOffset })
	[string]$escapedFunctionName = [regex]::Escape($customFunction.Name)
	if ($true -eq $InsertAtEnd) {
		[scriptblock[]]$detectionBlocks = @(
			{($functionComments | Where-Object { $_.Text -match "^#endregion $escapedFunctionName content\s*$" } | Select-Object -Last 1 -ExpandProperty Extent).StartOffset - 1},
			{$customFunction.Body.Extent.EndOffset - 1}
		)
	}
	else {
		## Determine the extend after which to insert the content, the installPhase assignment only exists in PSADT v3 packages
		[scriptblock[]]$detectionBlocks = @(
			{($functionComments | Where-Object { $_.Text -match "^#region $escapedFunctionName content\s*$" } | Select-Object -First 1 -ExpandProperty Extent).EndOffset},
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
	## Content that is valid on its own can still break the file at the insertion point, e.g. a 'using' statement
	[System.Management.Automation.Language.Parser]::ParseInput($outputText, [ref]$null, [ref]$errors) | Out-Null
	if ($errors.Count -gt 0) {
		throw "Inserting the content into the custom function '$FunctionName' would break '$DeployApplicationFile', it was not changed: `n$($errors -join "`n")"
	}
	Set-Content -LiteralPath $DeployApplicationFile.FullName -Value $outputText -Encoding UTF8 -NoNewline -ErrorAction Stop
}
catch {
	Write-Error $_.Exception.Message
	exit 1
}
