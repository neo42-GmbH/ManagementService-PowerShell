function Get-MmsFilterEvaluation {
	<#
	.SYNOPSIS
		Returns the recorded filter (criteria) evaluation runs.
	.DESCRIPTION
		Wraps the documented route of the 'MMS Filter' group:
			GET /api/CriteriaGroupEvalDuration   all recorded evaluation runs

		The server writes these entries only after an evaluation run finished
		without errors, one per criteria group. They are therefore the evidence
		that the filter evaluation actually ran, and when it last succeeded. An
		empty result, or a newest CreatedOn that is old, means the evaluation is
		not completing - for example because a connector it depends on is
		unreachable and the run is being skipped.

		GroupName is the criteria group, for example 'Active Directory', and
		AssociatedFilter lists the filters that group covered.

		Generation counts the evaluation passes of one service run and **restarts
		at 1 every time the service restarts**. It is therefore not a timeline:
		a higher Generation can be older than a lower one. Always order by
		CreatedOn to find the most recent pass.
	.PARAMETER Latest
		Returns only the entries of the most recent evaluation pass, determined
		by CreatedOn. A pass writes all of its group entries at once, so this is
		the newest entry plus the entries of the same Generation written with it.
	.EXAMPLE
		Get-MmsFilterEvaluation -Latest

		Shows the criteria groups of the most recent successful evaluation pass.
	.EXAMPLE
		(Get-MmsFilterEvaluation | Sort-Object CreatedOn -Descending | Select-Object -First 1).CreatedOn

		Answers 'when did the filter evaluation last succeed'.
	.EXAMPLE
		Get-MmsFilterEvaluation -Latest | Select-Object GroupName, Duration, @{ n = 'Filters'; e = { @($_.AssociatedFilter).Count } }

		Shows how long each criteria group took and how many filters it covered.
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter()]
		[switch]
		$Latest,

		[Parameter()]
		[object]
		$Session
	)

	$request = @{
		Session = $Session
	}

	$entries = @(Invoke-MmsApiRequest -Path '/api/CriteriaGroupEvalDuration' @request)

	if (-not $Latest -or $entries.Count -eq 0) {
		return $entries
	}

	# Generation restarts at 1 on every service start, so the newest pass is the
	# one with the newest CreatedOn - not the one with the highest Generation.
	$newest = $entries | Sort-Object { [datetime]$_.CreatedOn } -Descending | Select-Object -First 1

	# The server writes all group entries of a pass in a single call, so their
	# timestamps are milliseconds apart. The window only has to separate this
	# pass from the previous one and from an equal Generation of an earlier
	# service run, which are minutes to days away.
	$windowStart = ([datetime]$newest.CreatedOn).AddMinutes(-1)

	return @($entries | Where-Object {
			$_.Generation -eq $newest.Generation -and [datetime]$_.CreatedOn -ge $windowStart
		})
}
