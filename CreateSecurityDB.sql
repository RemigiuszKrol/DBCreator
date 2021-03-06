drop database if exists [SECURITY]
go

create database [SECURITY]
go

use [SECURITY]
go


drop schema if exists [hist]
go
create schema [hist]
go



drop table if exists [dbo].[Users]
go

create table [dbo].[Users] (
	userID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(), 
	userFirstName VARCHAR(20) NOT NULL, 
	userLastName VARCHAR(40) NOT NULL,
	userLogin VARCHAR(10) UNIQUE NOT NULL, 
	userDescription VARCHAR(200),
	isActive BIT NOT NULL, 
	createdDate DATETIME, 
	createdBy VARCHAR(128), 
	modifiedDate DATETIME, 
	modifiedBy VARCHAR(128),

	CONSTRAINT PK_UserID_Idx PRIMARY KEY NONCLUSTERED (userID), 
	CONSTRAINT UserLogin_Idx UNIQUE CLUSTERED (userLogin)
)
go

drop table if exists [hist].[Users]
go

create table [hist].[Users] (
	userID UNIQUEIDENTIFIER NOT NULL, 
	userFirstName VARCHAR(20) NOT NULL, 
	userLastName VARCHAR(40) NOT NULL,
	userLogin VARCHAR(10) NOT NULL, 
	userDescription VARCHAR(200), 
	operation VARCHAR(6) NOT NULL, 
	createdDate DATETIME, 
	createdBy VARCHAR(128), 
	modifiedDate DATETIME, 
	modifiedBy VARCHAR(128),
	operatedDate DATETIME, 
	operatedBy VARCHAR(128), 

	CONSTRAINT PK_UserID_Idx PRIMARY KEY NONCLUSTERED (userID), 
	CONSTRAINT UserLogin_Idx UNIQUE CLUSTERED (userLogin)
)
go

create trigger [UserInsert_tgr] ON [dbo].[Users] INSTEAD OF INSERT AS
	DECLARE @tUser VARCHAR(128)
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions WHERE session_id = @@SPID

	BEGIN
		INSERT INTO [dbo].[Users] (
			UserID, UserFirstName, UserLastName, UserLogin, IsActive,
			UserDescription, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy )

		SELECT UPPER(NEWID()), I.UserFirstName, I.UserLastName, UPPER(I.UserLogin), I.IsActive, I.UserDescription,
			   GETDATE(), @tUser, NULL, NULL FROM inserted I
	END
GO

create trigger [UserDelete_tgr] ON [dbo].[Users] FOR DELETE AS
	DECLARE @tUser VARCHAR(128)
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions  WHERE session_id = @@SPID

	BEGIN
		INSERT INTO [hist].[Users] (
			I.UserID, UserFirstName, UserLastName, UserLogin, UserDescription, Operation,
			CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, OperatedDate, OperatedBy )

		SELECT UPPER(D.UserID), D.UserFirstName, D.UserLastName, UPPER(D.UserLogin), D.UserDescription, 'Delete',
			   D.CreatedDate, D.CreatedBy, D.ModifiedDate, D.ModifiedBy, GETDATE(), @tUser FROM Deleted D
	END
GO



drop table if exists [dbo].[Groups]
go

create table [dbo].[Groups] (
	groupID UNIQUEIDENTIFIER NOT NULL, 
	groupName VARCHAR(50) UNIQUE NOT NULL, 
	groupShortName VARCHAR(9) UNIQUE NOT NULL, 
	groupDescription VARCHAR(200),
	groupApplication VARCHAR(10) NOT NULL,
	isActive BIT NOT NULL, 
	createdDate DATETIME, 
	createdBy VARCHAR(128), 
	modifiedDate DATETIME, 
	modifiedBy VARCHAR(128),

	CONSTRAINT PK_GroupID_Idx PRIMARY KEY NONCLUSTERED (groupID), 
	CONSTRAINT GroupShortName_Idx UNIQUE CLUSTERED (groupShortName)
)
go

create trigger [GroupsInsert_tgr] ON [dbo].[Groups] INSTEAD OF INSERT AS
	DECLARE @tUser VARCHAR(128)
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions WHERE session_id = @@SPID

	BEGIN
		INSERT INTO [dbo].[Groups] (
			GroupID, GroupName, GroupShortName, IsActive, GroupDescription, groupApplication,
			CreatedDate, CreatedBy, ModifiedDate, ModifiedBy )

		SELECT UPPER(NEWID()), I.GroupName, UPPER(I.GroupShortName), I.IsActive, I.GroupDescription, I.groupApplication,
			   GETDATE(), @tUser, NULL, NULL FROM inserted I
	END
GO



drop table if exists [dbo].[Roles]
go

create table [dbo].[Roles] (
	roleID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(), 
	roleName VARCHAR(50) UNIQUE NOT NULL, 
	roleShortName VARCHAR(9) UNIQUE NOT NULL, 
	roleDescription VARCHAR(200),
	isActive BIT NOT NULL, 
	createdDate DATETIME, 
	createdBy VARCHAR(128), 
	modifiedDate DATETIME, 
	modifiedBy VARCHAR(128),

	CONSTRAINT PK_RoleID_Idx PRIMARY KEY NONCLUSTERED (roleID), 
	CONSTRAINT RoleShortName_Idx UNIQUE CLUSTERED (roleShortName)
)
go

create trigger [RolesInsert_tgr] ON [dbo].[Roles] INSTEAD OF INSERT AS
	DECLARE @tUser VARCHAR(128)
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions WHERE session_id = @@SPID

	BEGIN
		INSERT INTO [dbo].[Roles] (
			RoleID, RoleName, RoleShortName, IsActive, RoleDescription,
			CreatedDate, CreatedBy, ModifiedDate, ModifiedBy )

		SELECT UPPER(NEWID()), I.RoleName, UPPER(I.RoleShortName), I.IsActive, I.RoleDescription,
			   GETDATE(), @tUser, NULL, NULL FROM inserted I
	END
GO



drop table if exists [dbo].[Passwords]
go

create table [dbo].[Passwords] (
	passwordID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(), 
	userId UNIQUEIDENTIFIER, 
	hashPassword VARCHAR(512) NOT NULL, 
	startDate DATE NOT NULL,
	validity DECIMAL(3,0) NOT NULL, 
	expires BIT NOT NULL DEFAULT 0,
	createdDate DATETIME, 
	createdBy VARCHAR(128), 
	modifiedDate DATETIME, 
	modifiedBy VARCHAR(128),

	CONSTRAINT PK_PasswordID_Idx PRIMARY KEY NONCLUSTERED (passwordID), 
	CONSTRAINT UserId_Idx UNIQUE CLUSTERED (userId),

	FOREIGN KEY(UserId) REFERENCES [dbo].[Users](UserId)
)
go

create trigger [PasswordInsert_tgr] ON [dbo].[Passwords] INSTEAD OF INSERT AS
	DECLARE @tUser VARCHAR(128)
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions WHERE session_id = @@SPID

	BEGIN
		INSERT INTO [dbo].[Passwords] (
			passwordID, userId, hashPassword, startDate, validity, expires,
			CreatedDate, CreatedBy, ModifiedDate, ModifiedBy )

		SELECT UPPER(NEWID()), UPPER(I.userId), I.hashPassword, GETDATE(), 30, I.expires,
			   GETDATE(), @tUser, NULL, NULL FROM inserted I
	END
GO



create table [dbo].[UsersGroups] (
	userId UNIQUEIDENTIFIER NOT NULL INDEX NC_UserID_Idx NONCLUSTERED, 
	groupId UNIQUEIDENTIFIER NOT NULL INDEX NC_GroupID_Idx NONCLUSTERED, 
	startDate DATE NOT NULL DEFAULT GETDATE(),
	endDate DATE DEFAULT NULL,
	isActive BIT NOT NULL DEFAULT 1,
	createdDate DATETIME, 
	createdBy VARCHAR(128), 
	modifiedDate DATETIME, 
	modifiedBy VARCHAR(128),
	
	FOREIGN KEY(UserId) REFERENCES [dbo].[Users](UserId),
	FOREIGN KEY(groupId) REFERENCES [dbo].[Groups](groupId)
)
go

create trigger [UsersGroupInsert_tgr] ON [dbo].[UsersGroups] INSTEAD OF INSERT AS
	DECLARE @tUser VARCHAR(128)
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions WHERE session_id = @@SPID

	BEGIN
		INSERT INTO [dbo].[UsersGroups] (
			userId, groupId, startDate, endDate, isActive,
			CreatedDate, CreatedBy, ModifiedDate, ModifiedBy )

		SELECT UPPER(I.userId), UPPER(I.groupId), GETDATE(), I.endDate, I.isActive,
			   GETDATE(), @tUser, NULL, NULL FROM inserted I
	END
GO



create table [dbo].[GroupsRoles] (
	groupId UNIQUEIDENTIFIER NOT NULL INDEX NC_GroupID_Idx NONCLUSTERED, 
	roleId UNIQUEIDENTIFIER NOT NULL INDEX NC_RoleID_Idx NONCLUSTERED, 
	startDate DATE NOT NULL DEFAULT GETDATE(),
	endDate DATE DEFAULT NULL,
	isActive BIT NOT NULL DEFAULT 1,
	createdDate DATETIME, 
	createdBy VARCHAR(128), 
	modifiedDate DATETIME, 
	modifiedBy VARCHAR(128),
	
	FOREIGN KEY(groupId) REFERENCES [dbo].[Groups](groupId),
	FOREIGN KEY(roleId) REFERENCES [dbo].[Roles](roleId)
)
go

create trigger [GroupRolesInsert_tgr] ON [dbo].[GroupsRoles] INSTEAD OF INSERT AS
	DECLARE @tUser VARCHAR(128)
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions WHERE session_id = @@SPID

	BEGIN
		INSERT INTO [dbo].[GroupsRoles] (
			groupId, roleId, startDate, endDate, isActive,
			CreatedDate, CreatedBy, ModifiedDate, ModifiedBy )

		SELECT UPPER(I.groupId), UPPER(I.roleId), GETDATE(), I.endDate, I.isActive,
			   GETDATE(), @tUser, NULL, NULL FROM inserted I
	END
GO

-- Testy jednostkowe dla triggerów
INSERT INTO [dbo].[Users] (UserFirstName, UserLastName, UserLogin, IsActive, UserDescription) VALUES('Remigiusz', 'Król', 'REKROL', 1, 'W³aœciciel oprogramowaia');
DELETE FROM [dbo].[Users] WHERE userLogin = 'REKROL';
INSERT INTO [dbo].[Users] (UserFirstName, UserLastName, UserLogin, IsActive, UserDescription) VALUES('Remigiusz', 'Król', 'REKROL', 1, 'W³aœciciel oprogramowaia');
INSERT INTO [dbo].[Groups] (GroupName, GroupShortName, IsActive, GroupDescription, groupApplication) VALUES('Administrator', 'GRPSYSADM', 1, 'Gruba nadrzêdnych uprawnieñ administratorów', 'MiniJIRA');
INSERT INTO [dbo].[Roles] (RoleName, RoleShortName, IsActive, RoleDescription) VALUES('Administrator', 'ROLSYSADM', 1, 'Rola nadrzêdnych uprawnieñ administratorów');
INSERT INTO [dbo].[Passwords] (userId, hashPassword, expires) VALUES((SELECT userId FROM [dbo].[Users] WHERE userLogin = 'REKROL'), CONVERT(varchar(max), HASHBYTES ('SHA2_512', 'Has³o1234!') ,2), 0)
INSERT INTO [dbo].[UsersGroups] (userId, groupId) VALUES((SELECT UserId FROM [dbo].[Users] WHERE userLogin = 'REKROL'),(SELECT GroupId FROM [dbo].[Groups] WHERE GroupName = 'Administrator'));
INSERT INTO [dbo].[GroupsRoles] (groupId, roleId) VALUES((SELECT GroupId FROM [dbo].[Groups] WHERE GroupName = 'Administrator'),(SELECT RoleId FROM [dbo].[Roles] WHERE RoleName = 'Administrator'));


SELECT * FROM [dbo].[Users]
SELECT * FROM [hist].[Users]
SELECT * FROM [dbo].[Groups]
SELECT * FROM [dbo].[Roles]
SELECT * FROM [dbo].[Passwords]
SELECT * FROM [dbo].[UsersGroups]
SELECT * FROM [dbo].[GroupsRoles]

use master



