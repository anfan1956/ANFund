IF OBJECT_ID('algo.GetStrategyConfigsPivot', 'P') IS NOT NULL 
    DROP PROCEDURE algo.GetStrategyConfigsPivot
GO

CREATE PROCEDURE algo.GetStrategyConfigsPivot 
    @strategyCode NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @columns NVARCHAR(MAX);
    DECLARE @sql NVARCHAR(MAX);
    
    SELECT 
        @columns = STRING_AGG(
            'JSON_VALUE(cs.ParameterValuesJson, ''$."' + param.value + '"'') AS ' + 
            QUOTENAME(param.value), 
            ', '
        )
    FROM algo.strategies s
    INNER JOIN algo.ParameterSets ps ON s.ID = ps.strategy_id
    CROSS APPLY OPENJSON(ps.ParameterSetJson) AS param
    WHERE s.strategy_code = @strategyCode;
    
    IF @columns IS NOT NULL
    BEGIN
        SET @sql = N'
        SELECT 
            cs.Id AS configID, ' + @columns + '
        FROM algo.strategies s
        INNER JOIN algo.ParameterSets ps ON s.ID = ps.strategy_id
        INNER JOIN algo.ConfigurationSets cs ON ps.Id = cs.ParameterSetId
        WHERE s.strategy_code = @strategy
        ORDER BY cs.Id;';
        
        EXEC sp_executesql @sql, 
            N'@strategy NVARCHAR(60)', 
            @strategy = @strategyCode;
    END
    ELSE
    BEGIN
        SELECT 'Strategy not found or no parameters defined' AS Message;
    END
END
GO

EXEC algo.GetStrategyConfigsPivot @strategyCode = 'mtf_rsi_ema';