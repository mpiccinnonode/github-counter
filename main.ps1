param(
    [Parameter(Mandatory=$true)]
    [string]$author,
    [Parameter(Mandatory=$true)]
    [int]$year,
    [Parameter(Mandatory=$true)]
    [int]$month,
    [Parameter(Mandatory=$true)]
    [string]$repoOwner,
    [Parameter(Mandatory=$true)]
    [string]$repoName
)

$token = $env:GITHUB_TOKEN # Imposta GITHUB_TOKEN come variabile di ambiente

if (-not $author -or -not $token -or -not $year -or -not $month -or -not $repoOwner -or -not $repoName) {
    Write-Host "Argomenti mancanti. Usa: .\main.ps1 <username> <anno> <mese> <owner> <repo>"
    return
}

$firstOfMonth = Get-Date -Year $year -Month $month -Day 1 -Hour 0 -Minute 0 -Second 0
Write-Host "Starting from: $firstOfMonth"

$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3+json"
}

function FormatPullDate {
	param(
		[string]$date
	)
	$startingFormat = 'MM/dd/yyyy HH:mm:ss'
	$dateParsed = [DateTime]::ParseExact($date, $startingFormat, $null)
	$parsedString = $dateParsed.toString('yyyy-MM-ddTHH:mm:ssZ')
	return [DateTime]::Parse($parsedString)
}

function HandlePullsFetch {
    param(
        [string]$reqUri
    )

    Write-Host "Fetching PRs..."
    $results = @()
	$page = 1;
    do {
        Write-Host "Fetching page $page..."
        try {
            $response = Invoke-RestMethod -ResponseHeadersVariable resHeaders -Uri $reqUri -Headers $headers -ErrorAction Stop
            Write-Host "Response: $($response.Count) items"
            $results += $response # Aggiungi i risultati all'array

			$firstElement = $response[0]
			$firstElementDate = FormatPullDate -date $firstElement.created_at
			Write-Host "First $($firstElement.title), at $firstElementDate..."

			$lastElement = $response[-1]
			Write-Host "Last element: $($lastElement.created_at)"
			$lastElementDate = FormatPullDate -date $lastElement.created_at

			# Blocca l'esecuzione se l'ultimo elemento della pagina è meno recente del primo giorno del mese
			if ($lastElementDate -ge $firstOfMonth) {
				$linkHeader = $resHeaders.Link
				if ($linkHeader -match 'rel="next"') {
					$reqUri = ($linkHeader -split ',')[0] -replace '<(.*)>', '$1'
					Write-Host "Next page"
					$page++
				} else {
					$reqUri = $null
				}
			} else {
				Write-Host "Blocking on $($lastElement.title), at $lastElementDate..."
				$reqUri = $null
			}
        } catch {
            Write-Host "Errore durante il recupero degli eventi: $($_.Exception.Message)"
            break
        }
    } while ($reqUri)

    return $results # Restituisci l'array di risultati
}

function FetchCommits {
    param(
        [string]$reqUri
    )

    $results = @()
    do {
        try
        {
            $response = Invoke-RestMethod -ResponseHeadersVariable resHeaders -Uri $reqUri -Headers $headers -ErrorAction Stop
            $results += $response

            $linkHeader = $resHeaders.Link
            if ($linkHeader -match 'rel="next"') {
                $reqUri = ($linkHeader -split ',')[0] -replace '<(.*)>', '$1'
            } else {
                $reqUri = $null
            }
        }
        catch
        {
            Write-Host "Errore durante il recupero dei commit: $($_.Exception.Message)"
            break
        }
    } while($reqUri)

    return $results
}

function FetchPullReviews {
    param(
        [int]$pullNumber
    )

    $uri = "https://api.github.com/repos/$repoOwner/$repoName/pulls/$pullNumber/reviews?per_page=100"
    $results = @();

    do {
        try {
            $response = Invoke-RestMethod -ResponseHeadersVariable resHeaders -Uri $uri -Headers $headers -ErrorAction Stop
            $results += $response

            $linkHeader = $resHeaders.Link
            if ($linkHeader -match 'rel="next"') {
                $uri = ($linkHeader -split ',')[0] -replace '<(.*)>', '$1'
            } else {
                $uri = $null
            }
        } catch {
            Write-Host "Errore durante il recupero delle review: $($_.Exception.Message)"
            break
        }
    } while ($uri)

    return $results;
}

function FetchCommitStats {
    param(
        [string]$sha
    )
    $uri = "https://api.github.com/repos/$repoOwner/$repoName/commits/$sha"
    try
    {
        $response = Invoke-RestMethod -ResponseHeadersVariable resHeaders -Uri $uri -Headers $headers -ErrorAction Stop
        return @{stats = $response.stats; files = $response.files}
    }
    catch
    {
        Write-Host "Errore durante il recupero delle statistiche: $($_.Exception.Message)"
        break
    }

}

$daysInMonth = [DateTime]::DaysInMonth([int]$year, [int]$month)
$prsUri = "https://api.github.com/repos/$repoOwner/$repoName/pulls?state=all&per_page=100"

$allPulls = HandlePullsFetch -reqUri $prsUri

Write-Host "Fetching commits and stats..."

for ($day = 1; $day -le $daysInMonth; $day++) {
	$date = Get-Date -Year $year -Month $month -Day $day
	$startDate = $date.ToString("yyyy-MM-ddT00:00:00Z")
	$endDate = $date.ToString("yyyy-MM-ddT23:59:59Z");
    Write-Host "--------";
    Write-Host "Current day: $($date.ToString("dd/MM/yyyy"))";

    $reviewsCount = 0;
    $pullRequestsCount = 0;
    $commitsCount = 0;
    $filesCount = 0;
    $additionsCount = 0;
    $removalsCount = 0;

    foreach ($pull in $allPulls) {
        $createdAt = FormatPullDate -date $pull.created_at

        if ($createdAt -ge [DateTime]::Parse($startDate) -and $createdAt -le [DateTime]::Parse($endDate)) {
			$isAuthor = $pull.user.login -eq $autor
			$isAssignee = $pull.assignee.login -eq $author
			$isIntoAssignees = $pull.assignees | Where-Object { $_.login -eq $author }

            if ($isAuthor -or $isAssignee -or $isIntoAssignees) {
                $pullRequestsCount++
            }

            Write-Host "Fetching reviews for pull #$($pull.number)"
            $allPullReviews = FetchPullReviews -pullNumber $($pull.number)
            $myPullReviews = $allPullReviews | Where-Object {$_.user.login -eq $author}
            $reviewsCount += $myPullReviews.Count;
        }
    }

    $commitsUri = "https://api.github.com/repos/$repoOwner/$repoName/commits?author=$author&since=$startDate&until=$endDate"
    # Write-Host "Commits uri: $commitsUri"
    $dayCommits = FetchCommits -reqUri $commitsUri
    $commitsCount = $dayCommits.Count

    foreach ($commit in $dayCommits) {
        $commitInfo = FetchCommitStats -sha $commit.sha
        $additionsCount += $commitInfo.stats.additions
        $removalsCount += $commitInfo.stats.deletions
        $filesCount += $commitInfo.files.Count
    }

    if ($reviewsCount -gt 0 -or $pullRequestsCount -gt 0 -or $commitsCount -gt 0 -or $additionsCount -gt 0 -or $removalsCount -gt 0 -or $filesCount -gt 0) {
        $output = @(
            [pscustomobject]@{ "Statistica" = "Giorno"; "Valore" = $($date.ToString("yyyy-MM-dd")) },
            [pscustomobject]@{ "Statistica" = "Review effettuate"; "Valore" = $reviewsCount },
            [pscustomobject]@{ "Statistica" = "Pull request aperte"; "Valore" = $pullRequestsCount },
            [pscustomobject]@{ "Statistica" = "N. commit"; "Valore" = $commitsCount },
            [pscustomobject]@{ "Statistica" = "File modificati"; "Valore" = $filesCount },
            [pscustomobject]@{ "Statistica" = "Tot. aggiunte"; "Valore" = $additionsCount },
            [pscustomobject]@{ "Statistica" = "Tot. rimozioni"; "Valore" = $removalsCount }
        )

        $output | Format-Table -AutoSize

        Write-Host "Salvando su file excel..."
        .\write_day_report.ps1 -Day $day -Year $year -Month $month -Prs $pullRequestsCount -Reviews $reviewsCount -Commits $commitsCount -FilesChanged $filesCount -Additions $additionsCount -Removals $removalsCount
    }
}
Write-Host "---------"
Write-Host "Processo terminato"
Write-Host "---------"
