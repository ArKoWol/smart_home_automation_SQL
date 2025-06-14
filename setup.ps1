# PowerShell версия setup.sh
# Запуск Smart Home System

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Smart Home System..." -ForegroundColor Green

# Проверка наличия Docker
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker не установлен. Установите Docker Desktop." -ForegroundColor Red
    exit 1
}

# Проверка наличия Docker Compose
if (!(Get-Command docker-compose -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Compose не установлен. Установите Docker Compose." -ForegroundColor Red
    exit 1
}

# Остановка и удаление существующих контейнеров
Write-Host "Stopping existing containers..." -ForegroundColor Yellow
try {
    docker-compose down -v --remove-orphans 2>$null
} catch {
    # Игнорируем ошибки если контейнеры не запущены
}

# Запуск контейнеров
Write-Host "Starting containers..." -ForegroundColor Yellow
docker-compose up -d

Write-Host "Waiting for databases..." -ForegroundColor Yellow
Start-Sleep -Seconds 45

# Проверка готовности OLTP
Write-Host "Checking OLTP database..." -ForegroundColor Yellow
$oltpReady = $false
for ($i = 1; $i -le 15; $i++) {
    try {
        $null = docker exec smart_home_shop_oltp psql -U postgres -d smart_home_shop_oltp -c "SELECT 1;" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OLTP ready" -ForegroundColor Green
            $oltpReady = $true
            break
        }
    } catch {
        # Продолжаем попытки
    }
    Write-Host "Waiting for OLTP... ($i/15)" -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

if (-not $oltpReady) {
    Write-Host "OLTP database failed to start" -ForegroundColor Red
    exit 1
}

# Проверка готовности OLAP
Write-Host "Checking OLAP database..." -ForegroundColor Yellow
$olapReady = $false
for ($i = 1; $i -le 15; $i++) {
    try {
        $null = docker exec smart_home_shop_olap psql -U postgres -d smart_home_shop_olap -c "SELECT 1;" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OLAP ready" -ForegroundColor Green
            $olapReady = $true
            break
        }
    } catch {
        # Продолжаем попытки
    }
    Write-Host "Waiting for OLAP... ($i/15)" -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

if (-not $olapReady) {
    Write-Host "OLAP database failed to start" -ForegroundColor Red
    exit 1
}

# Настройка соединения между базами
Write-Host "Setting up connections..." -ForegroundColor Yellow
try {
    docker exec smart_home_shop_olap psql -U postgres -d smart_home_shop_olap -c "CREATE EXTENSION IF NOT EXISTS postgres_fdw;" 2>$null
} catch {
    # Игнорируем ошибки если расширение уже существует
}

$connectionScript = @"
DO `$`$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname = 'oltp_server') THEN
        CREATE SERVER oltp_server FOREIGN DATA WRAPPER postgres_fdw
        OPTIONS (host 'smart_home_shop_oltp', port '5432', dbname 'smart_home_shop_oltp');
        CREATE USER MAPPING FOR postgres SERVER oltp_server
        OPTIONS (user 'postgres', password 'postgres');
    END IF;
END `$`$;
"@

try {
    docker exec smart_home_shop_olap psql -U postgres -d smart_home_shop_olap -c $connectionScript 2>$null
} catch {
    # Игнорируем ошибки если соединение уже настроено
}

# Проверка данных
Write-Host "Checking data..." -ForegroundColor Yellow
try {
    $usersCount = docker exec smart_home_shop_oltp psql -U postgres -d smart_home_shop_oltp -t -c "SELECT COUNT(*) FROM users;" 2>$null
    $usersCount = $usersCount.Trim()
    if ([string]::IsNullOrEmpty($usersCount)) { $usersCount = "0" }
} catch {
    $usersCount = "0"
}

try {
    $salesCount = docker exec smart_home_shop_olap psql -U postgres -d smart_home_shop_olap -t -c "SELECT COUNT(*) FROM fact_sales;" 2>$null
    $salesCount = $salesCount.Trim()
    if ([string]::IsNullOrEmpty($salesCount)) { $salesCount = "0" }
} catch {
    $salesCount = "0"
}

Write-Host ""
Write-Host "System started successfully!" -ForegroundColor Green
Write-Host "Data: $usersCount users, $salesCount sales" -ForegroundColor Cyan
Write-Host "OLTP: localhost:5434 | OLAP: localhost:5433" -ForegroundColor Cyan
Write-Host "User: postgres | Pass: postgres" -ForegroundColor Cyan
Write-Host ""
Write-Host "For stopping the system use: docker-compose down" -ForegroundColor Yellow 