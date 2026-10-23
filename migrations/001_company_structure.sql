-- Quest Format Goals app DB
-- 001_company_structure
-- Baseline Company_structure for Quest/Goal driven management system for a company

BEGIN;

CREATE TABLE companies (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE departments (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT uq_departments_company_id UNIQUE (company_id, id)
);

CREATE TABLE ranks (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  rank_order INT NOT NULL,
  
  CONSTRAINT uq_rank_company_id 
    UNIQUE (company_id, id)
);
  
CREATE TABLE positions (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  department_id BIGINT NOT NULL,
  name TEXT NOT NULL,
  rank_id BIGINT NOT NULL,
  parent_position_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  is_filled BOOLEAN NOT NULL DEFAULT FALSE,
  
  CONSTRAINT uq_positions_company_id 
    UNIQUE (company_id, id),
  
  CONSTRAINT fk_positions_department
    FOREIGN KEY (company_id, department_id) 
    REFERENCES departments(company_id, id)
    ON DELETE RESTRICT,
  
  CONSTRAINT fk_positions_parent
    FOREIGN KEY (company_id, parent_position_id)
    REFERENCES positions(company_id, id)
    ON DELETE RESTRICT,

  CONSTRAINT fk_positions_rank
    FOREIGN KEY (company_id, rank_id)
    REFERENCES ranks(company_id, id)
    ON DELETE RESTRICT,
  
  -- position can't be parent for self
  CONSTRAINT ck_positions_not_self_parent
    CHECK (parent_position_id <> id),

  -- can't have a position is not active to be filled
  CONSTRAINT ck_invalid_position_active
    CHECK (is_active OR NOT is_filled)
);




CREATE INDEX ix_positions_department ON positions (company_id, department_id);
CREATE INDEX ix_positions_parent ON positions (company_id, parent_position_id);

COMMIT;
