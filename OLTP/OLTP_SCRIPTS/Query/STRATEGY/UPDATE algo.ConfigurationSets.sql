--insert into algo.ConfigurationSets(ParameterSetId, ParameterValuesJson) values (1, 'some')


-- Обновляем первые три записи с правильными кодами таймфреймов
UPDATE algo.ConfigurationSets 
SET ParameterValuesJson = '{
  "ticker": "XAUUSD",
  "timeframe_signal": "M1",
  "timeframe_confirmation": "M15",
  "timeframe_trend": "H1",
  "open_volume": 0.02,
  "trading_close_utc": "22:00",
  "trading_start_utc": "00:00",
  "broker_id": 2,
  "platform_id": 1,
  "max_position_checks": 10,
  "check_interval_seconds": 10
}'
WHERE Id = 1;

UPDATE algo.ConfigurationSets 
SET ParameterValuesJson = '{
  "ticker": "XAGUSD",
  "timeframe_signal": "M5",
  "timeframe_confirmation": "M30",
  "timeframe_trend": "H4",
  "open_volume": 0.01,
  "trading_close_utc": "22:00",
  "trading_start_utc": "00:00",
  "broker_id": 2,
  "platform_id": 1,
  "max_position_checks": 15,
  "check_interval_seconds": 15
}'
WHERE Id = 2;

UPDATE algo.ConfigurationSets 
SET ParameterValuesJson = '{
  "ticker": "BTCUSD",
  "timeframe_signal": "M1",
  "timeframe_confirmation": "M15",
  "timeframe_trend": "H1",
  "open_volume": 0.02,
  "trading_close_utc": "00:00",
  "trading_start_utc": "00:00",
  "broker_id": 2,
  "platform_id": 1,
  "max_position_checks": 20,
  "check_interval_seconds": 30
}'
WHERE Id = 3;
UPDATE algo.ConfigurationSets 
SET ParameterValuesJson = '{
  "ticker": "BTCUSD",
  "timeframe_signal": "M1",
  "timeframe_confirmation": "M15",
  "timeframe_trend": "H1",
  "open_volume": 0.03,
  "trading_close_utc": "null",
  "trading_start_utc": "null",
  "broker_id": 2,
  "platform_id": 1,
  "max_position_checks": 20,
  "check_interval_seconds": 30
}'
WHERE Id = 8;

UPDATE algo.ConfigurationSets 
SET ParameterValuesJson = '{
  "ticker": "BTCUSD",
  "timeframe_signal": "M5",
  "timeframe_confirmation": "M30",
  "timeframe_trend": "H4",
  "open_volume": 0.04,
  "trading_close_utc": "null",
  "trading_start_utc": "null",
  "broker_id": 2,
  "platform_id": 1,
  "max_position_checks": 20,
  "check_interval_seconds": 30
}'
WHERE Id = 10;

UPDATE algo.ConfigurationSets 
SET ParameterValuesJson = 
'{    
		"ticker": "XPTUSD",    
		"timeframe_signal": "M1",    
		"timeframe_confirmation": "M15",    
		"timeframe_trend": "H1",    
		"open_volume": 0.01,    
		"trading_close_utc": "null",    
		"trading_start_utc": "null",    
		"broker_id": 2,    
		"platform_id": 1,    
		"max_position_checks": 20,    
		"check_interval_seconds": 30   
}'
WHERE Id = 11
GO
UPDATE algo.ConfigurationSets 
SET ParameterValuesJson = 
'{
		"ticker": "SPX500",
		"timeframe_signal": "M1",
		"timeframe_confirmation": "M15",
		"timeframe_trend": "H1",
		"open_volume": 1,
		"trading_close_utc": "null",
		"trading_start_utc": "null",
		"broker_id": 2,
		"platform_id": 1,
		"max_position_checks": 20,
		"check_interval_seconds": 10
	}'
WHERE Id = 12;
GO

-- Проверяем какие коды таймфреймов есть в tms.timeframes
PRINT 'Список таймфреймов:';
SELECT ID, timeframeCode, timeframeName, minutes 
FROM tms.timeframes 
ORDER BY minutes;
GO

-- Проверка результатов
SELECT 
    Id,
    ParameterSetId,
    LOWER(CONVERT(VARCHAR(64), hashForSet, 2)) AS HashString,
    JSON_VALUE(ParameterValuesJson, '$.ticker') AS Ticker,
    JSON_VALUE(ParameterValuesJson, '$.timeframe_signal') AS TF_Signal_Code,
    JSON_VALUE(ParameterValuesJson, '$.timeframe_confirmation') AS TF_Confirmation_Code,
    JSON_VALUE(ParameterValuesJson, '$.timeframe_trend') AS TF_Trend_Code,
    JSON_VALUE(ParameterValuesJson, '$.open_volume') AS Volume,
    JSON_VALUE(ParameterValuesJson, '$.trading_close_utc') AS CloseTime,
    JSON_VALUE(ParameterValuesJson, '$.trading_start_utc') AS StartTime
FROM algo.ConfigurationSets
--WHERE Id IN (1, 2, 3)
ORDER BY Id;

select * from algo.ConfigurationSets



--  insert CONFIG
/*

insert into algo.ConfigurationSets (ParameterSetId, ParameterValuesJson)
values 
(
	1, 
	'{
		"ticker": "NAS100",
		"timeframe_signal": "M1",
		"timeframe_confirmation": "M15",
		"timeframe_trend": "H1",
		"open_volume": 0.3,
		"trading_close_utc": "null",
		"trading_start_utc": "null",
		"broker_id": 2,
		"platform_id": 1,
		"max_position_checks": 10,
		"check_interval_seconds": 10
	}')
*/

select * from algo.ConfigurationSets s where s.Id = 11

select * from ref.assetMasterTable 