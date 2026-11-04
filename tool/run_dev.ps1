param(
    [string]$Device = "chrome"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $PSScriptRoot "env.local.json"

if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Error "Missing tool/env.local.json. Copy tool/env.local.example.json to tool/env.local.json and enter your Supabase project URL and publishable key."
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$supabaseUrl = [string]$config.SUPABASE_URL
$supabaseAnonKey = [string]$config.SUPABASE_ANON_KEY

if (-not $supabaseUrl.StartsWith("https://") -or
    [string]::IsNullOrWhiteSpace($supabaseAnonKey) -or
    $supabaseUrl.Contains("YOUR_PROJECT_REF") -or
    $supabaseAnonKey.Contains("YOUR_PUBLISHABLE")) {
    Write-Error "Enter valid SUPABASE_URL and SUPABASE_ANON_KEY values in tool/env.local.json."
}

Push-Location $projectRoot
try {
    & flutter run -d $Device `
        "--dart-define=SUPABASE_URL=$supabaseUrl" `
        "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey"
}
finally {
    Pop-Location
}
