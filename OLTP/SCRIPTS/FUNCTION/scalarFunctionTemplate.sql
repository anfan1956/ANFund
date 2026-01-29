if OBJECT_ID('trd.platform_ID') is not NULL DROP FUNCTION trd.platform_ID
go
CREATE FUNCTION trd.platform_ID(@platform NVARCHAR(50), @version VARCHAR(50))
RETURNS INT
AS
BEGIN
    DECLARE @ID INT;
    
    
    SELECT @ID = ID 
    FROM trd.platforms 
    WHERE 
        platformCode = @platform
        and platformVersion = @version;

    
    -- Return the ID (or NULL if not found)
    RETURN @ID;
END

GO
select * from trd.platforms
declare @broker varchar (50) = 'Pepperstone'
	, @platform varchar  = 'CTRADER', @version varchar(50) = '5.5.13.46616'
	;

select trd.platform_ID (@platform, '5.5.13.46616')