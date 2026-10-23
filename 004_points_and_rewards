-- Quest Format Goals app DB
-- 004_points_and_rewards
-- point actions and rewards user can spend their points on

BEGIN;

-- set of rewards users can use their earned points on
CREATE TABLE rewards (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  points_needed INT NOT NULL,
  description TEXT NOT NULL,
  created_by_user_id BIGINT NOT NULL,
  limit_type TEXT NOT NULL,
  limit_number INT,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,

  CONSTRAINT uq_rewards_company_id
    UNIQUE (company_id, id),

  CONSTRAINT fk_rewards_created_by_user
    FOREIGN KEY (company_id, created_by_user_id)
    REFERENCES users(company_id, id)
    ON DELETE RESTRICT,

  CONSTRAINT ck_rewards_limit_type
    CHECK (limit_type IN ('daily', 'weekly', 'biweekly', 'monthly', 'quarterly', 'annually', 'limitless' )),

  CONSTRAINT ck_rewards_limitless_limit_number
    CHECK ((limit_type = 'limitless') = (limit_number IS NULL)),

  CONSTRAINT ck_rewards_limit_number_not_negative
    CHECK (limit_number > 0),

  CONSTRAINT ck_rewards_points_needed_not_negative
    CHECK (points_needed > 0)
  
);


CREATE TABLE point_events (
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  point_event_user_id BIGINT NOT NULL,
  point_action TEXT NOT NULL,
  point_amount INT NOT NULL,
  description TEXT NOT NULL,
  related_goal_assignment_id BIGINT,
  reward_id BIGINT,
  event_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT uq_point_events_company_id
    UNIQUE (company_id, id),

  --prevents multiple gain from single goal. 
  CONSTRAINT uq_point_events_related_goal_assignment_id
    UNIQUE (company_id, related_goal_assignment_id),
  
  CONSTRAINT fk_point_events_point_event_user_id
    FOREIGN KEY (company_id, point_event_user_id)
    REFERENCES users(company_id, id)
    ON DELETE RESTRICT, 

  CONSTRAINT fk_point_events_goal_assignment
    FOREIGN KEY (company_id, related_goal_assignment_id)
    REFERENCES goal_assignments (company_id, id),

  CONSTRAINT fk_point_events_reward
    FOREIGN KEY (company_id, reward_id)
    REFERENCES rewards (company_id, id),

  CONSTRAINT ck_point_events_point_actions
    CHECK (point_action IN ('gain', 'usage', 'adjustment' )),

  CONSTRAINT ck_point_events_point_usage_reason
    CHECK ((point_action = 'usage') = (reward_id IS NOT NULL)),

  CONSTRAINT ck_point_events_point_gain_reason
    CHECK ((point_action = 'gain') = (related_goal_assignment_id IS NOT NULL)),

  CONSTRAINT ck_point_events_gain_not_negative
    CHECK ((point_action = 'gain') = (point_amount > 0)),

  CONSTRAINT ck_point_events_point_amount_not_zero
    CHECK (point_amount <> 0)
);



CREATE INDEX ix_point_events_point_event_user_id 
  ON point_events (company_id, point_event_user_id, point_action)
  INCLUDE (point_amount);


COMMIT;
