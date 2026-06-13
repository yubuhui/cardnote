try {
    # Try Markdown export endpoint
    $response = Invoke-RestMethod -Uri "https://agnes-ai.com/api/doc/overview/markdown" -Headers @{"Accept"="text/markdown"} -UseBasicParsing -TimeoutSec 15
    Write-Output $response
} catch {
    Write-Output "Error1: $($_.Exception.Message)"
    try {
        # Try with different content type
        $response = Invoke-RestMethod -Uri "https://agnes-ai.com/api/doc/overview" -Headers @{"Accept"="text/markdown"} -UseBasicParsing -TimeoutSec 15
        Write-Output $response
    } catch {
        Write-Output "Error2: $($_.Exception.Message)"
    }
}
