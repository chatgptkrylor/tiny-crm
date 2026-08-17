-- Tiny CRM — Schema + Seed Data
-- Database: ShopCRM on .\SQLEXPRESS
-- Run once via: sqlcmd -S .\SQLEXPRESS -E -i schema.sql

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'ShopCRM')
BEGIN
    CREATE DATABASE ShopCRM;
END
GO

USE ShopCRM;
GO

-- Drop existing tables if re-running (idempotent)
IF OBJECT_ID(N'dbo.Interactions', N'U') IS NOT NULL DROP TABLE dbo.Interactions;
IF OBJECT_ID(N'dbo.Customers', N'U') IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID(N'dbo.Users', N'U') IS NOT NULL DROP TABLE dbo.Users;
GO

-- Users table
CREATE TABLE dbo.Users (
    Id           INT IDENTITY(1,1) PRIMARY KEY,
    Username     NVARCHAR(50)  NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    Role         NVARCHAR(20)  NOT NULL DEFAULT 'User',
    CreatedAt    DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Customers table
CREATE TABLE dbo.Customers (
    Id             INT IDENTITY(1,1) PRIMARY KEY,
    Name           NVARCHAR(100) NOT NULL,
    Email          NVARCHAR(100) NULL,
    Phone          NVARCHAR(30)  NULL,
    Company        NVARCHAR(100) NULL,
    Status         NVARCHAR(20)  NOT NULL CHECK (Status IN ('Lead','Contact','Customer')),
    CreatedAt      DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt      DATETIME2     NULL,
    CreatedByUserId INT          NOT NULL,
    CONSTRAINT FK_Customers_Users FOREIGN KEY (CreatedByUserId) REFERENCES dbo.Users(Id)
);
GO

-- Interactions table
CREATE TABLE dbo.Interactions (
    Id            INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId    INT NOT NULL,
    Type          NVARCHAR(20)  NOT NULL CHECK (Type IN ('Call','Email','Meeting','Note')),
    Note          NVARCHAR(MAX) NOT NULL,
    LoggedAt      DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    LoggedByUserId INT          NOT NULL,
    CONSTRAINT FK_Interactions_Customers FOREIGN KEY (CustomerId) REFERENCES dbo.Customers(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Interactions_Users FOREIGN KEY (LoggedByUserId) REFERENCES dbo.Users(Id)
);
GO

-- Seed: Admin user
-- BCrypt hash of 'Admin@123' (cost factor 11)
INSERT INTO dbo.Users (Username, PasswordHash, Role)
VALUES ('admin', '$2b$11$YqX3XsU3KPpPpTb5tWc8Hep9qDDnf0sEKMf/8GhaaYZ/IDqUGAjG.', 'Admin');
GO

-- Seed: 10 customers
INSERT INTO dbo.Customers (Name, Email, Phone, Company, Status, CreatedByUserId) VALUES
('John Smith',     'john.smith@example.com',     '555-0101', 'Acme Corp',        'Lead',     1),
('Sarah Johnson',  'sarah.j@example.com',        '555-0102', 'TechStart LLC',    'Contact',  1),
('Mike Davis',     'mike.davis@example.com',     '555-0103', 'BlueWave Inc',     'Customer', 1),
('Emily Brown',    'emily.brown@example.com',    '555-0104', 'GreenLeaf Co',     'Lead',     1),
('David Wilson',   'david.wilson@example.com',   '555-0105', 'RedRock Systems',  'Customer', 1),
('Lisa Anderson',  'lisa.a@example.com',         '555-0106', 'NovaDigital',      'Contact',  1),
('Robert Taylor',  'robert.t@example.com',       '555-0107', 'Summit Partners',  'Lead',     1),
('Jennifer White', 'j.white@example.com',       '555-0108', 'CrystalBay Ltd',   'Customer', 1),
('Chris Martinez', 'chris.m@example.com',        '555-0109', 'OrionTech',        'Contact',  1),
('Amanda Lee',     'amanda.lee@example.com',     '555-0110', 'Pinecrest Group',  'Lead',     1);
GO

-- Seed: 5 interactions
INSERT INTO dbo.Interactions (CustomerId, Type, Note, LoggedByUserId) VALUES
(1, 'Call',    'Initial outreach call. John is interested in our pricing tiers.', 1),
(3, 'Email',   'Sent product catalog and setup guide for their team.', 1),
(5, 'Meeting', 'On-site demo with David and his engineering team. Very positive.', 1),
(2, 'Note',    'Followed up on the proposal sent last week. Awaiting response.', 1),
(8, 'Call',    'Quarterly check-in. Jennifer is happy with the service.', 1);
GO