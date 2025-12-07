CREATE OR ALTER PROCEDURE AddCompany
    @Name NVARCHAR(100),
    @Description NVARCHAR(500) = NULL,
    @SectorId INT,
    @Buff FLOAT = NULL,
    @Evaluation FLOAT = NULL,
    @Dividends FLOAT = NULL,
    @Earnings FLOAT = NULL,
    @Spendings FLOAT = NULL
AS
BEGIN
    INSERT INTO Companies (Name, Description, SectorId, Buff, Evaluation, Dividens, Earnings, Spendings)
    VALUES (@Name, @Description, @SectorId, @Buff, @Evaluation, @Dividends, @Earnings, @Spendings);
END
GO
CREATE OR ALTER PROCEDURE GetCompanyById
    @Id INT
AS
BEGIN
    SELECT * FROM Companies WHERE Id = @Id;
END
GO
CREATE OR ALTER PROCEDURE GetAllCompanies
AS
BEGIN
    SELECT * FROM Companies;
END
GO
CREATE OR ALTER PROCEDURE UpdateCompany
    @Id INT,
    @Name NVARCHAR(100),
    @Description NVARCHAR(500),
    @SectorId INT,
    @Buff FLOAT,
    @Evaluation FLOAT,
    @Dividends FLOAT,
    @Earnings FLOAT,
    @Spendings FLOAT
AS
BEGIN
    UPDATE Companies
    SET Name = @Name,
        Description = @Description,
        SectorId = @SectorId,
        Buff = @Buff,
        Evaluation = @Evaluation,
        Dividens = @Dividends,
        Earnings = @Earnings,
        Spendings = @Spendings
    WHERE Id = @Id;
END
GO
CREATE OR ALTER PROCEDURE DeleteCompany
    @Id INT
AS
BEGIN
    DELETE FROM Companies WHERE Id = @Id;
END
GO