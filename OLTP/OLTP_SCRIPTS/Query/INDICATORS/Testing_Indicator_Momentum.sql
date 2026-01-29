/*
Типы объектов SQL Server:
'FN' = SQL Scalar function
'TF' = SQL Table-valued function
'FS' = CLR Scalar function
'FT' = CLR Table-valued function (это наш случай!)
'P' = SQL Stored procedure
'PC' = CLR Stored procedure
'U' = Table
*/


-- Тест 1: Проверяем, что функции созданы
SELECT 
    name, 
    type_desc,
    create_date
FROM sys.objects 
WHERE name IN (
    'CalculateRSISeriesBatch',
    'CalculateStochasticSeriesBatch', 
    'CalculateROCSeriesBatch'
) AND type = 'FT';

-- Тест 2: Быстрый тест на небольшом объеме данных
SELECT TOP 10 * 
FROM dbo.CalculateRSISeriesBatch(60, NULL, NULL)
ORDER BY BarTime DESC;

SELECT TOP 10 * 
FROM dbo.CalculateStochasticSeriesBatch(60, NULL, NULL)
ORDER BY BarTime DESC;

SELECT TOP 10 * 
FROM dbo.CalculateROCSeriesBatch(60, NULL, NULL)
ORDER BY BarTime DESC;
