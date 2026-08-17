USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'IIS APPPOOL\ShopAppPool')
    CREATE LOGIN [IIS APPPOOL\ShopAppPool] FROM WINDOWS;
GO

USE ShopCRM;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'IIS APPPOOL\ShopAppPool')
    CREATE USER [IIS APPPOOL\ShopAppPool] FOR LOGIN [IIS APPPOOL\ShopAppPool];
GO
ALTER ROLE db_datareader ADD MEMBER [IIS APPPOOL\ShopAppPool];
ALTER ROLE db_datawriter ADD MEMBER [IIS APPPOOL\ShopAppPool];
GO
