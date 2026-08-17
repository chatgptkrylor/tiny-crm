$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$login = Invoke-WebRequest 'http://localhost/Shop/Account/Login' -WebSession $session -UseBasicParsing
$token = [regex]::Match($login.Content, 'name="__RequestVerificationToken" type="hidden" value="([^"]+)"').Groups[1].Value
Invoke-WebRequest 'http://localhost/Shop/Account/Login' -Method Post -Body @{
    Username = 'admin'; Password = 'Admin@123'; ReturnUrl = '/Shop/Dashboard'; __RequestVerificationToken = $token
} -WebSession $session -UseBasicParsing | Out-Null

$dash = Invoke-WebRequest 'http://localhost/Shop/Dashboard' -WebSession $session -UseBasicParsing
Write-Output "Dashboard has 'Total Customers': $($dash.Content -match 'Total Customers')"
Write-Output "Dashboard has 'Recent Interactions': $($dash.Content -match 'Recent Interactions')"
Write-Output "Dashboard has 'Quick Access': $($dash.Content -match 'Quick Access')"

$cust = Invoke-WebRequest 'http://localhost/Shop/Customers' -WebSession $session -UseBasicParsing
Write-Output "Customers has 'John Smith': $($cust.Content -match 'John Smith')"
Write-Output "Customers has 'New Customer': $($cust.Content -match 'New Customer')"

$det = Invoke-WebRequest 'http://localhost/Shop/Customers/Details/1' -WebSession $session -UseBasicParsing
Write-Output "Details has 'Interaction History': $($det.Content -match 'Interaction History')"
Write-Output "Details has 'Log New Interaction': $($det.Content -match 'Log New Interaction')"

$rep = Invoke-WebRequest 'http://localhost/Shop/Reports' -WebSession $session -UseBasicParsing
Write-Output "Reports has 'Customers by Status': $($rep.Content -match 'Customers by Status')"
Write-Output "Reports has 'progress-bar': $($rep.Content -match 'progress-bar')"