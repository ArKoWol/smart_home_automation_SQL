# Smart Home Automation SQL Database

Проект курсовой работы по разработке базы данных для системы автоматизации умного дома.

## Архитектура базы данных

База данных состоит из 8 таблиц в 3NF:

1. **Users** - пользователи системы
2. **Rooms** - комнаты в доме
3. **DeviceTypes** - типы устройств
4. **Devices** - устройства умного дома
5. **DeviceStatus** - статусы устройств (история)
6. **Scenes** - сценарии автоматизации
7. **SceneDevices** - связь сценариев с устройствами
8. **Events** - события в системе

## Быстрый запуск

### Предварительные требования

- Docker
- Docker Compose

### Установка и запуск

1. Клонируйте репозиторий:
```bash
git clone git@github.com:ArKoWol/smart_home_automation_SQL.git
cd smart_home_automation_SQL
```

2. Запустите контейнеры:
```bash
docker-compose up -d
```

3. Дождитесь инициализации базы данных (около 30 секунд)

### Доступ к базе данных

- **PostgreSQL**: localhost:5433
  - База данных: `smart_home`
  - Пользователь: `admin`
  - Пароль: `admin123`

- **PgAdmin**: http://localhost:8080
  - Email: `admin@example.com`
  - Пароль: `admin123`

## Структура проекта

```
smart_home_automation_SQL/
├── docker-compose.yml          # Docker Compose конфигурация
├── init/                       # SQL скрипты для инициализации
│   ├── 01_create_tables.sql   # Создание таблиц
│   └── 02_load_data.sql       # Загрузка данных
├── data/                      # CSV файлы с данными
│   ├── users.csv
│   ├── rooms.csv
│   ├── device_types.csv
│   ├── devices.csv
│   ├── scenes.csv
│   └── scene_devices.csv
└── README.md
```

## Особенности реализации

### 1.1 OLTP решение
- ✅ Логическая схема (ER-диаграмма в Screenshot)
- ✅ SQL скрипты создания таблиц
- ✅ Соответствие 3NF
- ✅ 8 таблиц

### 1.2 Подготовка данных
- ✅ 6 CSV файлов с тестовыми данными
- ✅ Отсутствие суррогатных ключей в CSV

### 1.3 Скрипт загрузки данных
- ✅ SQL скрипт загрузки из CSV
- ✅ Rerunnable (повторно выполняемый)
- ✅ Предотвращение перезаписи существующих данных

## Команды управления

```bash
# Запуск
docker-compose up -d

# Остановка
docker-compose down

# Просмотр логов
docker-compose logs

# Подключение к PostgreSQL
docker exec -it smart_home_db psql -U admin -d smart_home

# Перезагрузка данных
docker-compose down -v && docker-compose up -d
```

## Примеры запросов

```sql
-- Получить все устройства пользователя
SELECT d.DeviceName, r.RoomName, dt.TypeName 
FROM Devices d
JOIN Rooms r ON d.RoomID = r.RoomID
JOIN DeviceTypes dt ON d.DeviceTypeID = dt.DeviceTypeID
WHERE r.UserID = 1;

-- Получить устройства в сценарии
SELECT s.SceneName, d.DeviceName, sd.DesiredStatus
FROM Scenes s
JOIN SceneDevices sd ON s.SceneID = sd.SceneID
JOIN Devices d ON sd.DeviceID = d.DeviceID
WHERE s.SceneID = 1;
```