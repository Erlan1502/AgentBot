# 1. PROVERKA FAILOV
Write-Host "--- Checking Environment ---" -ForegroundColor Cyan
$requiredFiles = ".env", "workflows/my_bot.json", "workflows/creds.json"
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Error "Fail $file ne naiden! Script ostanovlen"
        exit
    }
}

# 2. AVTO-OCHISTKA (Auto-check)
Write-Host "Ostanovka predidushih obrazov (Stopping previous Images)" -ForegroundColor Yellow
docker-compose down --remove-orphans

# 3. ZAPUSK
Write-Host "Zapusk kontejnerov (Container Launch)..." -ForegroundColor Green
docker-compose up -d

# PROVERKA STATUSA (Docker PS)
Write-Host "--- Status kontejnerov ---" -ForegroundColor Cyan
docker ps

# Ozhidanie gotovnosti n8n
Write-Host "Ozhidaem gotovnosti n8n (15 sek)..." -ForegroundColor Gray
Start-Sleep -s 15

# 4. PODSTANOVKA KLYUCHEJ IZ .env V TEMP-FAIL
# Читаем файлы
$creds = Get-Content "workflows/creds.json" -Raw 
$envContent = Get-Content ".env" -Raw

# Извлекаем все ключи из .env
$tgToken = if ($envContent -match 'TELEGRAM_TOKEN=(.*)') { $matches[1].Trim() }
$groqKey = if ($envContent -match 'GROQ_API_KEY=(.*)') { $matches[1].Trim() }
$geminiKey = if ($envContent -match 'GEMINI_API_KEY=(.*)') { $matches[1].Trim() }

# Выполняем замену всех переменных
$creds = $creds.Replace('${TELEGRAM_TOKEN}', $tgToken)
$creds = $creds.Replace('${GROQ_API_KEY}', $groqKey)
$creds = $creds.Replace('${GEMINI_API_KEY}', $geminiKey)

# Сохраняем временный файл для импорта
$creds | Set-Content "workflows/creds_temp.json"
Write-Host "Ключи успешно подставлены в creds_temp.json" -ForegroundColor Green

# 5. IMPORT
Write-Host "--- Import dannih (Data Import) ---" -ForegroundColor Cyan
docker exec -it n8n_worker n8n import:credentials --input /backup/workflows/creds_temp.json
docker exec -it n8n_worker n8n import:workflow --input /backup/workflows/my_bot.json

Write-Host "Zagruzka modeli qwen2.5-vl:7b (Vision + Tools)..." -ForegroundColor Yellow
docker exec -it ollama ollama pull qwen2.5-vl:7b

# Udalyaem vremennij fail
if (Test-Path "workflows/creds_temp.json") { Remove-Item "workflows/creds_temp.json" }

Write-Host "--- ALL READY! Bot is online ---" -ForegroundColor Green