
CREATE TEMP TABLE temp_users (
    UserID INT,
    Name VARCHAR(100),
    Email VARCHAR(100),
    Password VARCHAR(255)
);

\COPY temp_users FROM '/data/users.csv' WITH CSV HEADER DELIMITER ';';

INSERT INTO Users (UserID, Name, Email, Password)
SELECT UserID, Name, Email, Password FROM temp_users
ON CONFLICT (Email) DO NOTHING;

DROP TABLE temp_users;

CREATE TEMP TABLE temp_device_types (
    DeviceTypeID INT,
    TypeName VARCHAR(100),
    Description TEXT
);

\COPY temp_device_types FROM '/data/device_types.csv' WITH CSV HEADER DELIMITER ';';

INSERT INTO DeviceTypes (DeviceTypeID, TypeName, Description)
SELECT DeviceTypeID, TypeName, Description FROM temp_device_types
ON CONFLICT (DeviceTypeID) DO NOTHING;

DROP TABLE temp_device_types;

CREATE TEMP TABLE temp_rooms (
    RoomID INT,
    UserID INT,
    RoomName VARCHAR(100)
);

\COPY temp_rooms FROM '/data/rooms.csv' WITH CSV HEADER DELIMITER ';';

INSERT INTO Rooms (RoomID, UserID, RoomName)
SELECT RoomID, UserID, RoomName FROM temp_rooms
ON CONFLICT (RoomID) DO NOTHING;

DROP TABLE temp_rooms;

CREATE TEMP TABLE temp_devices (
    DeviceID INT,
    RoomID INT,
    DeviceTypeID INT,
    DeviceName VARCHAR(100),
    Manufacturer VARCHAR(100)
);

\COPY temp_devices FROM '/data/devices.csv' WITH CSV HEADER DELIMITER ';';

INSERT INTO Devices (DeviceID, RoomID, DeviceTypeID, DeviceName, Manufacturer)
SELECT DeviceID, RoomID, DeviceTypeID, DeviceName, Manufacturer FROM temp_devices
ON CONFLICT (DeviceID) DO NOTHING;

DROP TABLE temp_devices;

CREATE TEMP TABLE temp_scenes (
    SceneID INT,
    UserID INT,
    SceneName VARCHAR(100),
    Description TEXT
);

\COPY temp_scenes FROM '/data/scenes.csv' WITH CSV HEADER DELIMITER ';';

INSERT INTO Scenes (SceneID, UserID, SceneName, Description)
SELECT SceneID, UserID, SceneName, Description FROM temp_scenes
ON CONFLICT (SceneID) DO NOTHING;

DROP TABLE temp_scenes;

CREATE TEMP TABLE temp_scene_devices (
    SceneID INT,
    DeviceID INT,
    DesiredStatus VARCHAR(100)
);

\COPY temp_scene_devices FROM '/data/scene_devices.csv' WITH CSV HEADER DELIMITER ';';

INSERT INTO SceneDevices (SceneID, DeviceID, DesiredStatus)
SELECT SceneID, DeviceID, DesiredStatus FROM temp_scene_devices
ON CONFLICT (SceneID, DeviceID) DO NOTHING;

DROP TABLE temp_scene_devices; 