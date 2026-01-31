
-- Drop procedure if exists
IF OBJECT_ID('algo.sp_RequestStrategyTermination', 'P') IS NOT NULL
    DROP PROCEDURE algo.sp_RequestStrategyTermination;
GO

-- Create procedure to request termination
CREATE PROCEDURE algo.sp_RequestStrategyTermination
    @config_id INT
AS
BEGIN
	set nocount on;
    -- Check if configuration exists
	DECLARE @GUID UNIQUEIDENTIFIER  = algo.fn_OpenStrategyGUID (@config_id);
    IF NOT EXISTS (SELECT 1 FROM algo.ConfigurationSets WHERE ID = @config_id)
        THROW 50000, 'Configuration not found', 1;

	if @GUID  is not null 
					and not exists (
						select 1 
						from algo.strategy_termination_queue f
						where 1=1
							and configInstanceGUID = @GUID
							and terminated_at is null
					)
		Begin
			-- Add to queue
			INSERT INTO algo.strategy_termination_queue (config_id, configInstanceGUID)
			VALUES (@config_id, @GUID);
			-- Return request ID
			SELECT 'A record has been enqueued for closing. LogId = ' +  cast(SCOPE_IDENTITY()as nvarchar(10)) as termination_id;
		END    
END;
GO

--exec algo.sp_RequestStrategyTermination 3
select * from algo.strategy_termination_queue order by 1 desc
