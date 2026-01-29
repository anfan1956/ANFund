
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
    IF NOT EXISTS (SELECT 1 FROM algo.ConfigurationSets WHERE ID = @config_id)
        THROW 50000, 'Configuration not found', 1;
    
    -- Add to queue
    INSERT INTO algo.strategy_termination_queue (config_id)
    VALUES (@config_id);
    
    -- Return request ID
    SELECT 'A record has been enqueued for closing. LogId = ' +  cast(SCOPE_IDENTITY()as nvarchar(10)) as termination_id;
END;
GO

--exec algo.sp_RequestStrategyTermination 3
select * from algo.strategy_termination_queue
