/* Find Duplicate records */
USE SQLPractice;


GO
/* 
-- Create a temporary sample from real AdventureWorks records.
-- The permanent AdventureWorks tables will not be modified.
*/
IF OBJECT_ID('SQLPractice.dev.PersonSample') IS NOT NULL
    DROP TABLE SQLPractice.dev.PersonSample;

SELECT   TOP (100) IDENTITY (INT, 1, 1) AS SampleRowID,
                   FirstName,
                   MiddleName,
                   LastName,
                   PersonType
INTO     dev.PersonSample
FROM     AdventureWorks2022.Person.Person
ORDER BY BusinessEntityID;

-- Intentionally insert duplicate copies of two sample records.
INSERT INTO dev.PersonSample (
    FirstName,
    MiddleName,
    LastName,
    PersonType
)
SELECT FirstName,
       MiddleName,
       LastName,
       PersonType
FROM   dev.PersonSample
WHERE  SampleRowID IN (1, 2, 30, 45, 70, 86, 46);

-- Review the sample, including the added duplicates.
SELECT   *
FROM     dev.PersonSample
ORDER BY LastName, FirstName, SampleRowID;

--
SELECT *
FROM   dev.PersonSample;

--
/* Find Duplicate Records */
SELECT   FirstName,
         MiddleName,
         LastName,
         PersonType,
         COUNT(*) AS DuplicateCount
FROM     dev.PersonSample
GROUP BY FirstName, MiddleName, LastName, PersonType
HAVING   COUNT(*) > 1
ORDER BY DuplicateCount DESC;

/* Inspect every row in the groups */
WITH     DuplicateCheck
AS       (SELECT SampleRowID,
                 FirstName,
                 MiddleName,
                 LastName,
                 PersonType,
                 ROW_NUMBER() OVER (PARTITION BY FirstName, MiddleName, LastName, PersonType ORDER BY SampleRowID) AS RowNum,
                 COUNT(*) OVER (PARTITION BY FirstName, MiddleName, LastName, PersonType) AS DuplicateCount
          FROM   dev.PersonSample)
SELECT   *
FROM     DuplicateCheck
WHERE    DuplicateCount > 1
ORDER BY LastName, FirstName, RowNum;

/* Safely remove duplicates using a transaction*/
-- Create a table to retain a review copy of deleted sample rows.
IF OBJECT_ID('SQLPractice.dev.DeletedRows') IS NOT NULL
    DROP TABLE SQLPractice.dev.DeletedRows;

CREATE TABLE SQLPractice.dev.DeletedRows (
    SampleRowID INT          ,
    FirstName   NVARCHAR (50),
    MiddleName  NVARCHAR (50),
    LastName    NVARCHAR (50),
    PersonType  NCHAR (2)    
);

BEGIN TRANSACTION;

WITH RankedRows
AS   (SELECT SampleRowID,
             ROW_NUMBER() OVER (PARTITION BY FirstName, MiddleName, LastName, PersonType ORDER BY SampleRowID) AS RowNum
      FROM   dev.PersonSample)
DELETE RankedRows
OUTPUT deleted.SampleRowID, deleted.FirstName, deleted.MiddleName, deleted.LastName, deleted.PersonType INTO dev.DeletedRows
WHERE  RowNum > 1;

-- Review exactly what was deleted.
SELECT   *
FROM     #DeletedRows
ORDER BY LastName, FirstName;

-- Verify that no duplicate groups remain under this definition.
SELECT   FirstName,
         MiddleName,
         LastName,
         PersonType,
         COUNT(*) AS RecordCount
FROM     #PersonSample
GROUP BY FirstName, MiddleName, LastName, PersonType
HAVING   COUNT(*) > 1;