CREATE OR ALTER PROCEDURE AddSector
    @Name NVARCHAR(100),
    @Description NVARCHAR(500) = NULL,
    @Buff DECIMAL(5,2) = NULL
AS
BEGIN
    INSERT INTO Sectors (Name, Description, Buff)
    VALUES (@Name, @Description, @Buff);
END
GO
CREATE OR ALTER PROCEDURE GetAllSectors
AS
BEGIN
    SELECT * FROM Sectors;
END
GO
CREATE OR ALTER PROCEDURE GetSectorById
    @Id INT
AS
BEGIN
    SELECT Id, Name, Description, Buff
    FROM Sectors
    WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE UpdateSector
    @Id INT,
    @Name NVARCHAR(100),
    @Description NVARCHAR(500),
    @Buff DECIMAL(5,2)
AS
BEGIN
    UPDATE Sectors
    SET Name = @Name,
        Description = @Description,
        Buff = @Buff
    WHERE Id = @Id;
END
GO

CREATE PROCEDURE DeleteSector
    @Id INT
AS
BEGIN
    DELETE FROM Sectors WHERE Id = @Id;
END
GO
