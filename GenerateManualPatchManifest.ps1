param(
    [string]$PatchRoot = "",
    [string]$Version = "1.0.0",
    [string]$BaseUrl = "https://raw.githubusercontent.com/Online-Updates/aetheria-online-patch/main/files"
)

if ([string]::IsNullOrWhiteSpace($PatchRoot)) {
    $PatchRoot = $PSScriptRoot
}

$manifestPath = Join-Path $PatchRoot "manifest.json"
$filesRoot = Join-Path $PatchRoot "files"
$deleteRoot = Join-Path $PatchRoot "delete_folder"

function Write-ManualStep {
    param([string]$Message)
    Write-Host ("[Manual Patch] " + $Message) -ForegroundColor Green
}

function Write-ManualProgress {
    param(
        [string]$Phase,
        [int]$Current,
        [int]$Total
    )

    if ($Total -le 0) {
        return
    }

    Write-Host ("[Manual Patch] {0} {1} / {2}" -f $Phase, $Current, $Total) -ForegroundColor DarkGreen
}

function Convert-ToManifestPath {
    param(
        [string]$RootPath,
        [string]$FullName
    )

    $rootFull = (Resolve-Path -LiteralPath $RootPath).Path.TrimEnd('\')
    $rootUri = New-Object System.Uri(($rootFull + '\'))
    $fileUri = New-Object System.Uri($FullName)
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($fileUri).ToString()).Replace('\', '/')
}

function Write-PatchManifest {
    param(
        [string]$OutputPath,
        [string]$Version,
        [System.Collections.IEnumerable]$DeletedFiles,
        [System.Collections.IEnumerable]$PatchFiles
    )

    $patchManifest = [ordered]@{
        version = $Version
        generatedUtc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        fileCount = @($PatchFiles).Count
        deletedFiles = @($DeletedFiles)
        files = @($PatchFiles)
    }

    $json = $patchManifest | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($OutputPath, $json + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
}

if (-not (Test-Path -LiteralPath $PatchRoot)) {
    throw "Patch root not found: $PatchRoot"
}

if (-not (Test-Path -LiteralPath $filesRoot)) {
    New-Item -ItemType Directory -Path $filesRoot -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $deleteRoot)) {
    New-Item -ItemType Directory -Path $deleteRoot -Force | Out-Null
}

Write-ManualStep ("Patch root: {0}" -f (Resolve-Path -LiteralPath $PatchRoot).Path)
Write-ManualStep "Scanning Updates\\files..."
$patchCandidates = @(Get-ChildItem -LiteralPath $filesRoot -Recurse -File | Sort-Object FullName)
Write-ManualStep ("Found {0} patch files." -f $patchCandidates.Count)

$patchFiles = New-Object System.Collections.Generic.List[object]
$hashProgressTotal = $patchCandidates.Count
$hashProgressIndex = 0
foreach ($file in $patchCandidates) {
    $hashProgressIndex++
    if ($hashProgressIndex -eq 1 -or ($hashProgressIndex % 100) -eq 0 -or $hashProgressIndex -eq $hashProgressTotal) {
        Write-ManualProgress -Phase "Hashing patch files" -Current $hashProgressIndex -Total $hashProgressTotal
    }

    $manifestPathKey = Convert-ToManifestPath -RootPath $filesRoot -FullName $file.FullName
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $downloadUrl = ""
    if (-not [string]::IsNullOrWhiteSpace($BaseUrl)) {
        $downloadUrl = ($BaseUrl.TrimEnd('/') + "/" + $manifestPathKey)
    }

    $patchFiles.Add([ordered]@{
        path = $manifestPathKey
        sha256 = $hash
        size = [int64]$file.Length
        url = $downloadUrl
    })
}

Write-ManualStep "Scanning Updates\\delete_folder..."
$deleteCandidates = @(Get-ChildItem -LiteralPath $deleteRoot -Recurse -File | Sort-Object FullName)
Write-ManualStep ("Found {0} delete markers." -f $deleteCandidates.Count)

$deletedFiles = New-Object System.Collections.Generic.List[string]
foreach ($file in $deleteCandidates) {
    $manifestPathKey = Convert-ToManifestPath -RootPath $deleteRoot -FullName $file.FullName
    $deletedFiles.Add($manifestPathKey)
}

Write-ManualStep "Writing patch manifest..."
Write-PatchManifest -OutputPath $manifestPath -Version $Version -DeletedFiles $deletedFiles -PatchFiles $patchFiles
Write-ManualStep ("Manifest written: {0}" -f $manifestPath)
Write-ManualStep "Manual patch manifest complete."

$summary = [ordered]@{
    version = $Version
    changedFileCount = $patchFiles.Count
    deletedFileCount = $deletedFiles.Count
    patchRoot = $PatchRoot
    manifestPath = $manifestPath
    mode = "manual_patch_folder"
}

$summary | ConvertTo-Json -Depth 4
