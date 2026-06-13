$headers = @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    'Referer' = 'https://agnes-ai.com/'
}
$response = Invoke-WebRequest -Uri 'https://agnes-ai.com/api/notion-page/10ea21620a658191b080e6a4271959a3' -Headers $headers -UseBasicParsing
$content = [System.Text.Encoding]::UTF8.GetString($response.Content)
$content | Out-File -Encoding UTF8 'D:\Ai_Project\cardnote_homo\temp_api.json'
$lines = ($content -split "`n").Count
Write-Output "Saved $content chars, $lines lines"
