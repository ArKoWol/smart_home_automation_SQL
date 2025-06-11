CREATE DATABASE smart_home_olap;
\c smart_home_olap;

CREATE TABLE DIM_DATE (
    DateKey INTEGER PRIMARY KEY,
    Date DATE NOT NULL,
    Year INTEGER NOT NULL,
    Quarter INTEGER NOT NULL,
    Month INTEGER NOT NULL,
    MonthName VARCHAR(20) NOT NULL,
    Week INTEGER NOT NULL,
    Day INTEGER NOT NULL,
    DayName VARCHAR(20) NOT NULL,
    DayOfYear INTEGER NOT NULL,
    IsWeekend BOOLEAN NOT NULL
);

CREATE TABLE DIM_TIME (
    TimeKey INTEGER PRIMARY KEY,
    Hour INTEGER NOT NULL,
    Minute INTEGER NOT NULL,
    TimeOfDay VARCHAR(20) NOT NULL,
    IsBusinessHour BOOLEAN NOT NULL
);

CREATE TABLE DIM_MANUFACTURER (
    ManufacturerKey SERIAL PRIMARY KEY,
    ManufacturerName VARCHAR(100) NOT NULL,
    Country VARCHAR(50),
    Founded_Year INTEGER,
    ValidFrom TIMESTAMP NOT NULL,
    ValidTo TIMESTAMP NULL,
    IsCurrent BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE DIM_DEVICE_TYPE (
    DeviceTypeKey SERIAL PRIMARY KEY,
    TypeName VARCHAR(100) NOT NULL,
    Category VARCHAR(50) NOT NULL,
    Description TEXT,
    EnergyEfficiencyRating VARCHAR(10)
);

CREATE TABLE DIM_USER (
    UserKey SERIAL PRIMARY KEY,
    UserID INTEGER NOT NULL,
    Name VARCHAR(100) NOT NULL,
    Email VARCHAR(255) NOT NULL,
    RegistrationDate DATE,
    UserType VARCHAR(50) NOT NULL,
    City VARCHAR(100),
    Country VARCHAR(100),
    ValidFrom TIMESTAMP NOT NULL,
    ValidTo TIMESTAMP NULL,
    IsCurrent BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE DIM_ROOM (
    RoomKey SERIAL PRIMARY KEY,
    RoomID INTEGER NOT NULL,
    UserKey INTEGER NOT NULL,
    RoomName VARCHAR(100) NOT NULL,
    RoomType VARCHAR(50) NOT NULL,
    Area_SqM DECIMAL(6,2),
    Floor INTEGER,
    HasWindows BOOLEAN,
    FOREIGN KEY (UserKey) REFERENCES DIM_USER(UserKey)
);

CREATE TABLE DIM_DEVICE (
    DeviceKey SERIAL PRIMARY KEY,
    DeviceID INTEGER NOT NULL,
    RoomKey INTEGER NOT NULL,
    DeviceTypeKey INTEGER NOT NULL,
    ManufacturerKey INTEGER NOT NULL,
    DeviceName VARCHAR(255) NOT NULL,
    Model VARCHAR(100),
    InstallationDate DATE,
    WarrantyExpiry DATE,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active',
    FOREIGN KEY (RoomKey) REFERENCES DIM_ROOM(RoomKey),
    FOREIGN KEY (DeviceTypeKey) REFERENCES DIM_DEVICE_TYPE(DeviceTypeKey),
    FOREIGN KEY (ManufacturerKey) REFERENCES DIM_MANUFACTURER(ManufacturerKey)
);

CREATE TABLE DIM_SCENE (
    SceneKey SERIAL PRIMARY KEY,
    SceneID INTEGER NOT NULL,
    UserKey INTEGER NOT NULL,
    SceneName VARCHAR(100) NOT NULL,
    Category VARCHAR(50) NOT NULL,
    Description TEXT,
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    FOREIGN KEY (UserKey) REFERENCES DIM_USER(UserKey)
);

CREATE TABLE BRIDGE_SCENE_DEVICE (
    BridgeKey SERIAL PRIMARY KEY,
    SceneKey INTEGER NOT NULL,
    DeviceKey INTEGER NOT NULL,
    DeviceGroupKey INTEGER NOT NULL,
    DesiredStatus VARCHAR(100) NOT NULL,
    Priority INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (SceneKey) REFERENCES DIM_SCENE(SceneKey),
    FOREIGN KEY (DeviceKey) REFERENCES DIM_DEVICE(DeviceKey)
);

CREATE TABLE FACT_DEVICE_USAGE (
    UsageKey SERIAL PRIMARY KEY,
    DateKey INTEGER NOT NULL,
    DeviceKey INTEGER NOT NULL,
    UserKey INTEGER NOT NULL,
    RoomKey INTEGER NOT NULL,
    TotalActivations INTEGER NOT NULL DEFAULT 0,
    TotalUsageMinutes INTEGER NOT NULL DEFAULT 0,
    EnergyConsumption_kWh DECIMAL(8,3) NOT NULL DEFAULT 0,
    AvgResponseTime_ms INTEGER NOT NULL DEFAULT 0,
    ErrorCount INTEGER NOT NULL DEFAULT 0,
    UsageScore DECIMAL(5,2) GENERATED ALWAYS AS ((TotalActivations * 0.3) + (TotalUsageMinutes * 0.7)) STORED,
    FOREIGN KEY (DateKey) REFERENCES DIM_DATE(DateKey),
    FOREIGN KEY (DeviceKey) REFERENCES DIM_DEVICE(DeviceKey),
    FOREIGN KEY (UserKey) REFERENCES DIM_USER(UserKey),
    FOREIGN KEY (RoomKey) REFERENCES DIM_ROOM(RoomKey)
);

CREATE TABLE FACT_SCENE_EXECUTION (
    ExecutionKey SERIAL PRIMARY KEY,
    DateKey INTEGER NOT NULL,
    TimeKey INTEGER NOT NULL,
    SceneKey INTEGER NOT NULL,
    UserKey INTEGER NOT NULL,
    ExecutionCount INTEGER NOT NULL DEFAULT 0,
    SuccessfulExecutions INTEGER NOT NULL DEFAULT 0,
    FailedExecutions INTEGER NOT NULL DEFAULT 0,
    AvgExecutionTime_ms INTEGER NOT NULL DEFAULT 0,
    DevicesAffected INTEGER NOT NULL DEFAULT 0,
    SuccessRate DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE 
            WHEN ExecutionCount > 0 THEN (SuccessfulExecutions * 100.0 / ExecutionCount)
            ELSE 0 
        END
    ) STORED,
    FOREIGN KEY (DateKey) REFERENCES DIM_DATE(DateKey),
    FOREIGN KEY (TimeKey) REFERENCES DIM_TIME(TimeKey),
    FOREIGN KEY (SceneKey) REFERENCES DIM_SCENE(SceneKey),
    FOREIGN KEY (UserKey) REFERENCES DIM_USER(UserKey)
);

CREATE TABLE FACT_MONTHLY_SUMMARY (
    SummaryKey SERIAL PRIMARY KEY,
    Year INTEGER NOT NULL,
    Month INTEGER NOT NULL,
    UserKey INTEGER NOT NULL,
    TotalDeviceActivations INTEGER NOT NULL DEFAULT 0,
    TotalEnergyConsumption_kWh DECIMAL(10,3) NOT NULL DEFAULT 0,
    TotalSceneExecutions INTEGER NOT NULL DEFAULT 0,
    AvgDevicesPerScene DECIMAL(5,2) NOT NULL DEFAULT 0,
    MostUsedDeviceKey INTEGER,
    MostUsedSceneKey INTEGER,
    FOREIGN KEY (UserKey) REFERENCES DIM_USER(UserKey),
    FOREIGN KEY (MostUsedDeviceKey) REFERENCES DIM_DEVICE(DeviceKey),
    FOREIGN KEY (MostUsedSceneKey) REFERENCES DIM_SCENE(SceneKey)
);

CREATE INDEX idx_device_usage_date ON FACT_DEVICE_USAGE(DateKey);
CREATE INDEX idx_device_usage_device ON FACT_DEVICE_USAGE(DeviceKey);
CREATE INDEX idx_device_usage_user ON FACT_DEVICE_USAGE(UserKey);

CREATE INDEX idx_scene_execution_date ON FACT_SCENE_EXECUTION(DateKey);
CREATE INDEX idx_scene_execution_time ON FACT_SCENE_EXECUTION(TimeKey);
CREATE INDEX idx_scene_execution_scene ON FACT_SCENE_EXECUTION(SceneKey);

CREATE INDEX idx_bridge_scene ON BRIDGE_SCENE_DEVICE(SceneKey);
CREATE INDEX idx_bridge_device ON BRIDGE_SCENE_DEVICE(DeviceKey);

CREATE INDEX idx_user_current ON DIM_USER(UserID, IsCurrent);
CREATE INDEX idx_manufacturer_current ON DIM_MANUFACTURER(ManufacturerName, IsCurrent); 