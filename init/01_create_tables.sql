CREATE TABLE Users (
    UserID INT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Password VARCHAR(255) NOT NULL
);

CREATE TABLE Rooms (
    RoomID INT PRIMARY KEY,
    UserID INT NOT NULL,
    RoomName VARCHAR(100) NOT NULL,
    FOREIGN KEY (UserID) REFERENCES Users(UserID)
);

CREATE TABLE DeviceTypes (
    DeviceTypeID INT PRIMARY KEY,
    TypeName VARCHAR(100) NOT NULL,
    Description TEXT
);

CREATE TABLE Devices (
    DeviceID INT PRIMARY KEY,
    RoomID INT NOT NULL,
    DeviceTypeID INT NOT NULL,
    DeviceName VARCHAR(100) NOT NULL,
    Manufacturer VARCHAR(100),
    FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID),
    FOREIGN KEY (DeviceTypeID) REFERENCES DeviceTypes(DeviceTypeID)
);

CREATE TABLE DeviceStatus (
    StatusID SERIAL PRIMARY KEY,
    DeviceID INT NOT NULL,
    StatusTimestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    StatusValue VARCHAR(100) NOT NULL,
    FOREIGN KEY (DeviceID) REFERENCES Devices(DeviceID)
);

CREATE TABLE Scenes (
    SceneID INT PRIMARY KEY,
    UserID INT NOT NULL,
    SceneName VARCHAR(100) NOT NULL,
    Description TEXT,
    FOREIGN KEY (UserID) REFERENCES Users(UserID)
);

CREATE TABLE SceneDevices (
    SceneID INT NOT NULL,
    DeviceID INT NOT NULL,
    DesiredStatus VARCHAR(100) NOT NULL,
    PRIMARY KEY (SceneID, DeviceID),
    FOREIGN KEY (SceneID) REFERENCES Scenes(SceneID),
    FOREIGN KEY (DeviceID) REFERENCES Devices(DeviceID)
);

CREATE TABLE Events (
    EventID SERIAL PRIMARY KEY,
    UserID INT NOT NULL,
    DeviceID INT,
    SceneID INT,
    EventTimestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    EventDescription TEXT NOT NULL,
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    FOREIGN KEY (DeviceID) REFERENCES Devices(DeviceID),
    FOREIGN KEY (SceneID) REFERENCES Scenes(SceneID)
);
