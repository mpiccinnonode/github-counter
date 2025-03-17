param(
    [Parameter(Mandatory=$true)]
    [int]$day,
    [Parameter(Mandatory=$true)]
    [int]$year,
    [Parameter(Mandatory=$true)]
    [int]$month,
    [Parameter(Mandatory=$true)]
    [int]$prs,
    [Parameter(Mandatory=$true)]
    [int]$reviews,
    [Parameter(Mandatory=$true)]
    [int]$commits,
    [Parameter(Mandatory=$true)]
    [int]$filesChanged,
    [Parameter(Mandatory=$true)]
    [int]$additions,
    [Parameter(Mandatory=$true)]
    [int]$removals
)
$path = Split-Path -Parent $MyInvocation.MyCommand.Definition;

class GitHubCounters {
    [int]$PRs;
    [int]$Rewiews;
    [int]$Commits;
    [int]$FilesChanged;
    [int]$Additions;
    [int]$Removals;

    GitHubCounters([int]$PRs, [int]$Reviews, [int]$Commits, [int]$FilesChanged, [int]$Additions, [int]$Removals) {
        $this.PRs = $PRs;
        $this.Rewiews = $Reviews;
        $this.Commits = $Commits;
        $this.FilesChanged = $FilesChanged;
        $this.Additions = $Additions;
        $this.Removals = $Removals;
    }
}


$counters = [GitHubCounters]::new($prs, $reviews, $commits, $filesChanged, $additions, $removals);

function CheckPackage {
    if (-not (Get-Module -Name ImportExcel)) {
        # Installa il modulo ImportExcel
        try {
            Write-Host "Installando ImportExcel..."
            Install-Module -Name ImportExcel -Force
            Write-Host "Il modulo ImportExcel è stato installato correttamente."
        }
        catch {
            Write-Error "Errore durante l'installazione del modulo ImportExcel: $($_.Exception.Message)"
        }
    } else {
        Write-Host "Il modulo ImportExcel è già installato."
    }
}

function GetWorksheet {
    param(
        [object]$excelObj,
        [int]$year,
        [int]$month
    )
    $workSheetName = "$month-$year"
    if ($month -lt 10)
    {
        $workSheetName = "0$workSheetName"
    }

    Write-Host $workSheetName
    $workSheet = $excelPackage.Workbook.Worksheets[$workSheetName]
    return $workSheet
}

function FindRowIndex {
    param(
        [object]$worksheet,
        [int]$day,
        [int]$month,
        [int]$year
    )

    $result;
    $date = Get-Date -Year $year -Month $month -Day $day
    $toSeek = $date.ToString("MM/dd/yyyy 00:00:00")
    $rows = $worksheet.Dimension.Rows;

    for($row = 2; $row -le $rows; $row++) {
        $cellValue = $worksheet.Cells[$row, 1].Value;
        if ($cellValue -eq $toSeek)
        {
            Write-Host "Row: $row; Date: $cellValue"
            $result = $row
            break;
        }
    }

    return $result;
}

function WriteCounters {
    param(
        [object]$worksheet,
        [GitHubCounters]$counters,
        [int]$row
    )

    $colIndexes = @{
        prs = 3;
        reviews = 4;
        commits = 5;
        filesChanged = 6;
        additions = 7;
        removals = 8
    }

    if($counters.PRs) {
        UpdateCellValue -worksheet $worksheet -row $row -col $($colIndexes.prs) -value $($counters.PRs)
    }
    if($counters.Rewiews) {
        UpdateCellValue -worksheet $worksheet -row $row -col $($colIndexes.reviews) -value $($counters.Rewiews)
    }
    if($counters.Commits) {
        UpdateCellValue -worksheet $worksheet -row $row -col $($colIndexes.commits) -value $($counters.Commits)
    }
    if($counters.FilesChanged) {
        UpdateCellValue -worksheet $worksheet -row $row -col $($colIndexes.filesChanged) -value $($counters.FilesChanged)
    }
    if($counters.Additions) {
        UpdateCellValue -worksheet $worksheet -row $row -col $($colIndexes.additions) -value $($counters.Additions)
    }
    if($counters.Removals) {
        UpdateCellValue -worksheet $worksheet -row $row -col $($colIndexes.removals) -value $($counters.Removals)
    }

    Write-Host "Valori aggiornati"
}

function UpdateCellValue {
    param(
        [object]$worksheet,
        [int]$row,
        [int]$col,
        [int]$value
    )

    $cell = $worksheet.Cells[$row, $col]
    Write-Host "--- Cell $cell"
    Write-Host "Current $($cell.Value)"
    Write-Host "To sum $value"
    $cell.Value += $value;
}

CheckPackage

$fileName = "Report.xlsx";
$filePath = Join-Path -Path $path -ChildPath $fileName;

$excelPackage = Open-ExcelPackage -Path $filePath;
$worksheet = GetWorksheet -excelObj $excelPackage -year $year -month $month
Write-Host "Sheet $($worksheet)"

$rowIndex = FindRowIndex -worksheet $worksheet -day $day -month $month -year $year

WriteCounters -worksheet $worksheet -counters $counters -row $rowIndex[1]

Close-ExcelPackage -ExcelPackage $excelPackage
$excelPackage.Dispose();

Write-Host "Modifiche salvate in '$filePath'"
