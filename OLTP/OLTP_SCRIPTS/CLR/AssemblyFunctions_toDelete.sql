if OBJECT_ID ('tempDB..#AssemblyFunctions') is not null drop table #AssemblyFunctions
go

-- 1. Сначала получаем список ВСЕХ функций из этой сборки
DECLARE @AssemblyName NVARCHAR(255) = 'SQL_CLR_EMA';
DECLARE @assembly_id INT;

-- Получаем ID сборки
SELECT @assembly_id = assembly_id 
FROM sys.assemblies 
WHERE name = @AssemblyName;

IF @assembly_id IS NOT NULL
BEGIN
    PRINT 'Найдена сборка: ' + @AssemblyName;
    
    -- Создаем временную таблицу для хранения информации о функциях
	
    CREATE TABLE #AssemblyFunctions (
        RowID INT IDENTITY(1,1),
        schema_name NVARCHAR(128),
        function_name NVARCHAR(128),
        object_id INT
    );
    
    -- Получаем все функции из этой сборки
    INSERT INTO #AssemblyFunctions (schema_name, function_name, object_id)
    SELECT 
        SCHEMA_NAME(o.schema_id) as schema_name,
        o.name as function_name,
        o.object_id
    FROM sys.objects o
    INNER JOIN sys.assembly_modules am ON o.object_id = am.object_id
    WHERE am.assembly_id = @assembly_id
        AND o.type IN ('FS', 'FT'); -- FS = Scalar function, FT = Table-valued function
    
    -- Выводим список функций для информации
    PRINT 'Функции в сборке ' + @AssemblyName + ':';
    SELECT * FROM #AssemblyFunctions ORDER BY RowID;

    -- Удаляем все функции через цикл
    DECLARE @CurrentRowID INT = 1;
    DECLARE @MaxRowID INT;
    DECLARE @CurrentSchema NVARCHAR(128);
    DECLARE @CurrentFunction NVARCHAR(128);
    DECLARE @DropSQL NVARCHAR(500);
    
    SELECT @MaxRowID = MAX(RowID) FROM #AssemblyFunctions;
    
    WHILE @CurrentRowID <= @MaxRowID
    BEGIN
        -- Получаем информацию о текущей функции
        SELECT 
            @CurrentSchema = schema_name,
            @CurrentFunction = function_name
        FROM #AssemblyFunctions
        WHERE RowID = @CurrentRowID;
        
        -- Формируем команду DROP
        SET @DropSQL = 'DROP FUNCTION ' + QUOTENAME(@CurrentSchema) + '.' + QUOTENAME(@CurrentFunction) + ';';
        
        -- Выводим информацию о удалении
        PRINT 'Удаляю функцию: ' + @CurrentSchema + '.' + @CurrentFunction;
        
        -- Выполняем удаление
        BEGIN TRY
            EXEC sp_executesql @DropSQL;
            PRINT '  ✓ Функция удалена успешно.';
        END TRY
        BEGIN CATCH
            PRINT '  ✗ Ошибка при удалении: ' + ERROR_MESSAGE();
        END CATCH
        
        -- Переходим к следующей функции
        SET @CurrentRowID = @CurrentRowID + 1;
    END
    
    -- Удаляем временную таблицу
    DROP TABLE #AssemblyFunctions;
    
    PRINT 'Все функции из сборки удалены.';
END
ELSE
BEGIN
    PRINT 'Сборка ' + @AssemblyName + ' не найдена.';
END
GO