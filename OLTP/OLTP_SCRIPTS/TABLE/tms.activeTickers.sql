if OBJECT_ID('tms.activeTickers') is not null drop table tms.activeTickers
go

create table tms.activeTickers
(
	tickerJID	int constraint Fk_activeTickers_ticker foreign key references ref.assetMasterTable (ID), 
	isActive	bit default null, 
	brokerID	int constraint Fk_activeTickers_broker foreign key references trd.brokers (ID),  
	modified	datetime default (GETDATE())
)
go
