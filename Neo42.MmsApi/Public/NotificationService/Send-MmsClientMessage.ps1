function Send-MmsClientMessage {
	<#
	.SYNOPSIS
		Sends a toast message to a single client through the Notification Service.
	.DESCRIPTION
		Wraps the documented route
			POST /api/StoreableNotification

		This is the Notification Service plug-in, not the Notification Center:
		the message is stored for one client and delivered by its client component
		the next time it connects. Use Send-MmsClientNotification when the target
		is a Notification Center target group with a schedule.

		The body shape below is what the server expects. The odd
		'<ActionType>k__BackingField' names are how the server serializes the
		action struct - they are required, not a typo.
	.PARAMETER ClientId
		MMS client id of the receiver, as delivered by Get-MmsClient.
	.PARAMETER Header
		First line of the message, shown as the title.
	.PARAMETER Line
		Further lines of the message body, in order.
	.PARAMETER ExpiresAt
		Point in time after which an undelivered message is dropped. Without it
		the message does not expire.
	.PARAMETER NotificationId
		Id of the notification. A fresh guid by default. Reuse one to replace a
		message that has not been delivered yet.
	.EXAMPLE
		$client = Get-MmsClient -Domain 'corp.example.com' -Name 'PC0815'
		Send-MmsClientMessage -ClientId $client.Id -Header 'Maintenance' -Line 'The server reboots at 20:00.' -WhatIf
	.EXAMPLE
		Send-MmsClientMessage -ClientId $client.Id -Header 'Update' -Line 'Please save your work.', 'This takes about 10 minutes.'
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
		[Alias('Id')]
		[guid]
		$ClientId,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Header,

		[Parameter(Position = 2)]
		[string[]]
		$Line,

		[Parameter()]
		[datetime]
		$ExpiresAt,

		[Parameter()]
		[guid]
		$NotificationId = [System.Guid]::NewGuid(),

		[Parameter()]
		[object]
		$Session
	)

	process {
		$lines = @($Header)
		foreach ($entry in $Line) {
			if (-not [string]::IsNullOrEmpty($entry)) {
				$lines += $entry
			}
		}

		$expiration = $null
		if ($PSBoundParameters.ContainsKey('ExpiresAt')) {
			$expiration = $ExpiresAt.ToString('yyyy-MM-ddTHH:mm:ss')
		}

		$now = Get-Date
		$body = @{
			Id                       = [System.Guid]::NewGuid().Guid
			ClientId                 = $ClientId
			IsSent                   = $false
			ExpirationDate           = $expiration
			SentTime                 = $now.ToString('yyyy-MM-ddTHH:mm:ss')
			SentTimeOffset           = [System.TimeZoneInfo]::Local.GetUtcOffset($now).ToString()
			ClientRecievedTime       = '0001-01-01T00:00:00'
			ClientRecievedTimeOffset = '00:00:00'
			Notification             = @{
				Id            = $NotificationId
				Actions       = [array]@(
					@{
						'<ActionType>k__BackingField'  = 0
						'<Arguments>k__BackingField'   = $null
						'<ProcessPath>k__BackingField' = $null
					}
				)
				ApplicationId = $null
				Lines         = [array]$lines
				Icon          = $null
				IconData      = $null
				Type          = 7
				Sound         = 0
			}
		}

		# ConvertTo-Json escapes non ascii characters as \uXXXX. The server reads
		# the body as utf-8, so the escapes are undone to keep umlauts readable in
		# the message and in the -WhatIf preview.
		$json = [System.Text.RegularExpressions.Regex]::Unescape(($body | ConvertTo-Json -Depth 10 -Compress))

		if (-not (Test-MmsShouldProcess -Cmdlet $PSCmdlet -Target "client $ClientId" -Action "Send the message '$Header'")) {
			return
		}

		return Invoke-MmsApiRequest -Path '/api/StoreableNotification' -Method POST -Body $json `
			-Session $Session -Confirm:$false
	}
}
