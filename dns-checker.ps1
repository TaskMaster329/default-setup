param(
    [string]$LogFile,          # путь к dns.txt
    [string[]]$Domains         # список доменов для поиска (например: anydesk, rustdesk)
)

Write-Host "=== DNS Analyzer started ==="
Write-Host "LogFile: $LogFile"
Write-Host "Domains to check: $($Domains -join ', ')"
Write-Host "================================="

# хэш-таблица для хранения статистики
$Stats = @{}

# читаем построчно
$lines = Get-Content $LogFile
$total = $lines.Count
$index = 0
$startTime = Get-Date

foreach ($line in $lines) {
    $index++

    # каждые 200 строк выводим прогресс
    if ($index % 200 -eq 0 -or $index -eq $total) {
        $percent = [math]::Round(($index / $total) * 100, 2)
        $elapsed = (Get-Date) - $startTime
        $rate = if ($index -gt 0) { $elapsed.TotalSeconds / $index } else { 0 }
        $remaining = [math]::Round(($total - $index) * $rate, 1)
        Write-Host "[DEBUG] Processed $index / $total lines ($percent%) | Elapsed: $([math]::Round($elapsed.TotalSeconds,1))s | ETA: ~${remaining}s"
    }

    foreach ($domain in $Domains) {
        # ищем IP
        if ($line -match "UDP\s+Rcv\s+([0-9\.]+)") {
            $ip = $matches[1]

            # вытаскиваем домен в формате (4)boot(3)net(7)anydesk(3)com(0)
            if ($line -match "\)\s*([A-Za-z0-9\(\)]+)$") {
                $rawDomain = $matches[1]

                # преобразуем формат (3)com(0) -> com
                $fullDomain = ($rawDomain -replace '\(\d+\)', '.').Trim('.')

            }

            # проверяем, что полный домен содержит нужный паттерн
            if ($fullDomain -match $domain) {
                if (-not $Stats.ContainsKey($ip)) {
                    $Stats[$ip] = @{}
                }
                if (-not $Stats[$ip].ContainsKey($fullDomain)) {
                    $Stats[$ip][$fullDomain] = 0
                }
                $Stats[$ip][$fullDomain]++
            }
        }
    }
}

Write-Host "================================="
Write-Host "=== Final Results ==="
foreach ($ip in $Stats.Keys) {
    foreach ($fullDomain in $Stats[$ip].Keys) {
        $count = $Stats[$ip][$fullDomain]
        Write-Output "$ip : $fullDomain : $count"
    }
}
Write-Host "================================="
Write-Host "Done."
