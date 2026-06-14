param(
    [string]$message = "chore: 更新代码"
)

Set-Location "D:\Ai_Project\cardnote_homo"

Write-Output ">>> Git Status <<<"
git status

Write-Output "`n>>> Staging all changes... <<<"
git add -A

Write-Output "`n>>> Committing: $message <<<"
git commit -m $message

Write-Output "`n>>> Pushing to origin... <<<"
git push

Write-Output "`n>>> Done! <<<"
