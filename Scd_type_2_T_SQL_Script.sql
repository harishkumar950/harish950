-- Source table (new incoming data)
if exists (select 1 from sys.objects where name like '%customer_source%' )
drop table customer_source
CREATE TABLE Customer_Source (
    CustomerID INT,
    CustomerName VARCHAR(100),
    Email VARCHAR(100),
    Address VARCHAR(200)
);

-- Target table (SCD Type 2 dimension table)
if exists (select 1 from sys.objects where name like '%Customer_Dim%' )
drop table Customer_Dim
CREATE TABLE Customer_Dim (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate key
    CustomerID INT,                            -- Business key
    CustomerName VARCHAR(100),
    Email VARCHAR(100),
    Address VARCHAR(200),
    StartDate DATE,                           -- Validity start date
    EndDate DATE,                             -- Validity end date (NULL for current)
    IsCurrent BIT                             -- Flag for current record (1 = current, 0 = historical)
);

-- Insert sample data into the source table
INSERT INTO Customer_Source (CustomerID, CustomerName, Email, Address)
VALUES 
    (1, 'John Doe', 'john.doe@email.com', '123 Elm St'),
    (2, 'Jane Smith', 'jane.smith@email.com', '456 Oak Ave');


INSERT INTO Customer_Dim (CustomerID, CustomerName, Email, Address, StartDate, EndDate, IsCurrent)
SELECT 
    CustomerID,
    CustomerName,
    Email,
    Address,
    GETDATE(),         -- Start date is today
    NULL,              -- End date is NULL for current records
    1                  -- Mark as current
FROM Customer_Source;



BEGIN TRANSACTION;

-- Step 1: Update existing records to expire them where changes are detected
UPDATE cd
SET 
    EndDate = GETDATE(),
    IsCurrent = 0
FROM Customer_Dim cd
INNER JOIN Customer_Source cs
    ON cd.CustomerID = cs.CustomerID
WHERE cd.IsCurrent = 1
    AND (cd.CustomerName != cs.CustomerName 
         OR cd.Email != cs.Email 
         OR cd.Address != cs.Address);

-- Step 2: Insert new or changed records
INSERT INTO Customer_Dim (CustomerID, CustomerName, Email, Address, StartDate, EndDate, IsCurrent)
SELECT 
    cs.CustomerID,
    cs.CustomerName,
    cs.Email,
    cs.Address,
    GETDATE(),        -- New start date
    NULL,             -- End date is NULL for current
    1                 -- Mark as current
FROM Customer_Source cs
LEFT JOIN Customer_Dim cd
    ON cs.CustomerID = cd.CustomerID 
    AND cd.IsCurrent = 1
WHERE cd.CustomerID IS NULL -- New records
    OR EXISTS (
        SELECT 1
        FROM Customer_Dim cd2
        WHERE cd2.CustomerID = cs.CustomerID
        AND cd2.IsCurrent = 1
        AND (cd2.CustomerName != cs.CustomerName 
             OR cd2.Email != cs.Email 
             OR cd2.Address != cs.Address)
    );

COMMIT TRANSACTION;


select * from Customer_Source
select * from Customer_Dim

update Customer_Source set customerName ='Harish' where customerid=1