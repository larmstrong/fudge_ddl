 
--------------------------------------------------------------------------------
-- This script creates/recreates a data warehouse for Fudge Co, a conglomerate
-- of two separate businesses, FudgeMart, a seller of consumer goods, and 
-- FudgeFlix, a mail-order and online video rental house. 
--
-- Key parameters for this script follow. As database and schema names are not
-- dynamic (i.e., can not be used via a variable) any changes to these values
-- should be made by a global search and replace.
--   1. Data warehouse database name. 
--      CURRENT VALUE: ist722_learmstr_dw
--   2. Data warehouse schema name.
--      CURRENT VALUE: dw_fudgeco
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- STAGE 1: INITIAL SET UP - DB AND SCHEMA(S) ----------------------------------


-- Set the DB to the current datawarehouse 
 USE ist722_learmstr_dw;

-- Create the dw_fudgeco schema if it does not exist
IF (NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dw_fudgeco')) 
	BEGIN
		EXEC ('CREATE SCHEMA [dw_fudgeco] AUTHORIZATION [dbo]')
		PRINT 'CREATE SCHEMA [dw_fudgeco] AUTHORIZATION [dbo]'
	END
ELSE
	BEGIN
		PRINT 'SCHEMA [dw_fudgeco] exists.'
	END
GO 


--------------------------------------------------------------------------------
-- STAGE 2: CLEAN OUT OLDER DATA AND START ANEW --------------------------------


/* Drop table dw_fudgeco.fact_sales */
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'dw_fudgeco.fact_sales') AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
	DROP TABLE dw_fudgeco.fact_sales
	PRINT('TABLE dw_fudgeco.fact_sales dropped.')
END
GO

/* Drop table dw_fudgeco.dim_date */
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'dw_fudgeco.dim_date') AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
	DROP TABLE dw_fudgeco.dim_date
	PRINT('TABLE dw_fudgeco.dim_date dropped.')
END
GO

/* Drop table dw_fudgeco.dim_customer */
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'dw_fudgeco.dim_customer') AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
	DROP TABLE dw_fudgeco.dim_customer
	PRINT('TABLE dw_fudgeco.dim_customer dropped.')
END
GO

/* Drop table dw_fudgeco.dim_commodity */
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'dw_fudgeco.dim_commodity') AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
	DROP TABLE dw_fudgeco.dim_commodity
	PRINT('TABLE dw_fudgeco.dim_commodity dropped.')
END
GO

--------------------------------------------------------------------------------
-- STAGE 3: CREATE THE REQUIRED DIMENSION TABLES. ------------------------------
 

-- Create Date dimension
CREATE TABLE [dw_fudgeco].[dim_date]
(
	[DateKey]       INT         NOT NULL,
	[Date]          DATETIME    NOT NULL,
	[FullDateUSA]   NCHAR(11)   NOT NULL,
	[DayOfWeek]     TINYINT     NOT NULL,
	[DayName]       NCHAR(10)   NOT NULL,
	[DayOfMonth]    TINYINT     NOT NULL,
	[DayOfYear]     INT         NOT NULL,
	[WeekOfYear]    TINYINT     NOT NULL,
	[MonthName]     NCHAR(10)   NOT NULL,
	[MonthOfYear]   TINYINT     NOT NULL,
	[Quarter]       TINYINT     NOT NULL,
	[QuarterName]   NCHAR(10)   NOT NULL,
	[Year]          INT         NOT NULL,
	[IsAWeekday]    VARCHAR(1)  NOT NULL DEFAULT (('N')),
	CONSTRAINT pkNorthwinddim_date PRIMARY KEY ([DateKey])
)
PRINT 'TABLE dw_fudgeco.dim_date created.'
GO
 
-- Create Customer Dimension
-- The customer dimension will include sales contact entities from both
-- FudgeMart and FudgeFlix.
CREATE TABLE [dw_fudgeco].[dim_customer]
(
	[customer_key] 			INT IDENTITY	NOT NULL,
	[customer_firstname]	VARCHAR(50)		NOT NULL,
	[customer_lastname] 	VARCHAR(50)		NOT NULL,
	[customer_address] 		VARCHAR(1000)	NOT NULL	DEFAULT(('UNKNOWN')),
	-- [customer_state] -- Not currently addressed (no pun intended).
	[customer_zipcode] 		VARCHAR(20)		NOT NULL,
	[customer_phone] 		VARCHAR(30)		NOT NULL	DEFAULT(('UNKNOWN')),
	[customer_fax] 			VARCHAR(30)		NOT NULL	DEFAULT(('UNKNOWN')),
	[customer_since] 		DATE			NOT NULL,
	CONSTRAINT pk_dw_fudgeco_dim_customer PRIMARY KEY ([customer_key])
)
PRINT 'TABLE dw_fudgeco.dim_customer created.'
GO

-- Create Commodity Dimension
-- The commodity dimension will include both products and subscriptions.
CREATE TABLE [dw_fudgeco].[dim_commodity]
(
	[commodity_key]				INT	IDENTITY	NOT NULL,
	[commodity_name]			VARCHAR(50)		NOT NULL,
	[commodity_department]		VARCHAR(20)		NOT NULL,
	[commodity_retail_price]	DECIMAL(10,2)	NOT NULL,
	[commodity_wholesale_price]	DECIMAL(10,2)	NOT NULL,
	[commodity_is_active]		BIT				NOT NULL,
	CONSTRAINT pk_dw_fudgeco_dim_commodity PRIMARY KEY ([commodity_key])
)
PRINT 'TABLE dw_fudgeco.dim_commodity created.'
GO


--------------------------------------------------------------------------------
-- STAGE 4: CREATE THE REQUIRED FACT TABLES. -----------------------------------

CREATE TABLE [dw_fudgeco].[fact_sales]
(
	[fact_sales_key]			INT	IDENTITY	NOT NULL,	-- Fact sales surrogate key
	[transaction_id]			INT				NOT NULL,	-- Business key pt 1. (fm.Orders.OrderID or fl.acct_bill.ab_id)
	[commodity_key]				INT				NOT NULL,	-- Business key pt 2. Ref. to dim_commodity
	[transaction_date_key]		INT				NOT NULL,	-- Business key pt 3. Ref. to dim_date
	[customer_key]				INT				NOT NULL,	-- Business key pt 4. Ref. to dim_customer
	[transaction_quantity]		INT				NOT NULL,
	[transaction_total]			DECIMAL(10,2)	NOT NULL,
	[transaction_gross_profit]	DECIMAL(10,2)	NOT NULL,
	CONSTRAINT pk_dw_fudgeco_fact_sales                      PRIMARY KEY ([fact_sales_key]),
	CONSTRAINT fk_dw_fudgeco_fact_sales_transaction_date_key FOREIGN KEY (transaction_date_key) REFERENCES [dw_fudgeco].dim_date(DateKey),
	CONSTRAINT fk_dw_fudgeco_fact_sales_customer_key 		 FOREIGN KEY (customer_key)			REFERENCES [dw_fudgeco].dim_customer(customer_key),
	CONSTRAINT fk_dw_fudgeco_fact_sales_commodity_key 		 FOREIGN KEY (commodity_key)		REFERENCES [dw_fudgeco].dim_commodity(commodity_key),
    CONSTRAINT chk_dw_fudgeco_fact_sales_01 				 UNIQUE (transaction_id, commodity_key, transaction_date_key, customer_key)
)
PRINT 'TABLE dw_fudgeco.fact_sales created.'
GO
