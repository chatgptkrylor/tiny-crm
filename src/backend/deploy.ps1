#requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$src = 'C:\src\Shop'
$sitePath = 'C:\inetpub\wwwroot\Shop'
$appPool = 'ShopAppPool'
$appPath = '/Shop'

Write-Host '=== Contoso Shop deploy ==='

# Ensure directories
New-Item -ItemType Directory -Force -Path $src | Out-Null
New-Item -ItemType Directory -Force -Path $sitePath | Out-Null

# Locate MSBuild
$msbuildCandidates = @(
  "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
  "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
  "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
  "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
  "${env:ProgramFiles(x86)}\MSBuild\14.0\Bin\MSBuild.exe"
)
$msbuild = $msbuildCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $msbuild) {
  throw 'MSBuild not found. Install Visual Studio Build Tools with Web workload.'
}
Write-Host "MSBuild: $msbuild"

# nuget.exe
$nuget = 'C:\tools\nuget.exe'
if (-not (Test-Path $nuget)) {
  New-Item -ItemType Directory -Force -Path 'C:\tools' | Out-Null
  Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nuget
}
Write-Host "NuGet: $nuget"

Push-Location $src
try {
  Write-Host 'Restoring NuGet packages...'
  & $nuget restore '.\Shop.csproj' -PackagesDirectory '.\packages' -NonInteractive
  if ($LASTEXITCODE -ne 0) { throw "nuget restore failed: $LASTEXITCODE" }

  Write-Host 'Building...'
  & $msbuild '.\Shop.csproj' /t:Build /p:Configuration=Release /p:Platform=AnyCPU /v:m /nologo
  if ($LASTEXITCODE -ne 0) { throw "msbuild failed: $LASTEXITCODE" }

  # Copy application files to IIS site path
  Write-Host "Publishing to $sitePath ..."
  if (Test-Path $sitePath) {
    Get-ChildItem $sitePath -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  }
  New-Item -ItemType Directory -Force -Path $sitePath | Out-Null

  $copyItems = @(
    'bin', 'Content', 'Views', 'Scripts', 'Global.asax', 'Web.config'
  )
  foreach ($item in $copyItems) {
    $from = Join-Path $src $item
    if (Test-Path $from) {
      Copy-Item -Path $from -Destination $sitePath -Recurse -Force
    }
  }

  # Roslyn compilers if present (for dynamic view compile fallback)
  $roslyn = Join-Path $src 'packages\Microsoft.CodeDom.Providers.DotNetCompilerPlatform.2.0.1\tools\RoslynLatest'
  if (-not (Test-Path $roslyn)) {
    $roslyn = Join-Path $src 'bin\roslyn'
  }
  if (Test-Path $roslyn) {
    New-Item -ItemType Directory -Force -Path (Join-Path $sitePath 'bin\roslyn') | Out-Null
    Copy-Item (Join-Path $roslyn '*') (Join-Path $sitePath 'bin\roslyn') -Recurse -Force -ErrorAction SilentlyContinue
  }
}
finally {
  Pop-Location
}

Import-Module WebAdministration -ErrorAction Stop

# App pool
if (-not (Test-Path "IIS:\AppPools\$appPool")) {
  New-WebAppPool -Name $appPool | Out-Null
}
Set-ItemProperty "IIS:\AppPools\$appPool" -Name managedRuntimeVersion -Value 'v4.0'
Set-ItemProperty "IIS:\AppPools\$appPool" -Name managedPipelineMode -Value 'Integrated'
Set-ItemProperty "IIS:\AppPools\$appPool" -Name startMode -Value 'AlwaysRunning' -ErrorAction SilentlyContinue
Restart-WebAppPool $appPool -ErrorAction SilentlyContinue

# Application under Default Web Site
$existing = Get-WebApplication -Site 'Default Web Site' -Name 'Shop' -ErrorAction SilentlyContinue
if ($existing) {
  Remove-WebApplication -Site 'Default Web Site' -Name 'Shop'
}
New-WebApplication -Site 'Default Web Site' -Name 'Shop' -PhysicalPath $sitePath -ApplicationPool $appPool | Out-Null

# Ensure Default Web Site is started
Start-Website -Name 'Default Web Site' -ErrorAction SilentlyContinue
Start-Service W3SVC -ErrorAction SilentlyContinue

Write-Host '=== Deploy complete ==='
Write-Host 'URL: http://localhost/Shop'
Write-Host 'URL: http://192.168.122.226/Shop'
