IF OBJECT_ID('algo.fn_TerminateInstance') IS NOT NULL   DROP FUNCTION algo.fn_TerminateInstance;
GO

CREATE FUNCTION algo.fn_TerminateInstance (@GUID UNIQUEIDENTIFIER)
RETURNS bit
AS
BEGIN
    DECLARE @terminate bit;
		SELECT @terminate = isnull(
			( select 1			 
						from algo.strategy_termination_queue f
						where 1=1
							and configInstanceGUID = @GUID
							and terminated_at is null)
							, 0)

	RETURN @terminate
END
GO

SELECT 
