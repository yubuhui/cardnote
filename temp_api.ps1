try {
    $response = Invoke-RestMethod -Uri "https://agnes-ai.com/api/doc/overview" -UseBasicParsing -TimeoutSec 15
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Output $_.Exception.Message
}
