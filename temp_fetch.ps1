$response = Invoke-WebRequest -Uri "https://agnes-ai.com/doc/overview" -UseBasicParsing -TimeoutSec 15
Write-Output "Status: $($response.StatusCode)"
Write-Output "---CONTENT---"
Write-Output $response.Content
