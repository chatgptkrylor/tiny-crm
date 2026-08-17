#requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$src = 'C:\src\Shop\backend'
$frontend = 'C:\src\Shop\frontend'
$sitePath = 'C:\inetpub\wwwroot\Shop'
$appPool = 'ShopAppPool'
$framework = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319'
$csc = Join-Path $framework 'csc.exe'
$nuget = 'C:\tools\nuget.exe'

Write-Host '=== Contoso Shop build (csc) ==='
if (-not (Test-Path $csc)) { throw "csc not found: $csc" }

New-Item -ItemType Directory -Force -Path 'C:\tools' | Out-Null
if (-not (Test-Path $nuget)) {
  Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nuget
}

Push-Location $src
try {
  Write-Host 'NuGet restore...'
  & $nuget restore '.\packages.config' -PackagesDirectory '.\packages' -NonInteractive
  if ($LASTEXITCODE -ne 0) {
    # fallback: install packages explicitly
    & $nuget install Microsoft.AspNet.Mvc -Version 5.2.9 -OutputDirectory '.\packages' -NonInteractive
    & $nuget install Microsoft.Web.Infrastructure -Version 2.0.0 -OutputDirectory '.\packages' -NonInteractive
    & $nuget install Microsoft.CodeDom.Providers.DotNetCompilerPlatform -Version 2.0.1 -OutputDirectory '.\packages' -NonInteractive
    & $nuget install BCrypt.Net-Next -Version 3.3.0 -OutputDirectory '.\packages' -NonInteractive
  }

  $pkg = Join-Path $src 'packages'
  $refs = @(
    (Join-Path $pkg 'Microsoft.AspNet.Mvc.5.2.9\lib\net45\System.Web.Mvc.dll'),
    (Join-Path $pkg 'Microsoft.AspNet.Razor.3.2.9\lib\net45\System.Web.Razor.dll'),
    (Join-Path $pkg 'Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.Helpers.dll'),
    (Join-Path $pkg 'Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.WebPages.dll'),
    (Join-Path $pkg 'Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.WebPages.Deployment.dll'),
    (Join-Path $pkg 'Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.WebPages.Razor.dll'),
    (Join-Path $pkg 'Microsoft.Web.Infrastructure.2.0.0\lib\net40\Microsoft.Web.Infrastructure.dll'),
    (Join-Path $pkg 'BCrypt.Net-Next.3.3.0\lib\net472\BCrypt.Net-Next.dll'),
    (Join-Path $framework 'System.Web.dll'),
    (Join-Path $framework 'System.Web.Extensions.dll'),
    (Join-Path $framework 'System.Web.Abstractions.dll'),
    (Join-Path $framework 'System.Web.Routing.dll'),
    (Join-Path $framework 'System.Web.ApplicationServices.dll'),
    (Join-Path $framework 'System.Configuration.dll'),
    (Join-Path $framework 'System.ComponentModel.DataAnnotations.dll'),
    (Join-Path $framework 'System.Net.Http.dll'),
    (Join-Path $framework 'System.Core.dll'),
    (Join-Path $framework 'System.dll'),
    (Join-Path $framework 'System.Xml.dll'),
    (Join-Path $framework 'System.Data.dll'),
    (Join-Path $framework 'Microsoft.CSharp.dll')
  )

  foreach ($r in $refs) {
    if (-not (Test-Path $r)) { throw "Missing reference: $r" }
  }

  $sources = Get-ChildItem -Path $src -Recurse -Filter '*.cs' |
    Where-Object { $_.FullName -notmatch '\\packages\\' -and $_.FullName -notmatch '\\obj\\' } |
    ForEach-Object { $_.FullName }

  New-Item -ItemType Directory -Force -Path (Join-Path $src 'bin') | Out-Null
  $outDll = Join-Path $src 'bin\Shop.dll'

  Write-Host "Compiling $($sources.Count) sources -> $outDll"
  $rsp = Join-Path $src 'bin\build.rsp'
  $rspLines = New-Object System.Collections.Generic.List[string]
  $rspLines.Add('/nologo') | Out-Null
  $rspLines.Add('/target:library') | Out-Null
  $rspLines.Add("/out:$outDll") | Out-Null
  $rspLines.Add('/debug+') | Out-Null
  $rspLines.Add('/optimize-') | Out-Null
  $rspLines.Add('/define:DEBUG;TRACE') | Out-Null
  $rspLines.Add('/langversion:default') | Out-Null
  foreach ($r in $refs) { $rspLines.Add("/r:$r") | Out-Null }
  foreach ($s in $sources) { $rspLines.Add($s) | Out-Null }
  $rspLines | Set-Content -Path $rsp -Encoding ASCII

  & $csc "@$rsp"
  if ($LASTEXITCODE -ne 0) { throw "csc failed: $LASTEXITCODE" }
  if (-not (Test-Path $outDll)) { throw 'Shop.dll not produced' }

  # Copy dependency DLLs into bin
  $depDlls = @(
    (Join-Path $pkg 'Microsoft.AspNet.Mvc.5.2.9\lib\net45\System.Web.Mvc.dll'),
    (Join-Path $pkg 'Microsoft.AspNet.Razor.3.2.9\lib\net45\System.Web.Razor.dll'),
    (Join-Path $pkg 'Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.Helpers.dll'),
    (Join-Path $pkg 'Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.WebPages.dll'),
    (Join-Path $pkg 'Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.WebPages.Deployment.dll'),
    (Join-Path $pkg 'Microsoft.AspNet.WebPages.3.2.9\lib\net45\System.Web.WebPages.Razor.dll'),
    (Join-Path $pkg 'Microsoft.Web.Infrastructure.2.0.0\lib\net40\Microsoft.Web.Infrastructure.dll'),
    (Join-Path $pkg 'BCrypt.Net-Next.3.3.0\lib\net472\BCrypt.Net-Next.dll')
  )
  foreach ($d in $depDlls) {
    Copy-Item $d (Join-Path $src 'bin') -Force
  }

  # CodeDom provider optional
  $codedom = Join-Path $pkg 'Microsoft.CodeDom.Providers.DotNetCompilerPlatform.2.0.1\lib\net45\Microsoft.CodeDom.Providers.DotNetCompilerPlatform.dll'
  if (Test-Path $codedom) {
    Copy-Item $codedom (Join-Path $src 'bin') -Force
  }

  Write-Host "Publishing to $sitePath"
  if (Test-Path $sitePath) {
    Get-ChildItem $sitePath -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  }
  New-Item -ItemType Directory -Force -Path $sitePath | Out-Null
  Copy-Item (Join-Path $src 'bin') $sitePath -Recurse -Force
  Copy-Item (Join-Path $frontend 'Views') $sitePath -Recurse -Force
  Copy-Item (Join-Path $src 'Global.asax') $sitePath -Force
  Copy-Item (Join-Path $src 'Web.config') $sitePath -Force

  # Soften codedom if roslyn missing
  $webConfigPath = Join-Path $sitePath 'Web.config'
  if (-not (Test-Path (Join-Path $sitePath 'bin\Microsoft.CodeDom.Providers.DotNetCompilerPlatform.dll'))) {
    [xml]$cfg = Get-Content $webConfigPath
    $codedomNode = $cfg.configuration['system.codedom']
    if ($codedomNode) {
      $cfg.configuration.RemoveChild($codedomNode) | Out-Null
      $cfg.Save($webConfigPath)
    }
  }
}
finally {
  Pop-Location
}

Import-Module WebAdministration

if (-not (Test-Path "IIS:\AppPools\$appPool")) {
  New-WebAppPool -Name $appPool | Out-Null
}
Set-ItemProperty "IIS:\AppPools\$appPool" -Name managedRuntimeVersion -Value 'v4.0'
Set-ItemProperty "IIS:\AppPools\$appPool" -Name managedPipelineMode -Value 'Integrated'

$existing = Get-WebApplication -Site 'Default Web Site' -Name 'Shop' -ErrorAction SilentlyContinue
if ($existing) {
  Remove-WebApplication -Site 'Default Web Site' -Name 'Shop'
}
New-WebApplication -Site 'Default Web Site' -Name 'Shop' -PhysicalPath $sitePath -ApplicationPool $appPool | Out-Null

# Grant IIS_IUSRS read on site
icacls $sitePath /grant 'IIS_IUSRS:(OI)(CI)RX' /T | Out-Null

Restart-WebAppPool $appPool
Start-Website -Name 'Default Web Site' -ErrorAction SilentlyContinue
Start-Service W3SVC -ErrorAction SilentlyContinue

Write-Host '=== Deploy complete ==='
Write-Host 'http://localhost/Shop'
Write-Host 'http://192.168.122.226/Shop'
