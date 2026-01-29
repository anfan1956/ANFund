EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

EXEC sp_configure 'clr strict security';




EXEC sp_configure 'clr strict security', 0;
RECONFIGURE;

EXEC sp_configure 'clr strict security';



USE [cTrader];
GO

-- Создай сборку
CREATE ASSEMBLY SQL_CLR_EMA
FROM 'D:\TradingSystems\CLR\SQL_CLR_EMA\bin\Debug\SQL_CLR_EMA.dll'
WITH PERMISSION_SET = SAFE;
GO

PRINT 'Assembly SQL_CLR_EMA created';


SELECT 
    am.assembly_class,
    am.assembly_method
FROM sys.assembly_modules am
INNER JOIN sys.assemblies a ON am.assembly_id = a.assembly_id
WHERE a.name = 'SQL_CLR_EMA';


SELECT 
    a.name,
    a.permission_set_desc,
    a.clr_name,
    OBJECT_DEFINITION(asm.object_id) as ModuleDefinition
FROM sys.assemblies a
LEFT JOIN sys.assembly_modules asm ON a.assembly_id = asm.assembly_id
WHERE a.name = 'SQL_CLR_EMA';
go

-- Создай функции напрямую из сборки
CREATE FUNCTION dbo.fn_CalculateEMA_CLR_FINAL(
    @currentPrice FLOAT,
    @previousEMA FLOAT,
    @period INT
)
RETURNS FLOAT
AS EXTERNAL NAME SQL_CLR_EMA.[UserDefinedFunctions].CalculateEMA_CLR;
GO

CREATE FUNCTION dbo.fn_GetAlpha_CLR_FINAL(
    @period INT
)
RETURNS FLOAT
AS EXTERNAL NAME SQL_CLR_EMA.[UserDefinedFunctions].GetAlpha_CLR;
GO

PRINT 'Functions created from CLR';




-- Тест 1: Alpha коэффициент
SELECT 
    dbo.fn_GetAlpha_CLR_FINAL(9) as Alpha_9,
    dbo.fn_GetAlpha_CLR_FINAL(20) as Alpha_20,
    dbo.fn_GetAlpha_CLR_FINAL(50) as Alpha_50;

-- Тест 2: Расчет EMA последовательно
DECLARE @ema FLOAT = 100.0;  -- Начальное значение

-- Шаг 1: 102 → 100 → период 9
SELECT @ema = dbo.fn_CalculateEMA_CLR_FINAL(102.0, @ema, 9);
SELECT @ema as EMA_After_102;

-- Шаг 2: 105 → предыдущая EMA → период 9  
SELECT dbo.fn_CalculateEMA_CLR_FINAL(105.0, @ema, 9) as EMA_After_105;

-- Тест 3: С NULL
SELECT 
    dbo.fn_CalculateEMA_CLR_FINAL(NULL, 100.0, 9) as WithNullPrice,
    dbo.fn_CalculateEMA_CLR_FINAL(105.0, NULL, 9) as WithNullPrevEMA;
