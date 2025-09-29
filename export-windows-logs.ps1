$dest = "C:\Logs"
New-Item -Path $dest -ItemType Directory -Force | Out-Null

Get-WinEvent -ListLog * |
    Where-Object { $_.RecordCount -gt 0 -and $_.IsEnabled } |
    ForEach-Object {
        $safeName = ($_.LogName -replace '[\\\/\:\*\?\"\<\>\|]', '_')
        $path = Join-Path $dest "$safeName.evtx"
        try {
            wevtutil epl "$($_.LogName)" "$path"
            Write-Host "Экспортирован: $($_.LogName)"
        }
        catch {
            Write-Warning "Ошибка при экспорте: $($_.LogName)"
        }
    }
