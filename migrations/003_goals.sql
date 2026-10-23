-- Quest Format Goals app DB
-- 003_goals
-- goals that are given to users 

BEGIN;

-- reference table for type of task user can work on. ex.Research, market reasearch(child of research)
CREATE TABLE task_types (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  parent_task_type_id BIGINT,

  CONSTRAINT fk_task_type_parent
    FOREIGN KEY (parent_task_type_id)
    REFERENCES task_types(id),

  CONSTRAINT ck_task_type_self_parent
    CHECK (parent_task_type_id <> id)
);


--goals templates/reference to use/add
CREATE TABLE goal_templates (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  task_type_id BIGINT NOT NULL,
  description TEXT,
  parent_goal_template_id BIGINT,
  estimate_days_needed INT NOT NULL,
  max_point_worth INT NOT NULL,
  min_point_worth INT NOT NULL,


  CONSTRAINT uq_goal_templates_company_id 
    UNIQUE (company_id, id),

  CONSTRAINT fk_goal_template_parent
    FOREIGN KEY (company_id, parent_goal_template_id)
    REFERENCES goal_templates(company_id, id),

  CONSTRAINT fk_goal_templates_task_type
    FOREIGN KEY (task_type_id)
    REFERENCES task_types(id),

  CONSTRAINT ck_goal_template_mix_less_than_max_points
    CHECK (min_point_worth <= max_point_worth)

);


CREATE TABLE goals (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  task_type_id BIGINT NOT NULL,
  goal_tier BIGINT NOT NULL,
  description TEXT,
  parent_goal_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_position_id BIGINT NOT NULL,
  created_by_user_id BIGINT NOT NULL,
  due_date DATE,
  points_worth INT NOT NULL,
  referenced_template_id BIGINT,
  
  
  CONSTRAINT uq_goals_company_id 
    UNIQUE (company_id, id),

  CONSTRAINT ck_goals_self_parent
    CHECK (parent_goal_id <> id),

  CONSTRAINT ck_goals_point_worth_not_negative
    CHECK (points_worth >= 0),

  CONSTRAINT fk_goals_parent
    FOREIGN KEY (company_id, parent_goal_id)
    REFERENCES goals(company_id, id)
    ON DELETE RESTRICT,

  CONSTRAINT fk_goals_created_by_position
    FOREIGN KEY (company_id, created_by_position_id)
    REFERENCES positions(company_id, id)
    ON DELETE RESTRICT,  

  CONSTRAINT fk_goals_created_by_user
    FOREIGN KEY (company_id, created_by_user_id)
    REFERENCES users(company_id, id)
    ON DELETE RESTRICT,  

  CONSTRAINT fk_goals_task_type
    FOREIGN KEY (task_type_id)
    REFERENCES task_types(id)
    ON DELETE RESTRICT,

  CONSTRAINT fk_goals_referenced_template_id
    FOREIGN KEY (company_id, referenced_template_id)
    REFERENCES goal_templates(company_id, id)
    ON DELETE RESTRICT
);



-- goal is made then assigned. this table keeps the record of goal's current status after it was assigned
CREATE TABLE goal_assignments (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  goal_id BIGINT NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL,
  issued_by_position_id BIGINT NOT NULL,
  issued_by_user_id BIGINT NOT NULL,
  assigned_position_id BIGINT NOT NULL,
  assigned_user_id BIGINT NOT NULL,
  completed_at TIMESTAMPTZ,
  goal_status TEXT NOT NULL DEFAULT 'in_progress',

  CONSTRAINT uq_goal_assignments_company_id 
    UNIQUE (company_id, id),

  CONSTRAINT ck_goal_assignments_status
    CHECK (goal_status IN ('in_progress', 'complete', 'terminated', 'passed_over', 'reported', 'rejected')),

  CONSTRAINT ck_goal_assignment_complete
    CHECK ( (completed_at IS NOT NULL) = (goal_status = 'complete')),

  CONSTRAINT fk_goal_assignments_goal_id
    FOREIGN KEY (company_id, goal_id)
    REFERENCES goals(company_id, id),

  CONSTRAINT fk_goal_assignments_issued_by_position
    FOREIGN KEY (company_id, issued_by_position_id) 
    REFERENCES positions(company_id, id)
    ON DELETE RESTRICT, 

  CONSTRAINT fk_goal_assignments_assigned_position
    FOREIGN KEY (company_id, assigned_position_id) 
    REFERENCES positions(company_id, id)
    ON DELETE RESTRICT, 
  
  CONSTRAINT fk_goal_assignments_issued_by_user
    FOREIGN KEY (company_id, issued_by_user_id) 
    REFERENCES users(company_id, id)
    ON DELETE RESTRICT, 

  CONSTRAINT fk_goal_assignments_assigned_user
    FOREIGN KEY (company_id, assigned_user_id) 
    REFERENCES users(company_id, id)
    ON DELETE RESTRICT
  
  
);

-- this table keeps record of each change of event in goal assignments
CREATE TABLE goal_events (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  goal_assignment_id BIGINT NOT NULL,
  actor_user_id BIGINT NOT NULL,
  event_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  event_type TEXT NOT NULL,

  CONSTRAINT uq_goal_events 
    UNIQUE (company_id, id),

  CONSTRAINT ck_goal_events_event_type
    CHECK (event_type IN ('assigned', 'passed_over', 'reported', 'rejected', 'approved', 'terminated', 'completed')),

  CONSTRAINT fk_goal_events_goal_assignment
    FOREIGN KEY (company_id, goal_assignment_id)
    REFERENCES goal_assignments(company_id, id),

  CONSTRAINT fk_goal_events_user_id
    FOREIGN KEY (company_id, actor_user_id)
    REFERENCES users(company_id, id)
  
);



-- goal_templates
CREATE INDEX ix_goal_templates_parent    ON goal_templates (company_id, parent_goal_template_id);
CREATE INDEX ix_goal_templates_task_type ON goal_templates (task_type_id);

-- goals
CREATE INDEX ix_goals_parent             ON goals (company_id, parent_goal_id);
CREATE INDEX ix_goals_template           ON goals (company_id, referenced_template_id);
CREATE INDEX ix_goals_task_type          ON goals (task_type_id);

-- goal_assignments
CREATE INDEX ix_goal_assignments_goal          ON goal_assignments (company_id, goal_id);
CREATE INDEX ix_goal_assignments_assigned_user ON goal_assignments (company_id, assigned_user_id);
CREATE INDEX ix_goal_assignments_assigned_pos  ON goal_assignments (company_id, assigned_position_id);

-- goal_events
CREATE INDEX ix_goal_events_assignment   ON goal_events (company_id, goal_assignment_id);


COMMIT;
