
drop database if exists [MiniJIRA]
go

create database [MiniJIRA]
go

use [MiniJIRA]
go


drop schema if exists [hist]
go
create schema [hist]
go

drop schema if exists [arch]
go
create schema [arch]
go



-- TasksStatus - S³ownik Statusów
drop table if exists [dbo].[TasksStatus]
go

create table [dbo].[TasksStatus] (
	statusID INT PRIMARY KEY,
	statusName VARCHAR(64) NOT NULL,
	statusDescription VARCHAR(256) NOT NULL,

	CONSTRAINT NC_StatusName_idx UNIQUE NONCLUSTERED (statusName)
)
go

INSERT INTO [dbo].[TasksStatus] VALUES(1, 'NewTask', 'Nowe zadanie')

-- TasksOperations - S³ownik Operacji
drop table if exists [dbo].[TasksOperations]
go

create table [dbo].[TasksOperations] (
	operationID INT PRIMARY KEY,
	operationName VARCHAR(64) NOT NULL,
	operationDescription VARCHAR(256) NOT NULL,
	
	CONSTRAINT NC_operationName_idx UNIQUE NONCLUSTERED (operationName)
)
go

INSERT INTO [dbo].[TasksOperations] VALUES(1, 'AddNewTask', 'Dodanie nowego zadania')

-- Tasks - Zadania
drop table if exists [dbo].[Tasks]
go

create table [dbo].[Tasks] (
	taskID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(), 
	taskCategory VARCHAR(5) NOT NULL, 
	taskNumber INT NOT NULL, 
	taskSubject VARCHAR(100) NOT NULL,
	taskDescription VARCHAR(300),
	taskStatus INT NOT NULL FOREIGN KEY REFERENCES [dbo].[TasksStatus](statusID), 
	createdDate DATETIME, 
	createdBy VARCHAR(128), 
	modifiedDate DATETIME, 
	modifiedBy VARCHAR(128),

	CONSTRAINT PK_TaskID_Idx PRIMARY KEY CLUSTERED (taskID), 
	CONSTRAINT NC_taskCategoryNumber_Idx UNIQUE NONCLUSTERED (taskCategory, taskNumber),
	INDEX NC_taskCategory_idx NONCLUSTERED (taskCategory),
)
go

-- TasksArchive - Zadania zamkniête
drop table if exists [arch].[TasksArchive]
go

create table [arch].[TasksArchive] (
	taskID UNIQUEIDENTIFIER NOT NULL, 
	taskCategory VARCHAR(5) NOT NULL, 
	taskNumber INT NOT NULL, 
	taskSubject VARCHAR(100) NOT NULL,
	taskDescription VARCHAR(300),
	createdDate DATETIME, 
	createdBy VARCHAR(128), 
	modifiedDate DATETIME, 
	modifiedBy VARCHAR(128),

	CONSTRAINT PK_TaskArchID_Idx PRIMARY KEY CLUSTERED (taskID), 
	CONSTRAINT NC_taskCategoryNumber_Idx UNIQUE NONCLUSTERED (taskCategory, taskNumber),
	INDEX NC_taskCategory_idx NONCLUSTERED (taskCategory)
)
go


-- TasksStatusHistory - Historia zmian statusów zadañ
drop table if exists [dbo].[TasksStatusHistory]
go

create table [dbo].[TasksStatusHistory] (
	taskID UNIQUEIDENTIFIER PRIMARY KEY,
	operationID INT NOT NULL,
	createdDate DATETIME, 
	createdBy VARCHAR(128), 

	FOREIGN KEY(operationID) REFERENCES [dbo].[TasksOperations](operationID),
	FOREIGN KEY(taskID) REFERENCES [dbo].[Tasks](taskID)
)
go

create trigger [TasksStatusHistory_tgr] ON [dbo].[TasksStatusHistory] INSTEAD OF INSERT AS
	DECLARE @tUser VARCHAR(128)
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions WHERE session_id = @@SPID

	BEGIN
		INSERT INTO [dbo].[TasksStatusHistory] (taskID, operationID, CreatedDate, CreatedBy)
		SELECT I.taskID, operationID, GETDATE(), @tUser FROM inserted I
	END
GO

create trigger [TaskInsert_tgr] ON [dbo].[Tasks] INSTEAD OF INSERT AS
	DECLARE @tUser VARCHAR(128)
	DECLARE @tTaskNumber INT = 0
	DECLARE @taskID UNIQUEIDENTIFIER = NEWID()
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions WHERE session_id = @@SPID
	SELECT  @tTaskNumber = MAX(A.taskNumber) + 1 FROM 
		(SELECT taskNumber FROM [dbo].[Tasks] WHERE taskCategory IN(SELECT UPPER(I.taskCategory) FROM inserted I) UNION 
	     SELECT taskNumber FROM [arch].[TasksArchive] WHERE taskCategory IN(SELECT UPPER(I.taskCategory) FROM inserted I)) A

	BEGIN
		INSERT INTO [dbo].[Tasks] (
			taskID, taskCategory, taskNumber, taskSubject, taskDescription,
			taskStatus, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy )

		SELECT UPPER(@taskID), UPPER(I.taskCategory), IIF(@tTaskNumber>0, @tTaskNumber, 1), I.taskSubject, I.taskDescription, (SELECT statusID FROM [dbo].[TasksStatus] WHERE statusName = 'NewTask'),
			   GETDATE(), @tUser, NULL, NULL FROM inserted I

		INSERT INTO [dbo].[TasksStatusHistory] (taskID, operationID) VALUES(@taskID, (SELECT operationID FROM [dbo].[TasksOperations] WHERE operationName = 'AddNewTask'))
	END
GO

-- Comments - Komentarze do zadañ
drop table if exists [dbo].[Comments]
go

create table [dbo].[Comments] (
	commentID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(), 
	taskID UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES [dbo].[Tasks](taskID), 
	orginalCommentID UNIQUEIDENTIFIER FOREIGN KEY REFERENCES [dbo].[Comments](commentID), 
	comment VARCHAR(1024) NOT NULL,
	userID UNIQUEIDENTIFIER NOT NULL, 
	createdDate DATETIME, 
	createdBy VARCHAR(128), 

	CONSTRAINT NC_Comment_Idx PRIMARY KEY CLUSTERED (commentID),
	INDEX NC_commentHistory_idx NONCLUSTERED (orginalCommentID),
	INDEX NC_CommentTaskID_Idx NONCLUSTERED (taskID),
	
	--FOREIGN KEY(userID) REFERENCES [SECURITY].[dbo].[Users](userID)
)
go

-- CommentsArchive - Komentarze do zadañ zamkniêtych
drop table if exists [arch].[CommentsArchive]
go

create table [arch].[CommentsArchive] (
	commentID UNIQUEIDENTIFIER NOT NULL, 
	taskID UNIQUEIDENTIFIER NOT NULL, 
	orginalCommentID UNIQUEIDENTIFIER, 
	userID UNIQUEIDENTIFIER NOT NULL, 
	createdDate DATETIME, 
	createdBy VARCHAR(128), 

	CONSTRAINT NC_Comment_Idx PRIMARY KEY CLUSTERED (commentID),
	INDEX NC_commentHistory_idx NONCLUSTERED (orginalCommentID),
	INDEX NC_CommentTaskID_Idx NONCLUSTERED (taskID),
)
go

create trigger [CommentInsert_tgr] ON [dbo].[Comments] INSTEAD OF INSERT AS
	DECLARE @tUser VARCHAR(128)
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions WHERE session_id = @@SPID

	BEGIN
		INSERT INTO [dbo].[Comments] (commentID, taskID, comment, orginalCommentID, userID, CreatedDate, CreatedBy)
		SELECT UPPER(NEWID()), UPPER(I.taskID), comment, UPPER(I.orginalCommentID), UPPER(I.userID), GETDATE(), @tUser FROM inserted I
	END
GO


-- TasksRelations - Relacje miedzy zadaniami
drop table if exists [dbo].[TasksRelations]
go

create table [dbo].[TasksRelations] (
	parentTaskID UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES [dbo].[Tasks](taskID), 
	childTaskID UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES [dbo].[Tasks](taskID), 
	createdDate DATETIME, 
	createdBy VARCHAR(128), 

	CONSTRAINT UX_uniqueRow_idx UNIQUE (parentTaskID, childTaskID),
	INDEX NC_parentTask_idx NONCLUSTERED (parentTaskID),
	INDEX NC_childTask_idx NONCLUSTERED (childTaskID),
)
go

-- TasksRelationArchive - Relacje miêdzy zadaniami zamkniêtymi
drop table if exists [arch].[TasksRelationArchive]
go

create table [arch].[TasksRelationArchive] (
	parentTaskID UNIQUEIDENTIFIER NOT NULL, 
	childTaskID UNIQUEIDENTIFIER NOT NULL, 
	deletedDate DATETIME, 
	deletedBy VARCHAR(128), 

	INDEX NC_parentTask_idx NONCLUSTERED (parentTaskID),
	INDEX NC_childTask_idx NONCLUSTERED (childTaskID),
)
go

-- TasksRelationsHistory - Historia zmian relacji miêdzy zadaniami
drop table if exists [hist].[TasksRelationsHistory]
go

create table [hist].[TasksRelationsHistory] (
	parentTaskID UNIQUEIDENTIFIER NOT NULL, 
	childTaskID UNIQUEIDENTIFIER NOT NULL, 
	deletedDate DATETIME, 
	deletedBy VARCHAR(128), 

	INDEX NC_parentTask_idx NONCLUSTERED (parentTaskID),
	INDEX NC_childTask_idx NONCLUSTERED (childTaskID),
)
go

create trigger [RelationInsert_tgr] ON [dbo].[TasksRelations] INSTEAD OF INSERT AS
	DECLARE @tUser VARCHAR(128)
    SELECT  @tUser = login_name FROM sys.dm_exec_sessions WHERE session_id = @@SPID

	BEGIN
		INSERT INTO [dbo].[TasksRelations] (parentTaskID, childTaskID, CreatedDate, CreatedBy)
		SELECT UPPER(I.parentTaskID), UPPER(I.childTaskID), GETDATE(), @tUser FROM inserted I
	END
GO

-- TasksFiles - Za³¹czniki do zadañ
-- TasksFilesArchive - Za³¹czniki do zadañ zamknietych


-- Testy
INSERT INTO [dbo].[Tasks] (taskCategory, taskSubject, taskDescription) VALUES ('mj', 'Utworzenie mechanizmu pobierania danych', 'Nale¿y utworzyæ mechanizm')
INSERT INTO [dbo].[Tasks] (taskCategory, taskSubject, taskDescription) VALUES ('mj', 'Utworzenie mechanizmu pobierania danych 2', 'Nale¿y utworzyæ mechanizm 2')
INSERT INTO [dbo].[Comments] (taskID, comment, userID)                   VALUES ((SELECT TOP 1 taskID FROM [dbo].[Tasks]), 'Nowy komentarz',    (SELECT TOP 1 userID FROM [Security].[dbo].Users))
INSERT INTO [dbo].[Comments] (taskID, comment, orginalCommentID, userID) VALUES ((SELECT TOP 1 taskID FROM [dbo].[Tasks]), 'Zmiana komentarza', (SELECT TOP 1 commentID FROM [dbo].[Comments]), (SELECT TOP 1 userID FROM [Security].[dbo].Users))
INSERT INTO [dbo].[TasksRelations] (parentTaskID, childTaskID) VALUES ((SELECT TOP 1 taskID FROM [dbo].[Tasks] ORDER BY createdDate), (SELECT TOP 1 taskID FROM [dbo].[Tasks] ORDER BY createdDate DESC))

SELECT * FROM [dbo].Tasks
SELECT * FROM [dbo].Comments
SELECT * FROM [dbo].TasksRelations
SELECT * FROM [dbo].TasksOperations
SELECT * FROM [dbo].TasksStatus
SELECT * FROM [dbo].TasksStatusHistory

use master