IF OBJECT_ID('algo.fn_OpenStrategyGUID') IS NOT NULL    DROP FUNCTION algo.fn_OpenStrategyGUID;
GO

CREATE FUNCTION algo.fn_OpenStrategyGUID (@config_id INT)
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @GUID UNIQUEIDENTIFIER;
		SELECT @GUID =  configInstanceGUID 
		FROM algo.strategyTracker st 
		WHERE 1=1
			AND st.configID = @config_id AND timeClosed IS NULL

	RETURN @GUID
END
GO

SELECT algo.fn_OpenStrategyGUID (2)