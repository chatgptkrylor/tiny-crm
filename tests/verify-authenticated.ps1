$ErrorActionPreference = 'Stop'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$login = Invoke-WebRequest 'http://localhost/Shop/Account/Login' -WebSession $session -UseBasicParsing
$tokenMatch = [regex]::Match($login.Content, 'name="__RequestVerificationToken" type="hidden" value="([^"]+)"')
if (-not $tokenMatch.Success) { throw 'Anti-forgery token not found' }

$body = @{
    Username = 'admin'
    Password = 'Admin@123'
    ReturnUrl = '/Shop/Dashboard'
    __RequestVerificationToken = $tokenMatch.Groups[1].Value
}

$result = Invoke-WebRequest 'http://localhost/Shop/Account/Login' -Method Post -Body $body -WebSession $session -UseBasicParsing
Write-Output "Login final URL: $($result.BaseResponse.ResponseUri)"
Write-Output "Login status: $($result.StatusCode)"

foreach ($path in @('Dashboard', 'Customers', 'Customers/Details/1', 'Customers/Create', 'Customers/Edit/1', 'Reports')) {
    $response = Invoke-WebRequest "http://localhost/Shop/$path" -WebSession $session -UseBasicParsing
    Write-Output "$path`: $($response.StatusCode)"
}
