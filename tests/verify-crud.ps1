$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$login = Invoke-WebRequest 'http://localhost/Shop/Account/Login' -WebSession $session -UseBasicParsing
$token = [regex]::Match($login.Content, 'name="__RequestVerificationToken" type="hidden" value="([^"]+)"').Groups[1].Value
Invoke-WebRequest 'http://localhost/Shop/Account/Login' -Method Post -Body @{
    Username = 'admin'; Password = 'Admin@123'; ReturnUrl = '/Shop/Dashboard'; __RequestVerificationToken = $token
} -WebSession $session -UseBasicParsing | Out-Null

# Create customer
$create = Invoke-WebRequest 'http://localhost/Shop/Customers/Create' -WebSession $session -UseBasicParsing
$ctoken = [regex]::Match($create.Content, 'name="__RequestVerificationToken" type="hidden" value="([^"]+)"').Groups[1].Value
$newCust = Invoke-WebRequest 'http://localhost/Shop/Customers/Create' -Method Post -Body @{
    Name = 'Test Customer'; Email = 'test@example.com'; Phone = '555-9999'; Company = 'TestCo'; Status = 'Lead'; __RequestVerificationToken = $ctoken
} -WebSession $session -UseBasicParsing
Write-Output "Create customer: $($newCust.StatusCode)"

# Find the new customer id (highest id in list)
$list = Invoke-WebRequest 'http://localhost/Shop/Customers' -WebSession $session -UseBasicParsing
$ids = [regex]::Matches($list.Content, 'Details/(\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
$newId = ($ids | Measure-Object -Maximum).Maximum
Write-Output "New customer id: $newId"

# Log interaction
$det = Invoke-WebRequest "http://localhost/Shop/Customers/Details/$newId" -WebSession $session -UseBasicParsing
$itoken = [regex]::Match($det.Content, 'name="__RequestVerificationToken" type="hidden" value="([^"]+)"').Groups[1].Value
$inter = Invoke-WebRequest "http://localhost/Shop/Interactions/Create?customerId=$newId" -Method Post -Body @{
    Type = 'Call'; Note = 'Test interaction note'; __RequestVerificationToken = $itoken
} -WebSession $session -UseBasicParsing
Write-Output "Log interaction: $($inter.StatusCode)"

# Verify interaction appears
$det2 = Invoke-WebRequest "http://localhost/Shop/Customers/Details/$newId" -WebSession $session -UseBasicParsing
Write-Output "Interaction visible: $($det2.Content -match 'Test interaction note')"

# Edit customer
$edit = Invoke-WebRequest "http://localhost/Shop/Customers/Edit/$newId" -WebSession $session -UseBasicParsing
$etoken = [regex]::Match($edit.Content, 'name="__RequestVerificationToken" type="hidden" value="([^"]+)"').Groups[1].Value
$edited = Invoke-WebRequest "http://localhost/Shop/Customers/Edit/$newId" -Method Post -Body @{
    Id = $newId; Name = 'Test Customer Updated'; Email = 'test@example.com'; Phone = '555-9999'; Company = 'TestCo'; Status = 'Customer'; __RequestVerificationToken = $etoken
} -WebSession $session -UseBasicParsing
Write-Output "Edit customer: $($edited.StatusCode)"

# Verify edit persisted
$det3 = Invoke-WebRequest "http://localhost/Shop/Customers/Details/$newId" -WebSession $session -UseBasicParsing
Write-Output "Edit persisted: $($det3.Content -match 'Test Customer Updated')"

# Delete customer
$del = Invoke-WebRequest "http://localhost/Shop/Customers/Delete/$newId" -Method Post -Body @{ __RequestVerificationToken = $etoken } -WebSession $session -UseBasicParsing
Write-Output "Delete customer: $($del.StatusCode)"

# Verify deleted
$list2 = Invoke-WebRequest 'http://localhost/Shop/Customers' -WebSession $session -UseBasicParsing
Write-Output "Deleted gone: $(-not ($list2.Content -match 'Test Customer Updated'))"