try {
    # Try GitHub raw docs
    $response = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Agnes-AI/Agnes-Docs/main/docs/zh/overview.md" -UseBasicParsing -TimeoutSec 15
    Write-Output $response
} catch {
    Write-Output "Error1: $($_.Exception.Message)"
    try {
        $response = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Agnes-AI/Agnes-Docs/main/docs/overview.md" -UseBasicParsing -TimeoutSec 15
        Write-Output $response
    } catch {
        Write-Output "Error2: $($_.Exception.Message)"
        try {
            # Try github.io
            $response = Invoke-WebRequest -Uri "https://agnes-ai.github.io/Agnes-Docs/zh/overview.html" -UseBasicParsing -TimeoutSec 15
            Write-Output $response.Content.Substring(0, [Math]::Min(3000, $response.Content.Length))
        } catch {
            Write-Output "Error3: $($_.Exception.Message)"
        }
    }
}
