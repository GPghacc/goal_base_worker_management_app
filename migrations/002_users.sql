-- Quest Format Goals app DB
-- 002_users
-- worker as user that works on the company

BEGIN;

CREATE TABLE users (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  employee_no TEXT NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  birth_date DATE NOT NULL,
  position_id BIGINT,
  start_date DATE NOT NULL,
  end_date DATE,
  user_status TEXT NOT NULL DEFAULT 'in_training',
  current_points int NOT NULL DEFAULT 0,
  total_exp int NOT NULL DEFAULT 0,
  
  CONSTRAINT uq_users_company_id 
    UNIQUE (company_id, id),

  CONSTRAINT uq_users_employee_no
    UNIQUE (company_id, employee_no),

  CONSTRAINT fk_users_position
    FOREIGN KEY (company_id, position_id) 
    REFERENCES positions(company_id, id)
    ON DELETE RESTRICT,  

  CONSTRAINT ck_users_status
    CHECK (user_status IN ('in_training', 'working', 'suspended', 'waiting_position', 'retired', 'left')),

  CONSTRAINT ck_users_out_of_company_end_date
    CHECK ((user_status IN ('retired', 'left')) = (end_date IS NOT NULL)),

  CONSTRAINT ck_users_position_by_status
    CHECK (
      CASE
        WHEN user_status IN ('retired', 'left', 'waiting_position') THEN position_id IS NULL
        WHEN user_status IN ('in_training')        THEN TRUE
        ELSE position_id IS NOT NULL
      END
    ),  
  CONSTRAINT ck_users_date_validity
    CHECK (end_date IS NULL OR start_date <= end_date),
  
  CONSTRAINT ck_users_current_points_not_negative 
    CHECK (current_points >= 0),
  
  CONSTRAINT ck_users_total_exp_not_negative 
    CHECK (total_exp >= 0)
);

CREATE TABLE position_history (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  position_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE, --null if still in position
  end_reason TEXT,

  CONSTRAINT fk_position_history_position
    FOREIGN KEY (company_id, position_id) 
    REFERENCES positions(company_id, id)
    ON DELETE RESTRICT,

  CONSTRAINT fk_position_history_user
    FOREIGN KEY (company_id, user_id) 
    REFERENCES users(company_id, id)
    ON DELETE RESTRICT, 

  CONSTRAINT ck_position_history_end_reasons
    CHECK (end_reason IN ('promotion', 'demotion', 'department_change', 'position_changed', 'retired', 'left')),

  --if user is still in position, keep end_reason null
  CONSTRAINT ck_position_history_end_consistency
    CHECK ((end_date IS NULL) = (end_reason IS NULL)),

  CONSTRAINT ck_position_history_date_validity
    CHECK (end_date IS NULL OR start_date <= end_date)
);


CREATE INDEX ix_users_position             ON users (company_id, position_id);
CREATE INDEX ix_position_history_user      ON position_history (company_id, user_id);
CREATE INDEX ix_position_history_position  ON position_history (company_id, position_id);

COMMIT;
