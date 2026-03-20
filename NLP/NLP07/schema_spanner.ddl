-- Google Cloud Spanner Graph DDL Prototype
-- LG U+ 5G Plan Graph Schema
-- Generated based on prototyping.md requirements

-- -----------------------------------------------------------------------------
-- 1. Node Tables
-- Note: User Review on Core Attributes is strictly managed here via column rules 
-- (NOT NULL, types) to define explicit Schema definitions in Spanner.
-- -----------------------------------------------------------------------------

CREATE TABLE Plan (
  id STRING(36) NOT NULL,
  
  -- Core plan attributes
  name STRING(100) NOT NULL,
  price INT64 NOT NULL,
  voice_limit STRING(50) NOT NULL,
  
  -- Capacity Data Handling
  -- data_limit: Data amount in GB. Set to -1 or a large placeholder to indicate unlimited, 
  -- but is_data_unlimited BOOL is explicitly required.
  data_limit INT64 NOT NULL,
  is_data_unlimited BOOL NOT NULL,
  
  -- Contract and extra specifications
  contract_period_months INT64, 
  shared_data STRING(50),
  tethering_limit_gb INT64,
  roaming_discount_rate FLOAT64
) PRIMARY KEY (id);

CREATE TABLE PlanCategory (
  id STRING(36) NOT NULL,
  category_name STRING(50) NOT NULL,
  description STRING(200)
) PRIMARY KEY (id);

CREATE TABLE Benefit (
  id STRING(36) NOT NULL,
  benefit_type STRING(50) NOT NULL,
  description STRING(200),
  value STRING(100)
) PRIMARY KEY (id);

CREATE TABLE Condition (
  id STRING(36) NOT NULL,
  condition_type STRING(50) NOT NULL,
  value STRING(100),
  description STRING(200)
) PRIMARY KEY (id);

CREATE TABLE OTTService (
  id STRING(36) NOT NULL,
  service_name STRING(50) NOT NULL,
  provider STRING(50)
) PRIMARY KEY (id);

CREATE TABLE AgeDiscount (
  id STRING(36) NOT NULL,
  min_age INT64,
  max_age INT64,
  discount_rate FLOAT64,
  description STRING(200)
) PRIMARY KEY (id);


-- -----------------------------------------------------------------------------
-- 2. Edge Tables
-- Interleave or Reference using Foreign Keys. For Property Graph, FKs are required.
-- -----------------------------------------------------------------------------

CREATE TABLE Plan_BelongsTo_Category (
  plan_id STRING(36) NOT NULL,
  category_id STRING(36) NOT NULL,
  CONSTRAINT FK_PlanBelongsTo FOREIGN KEY (plan_id) REFERENCES Plan (id),
  CONSTRAINT FK_CategoryBelongsTo FOREIGN KEY (category_id) REFERENCES PlanCategory (id)
) PRIMARY KEY (plan_id, category_id);

CREATE TABLE Plan_Includes_Benefit (
  plan_id STRING(36) NOT NULL,
  benefit_id STRING(36) NOT NULL,
  CONSTRAINT FK_PlanIncludes FOREIGN KEY (plan_id) REFERENCES Plan (id),
  CONSTRAINT FK_BenefitIncludes FOREIGN KEY (benefit_id) REFERENCES Benefit (id)
) PRIMARY KEY (plan_id, benefit_id);

CREATE TABLE Plan_Requires_Condition (
  plan_id STRING(36) NOT NULL,
  condition_id STRING(36) NOT NULL,
  CONSTRAINT FK_PlanRequires FOREIGN KEY (plan_id) REFERENCES Plan (id),
  CONSTRAINT FK_ConditionRequires FOREIGN KEY (condition_id) REFERENCES Condition (id)
) PRIMARY KEY (plan_id, condition_id);

CREATE TABLE Plan_Offers_OTT (
  plan_id STRING(36) NOT NULL,
  ott_id STRING(36) NOT NULL,
  CONSTRAINT FK_PlanOffers FOREIGN KEY (plan_id) REFERENCES Plan (id),
  CONSTRAINT FK_OTTOffers FOREIGN KEY (ott_id) REFERENCES OTTService (id)
) PRIMARY KEY (plan_id, ott_id);

CREATE TABLE Plan_EligibleFor_AgeDiscount (
  plan_id STRING(36) NOT NULL,
  discount_id STRING(36) NOT NULL,
  CONSTRAINT FK_PlanEligible FOREIGN KEY (plan_id) REFERENCES Plan (id),
  CONSTRAINT FK_DiscountEligible FOREIGN KEY (discount_id) REFERENCES AgeDiscount (id)
) PRIMARY KEY (plan_id, discount_id);

CREATE TABLE Condition_Provides_Benefit (
  condition_id STRING(36) NOT NULL,
  benefit_id STRING(36) NOT NULL,
  CONSTRAINT FK_ConditionProvides FOREIGN KEY (condition_id) REFERENCES Condition (id),
  CONSTRAINT FK_BenefitProvidedByCond FOREIGN KEY (benefit_id) REFERENCES Benefit (id)
) PRIMARY KEY (condition_id, benefit_id);

CREATE TABLE Category_Provides_Benefit (
  category_id STRING(36) NOT NULL,
  benefit_id STRING(36) NOT NULL,
  CONSTRAINT FK_CategoryProvides FOREIGN KEY (category_id) REFERENCES PlanCategory (id),
  CONSTRAINT FK_BenefitProvidedByCat FOREIGN KEY (benefit_id) REFERENCES Benefit (id)
) PRIMARY KEY (category_id, benefit_id);


-- -----------------------------------------------------------------------------
-- 3. Property Graph Definition
-- Detailed in a single line mapping mechanism for SOURCE KEY and DESTINATION KEY
-- -----------------------------------------------------------------------------

CREATE PROPERTY GRAPH LGUPlusPlanGraph
  NODE TABLES (Plan, PlanCategory, Benefit, Condition, OTTService, AgeDiscount)
  EDGE TABLES (
    Plan_BelongsTo_Category SOURCE KEY (plan_id) REFERENCES Plan (id) DESTINATION KEY (category_id) REFERENCES PlanCategory (id) LABEL BELONGS_TO,
    Plan_Includes_Benefit SOURCE KEY (plan_id) REFERENCES Plan (id) DESTINATION KEY (benefit_id) REFERENCES Benefit (id) LABEL INCLUDES,
    Plan_Requires_Condition SOURCE KEY (plan_id) REFERENCES Plan (id) DESTINATION KEY (condition_id) REFERENCES Condition (id) LABEL REQUIRES,
    Plan_Offers_OTT SOURCE KEY (plan_id) REFERENCES Plan (id) DESTINATION KEY (ott_id) REFERENCES OTTService (id) LABEL OFFERS,
    Plan_EligibleFor_AgeDiscount SOURCE KEY (plan_id) REFERENCES Plan (id) DESTINATION KEY (discount_id) REFERENCES AgeDiscount (id) LABEL ELIGIBLE_FOR,
    Condition_Provides_Benefit SOURCE KEY (condition_id) REFERENCES Condition (id) DESTINATION KEY (benefit_id) REFERENCES Benefit (id) LABEL PROVIDES,
    Category_Provides_Benefit SOURCE KEY (category_id) REFERENCES PlanCategory (id) DESTINATION KEY (benefit_id) REFERENCES Benefit (id) LABEL PROVIDES_BENEFIT
  );
