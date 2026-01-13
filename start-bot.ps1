# 1. ПРОВЕРКА ФАЙЛОВ
Write-Host "--- Checking Enviroment ---" -ForegroundColor Cyan
$requiredFiles = ".env", "workflows/my_bot.json", "workflows/creds.json"
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Error "File $file is not found! Script stopped"
        exit
    }
}

# 2. АВТО-ОЧИСТКА (Auto-check)
Write-Host "Stopping previous Images" -ForegroundColor Yellow
# Останавливаем контейнеры этого проекта, если они запущены
docker-compose down --remove-orphans

# 3. ЗАПУСК
Write-Host "Container Launch..." -ForegroundColor Green
docker-compose up -d

# Ожидание готовности n8n (обычно хватает 10-15 секунд)
Write-Host "Ожидаем готовности n8n (15 сек)..." -ForegroundColor Gray
Start-Sleep -s 15

# 4. ПОДСТАНОВКА КЛЮЧЕЙ ИЗ .env В ТЕМП-ФАЙЛ
$creds = Get-Content "workflows/creds.json" -Raw 
# Загружаем переменную из .env (простой способ для PS)
$envContent = Get-Content ".env" -Raw
if ($envContent -match 'GEMINI_API_KEY=(.*)') {
    $apiKey = $matches[1].Trim()
    $creds = $creds.Replace('${GEMINI_API_KEY}', $apiKey)
    $creds | Set-Content "workflows/creds_temp.json"
}

# 5. ИМПОРТ
Write-Host "--- Data Import ---" -ForegroundColor Cyan
docker exec -it n8n_worker n8n import:credentials --input /backup/workflows/creds_temp.json
docker exec -it n8n_worker n8n import:workflow --input /backup/workflows/my_bot.json

# Удаляем временный файл с открытым ключом
if (Test-Path "workflows/creds_temp.json") { Remove-Item "workflows/creds_temp.json" }

Write-Host "--- ALL READY! Bot is online ---" -ForegroundColor Green