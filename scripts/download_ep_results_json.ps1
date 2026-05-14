param(
    [string]$PageUrl = 'https://results.elections.europa.eu/en/tools/download-datasheets/',
    [string]$OutputRoot = 'data/elections/raw/european_parliament_results/json'
)

$ErrorActionPreference = 'Stop'

$baseUri = [System.Uri]'https://results.elections.europa.eu'
$html = (Invoke-WebRequest -Uri $PageUrl -UseBasicParsing).Content
$links = [regex]::Matches($html, 'href="([^"]+\.json)"') |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$manifest = New-Object System.Collections.Generic.List[object]
$errors = New-Object System.Collections.Generic.List[object]

$index = 0
foreach ($link in $links) {
    $index++
    $relativePath = $link -replace '^/data-sheets/json/', ''
    $localPath = Join-Path $OutputRoot ($relativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
    New-Item -ItemType Directory -Force -Path (Split-Path $localPath -Parent) | Out-Null

    $url = [System.Uri]::new($baseUri, $link).AbsoluteUri
    try {
        Invoke-WebRequest -Uri $url -OutFile $localPath -UseBasicParsing
        $item = Get-Item $localPath
        $manifest.Add([pscustomobject]@{
            source_url = $url
            relative_url = $link
            local_path = $localPath.Replace('\', '/')
            bytes = $item.Length
            modified_utc = $item.LastWriteTimeUtc.ToString('s') + 'Z'
        })

        if (($index % 50) -eq 0) {
            Write-Host "Downloaded $index / $($links.Count)"
        }
    }
    catch {
        $errors.Add([pscustomobject]@{
            source_url = $url
            local_path = $localPath.Replace('\', '/')
            error = $_.Exception.Message
        })
        Write-Warning ("Failed {0}: {1}" -f $url, $_.Exception.Message)
    }
}

$manifestPath = Join-Path (Split-Path $OutputRoot -Parent) 'json_manifest.csv'
$errorsPath = Join-Path (Split-Path $OutputRoot -Parent) 'json_download_errors.csv'
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $manifestPath
$errors | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $errorsPath

Write-Host "Downloaded $($manifest.Count) JSON files; errors $($errors.Count)."
Write-Host "Manifest: $manifestPath"
Write-Host "Errors: $errorsPath"