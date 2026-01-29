use cTrader 
go
if OBJECT_ID('algo.strategies_positions' ) is not null drop table algo.strategies_positions
go


CREATE TABLE algo.strategies_positions (
    trade_uuid NVARCHAR(50) PRIMARY KEY,      -- UUID сделки = первичный ключ (уникален)
    strategy_configuration_id INT NOT NULL 
        FOREIGN KEY REFERENCES algo.strategy_configurations(ID)
);

-- “олько один индекс дл€ поиска по стратегии
CREATE INDEX idx_strategies_config ON algo.strategies_positions(strategy_configuration_id);