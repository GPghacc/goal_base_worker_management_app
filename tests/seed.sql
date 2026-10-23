-- Test seed data for data_input_testing branch
-- Run once on an empty schema built from 001-006.
-- Positions are filled only through position_history inserts (triggers set users/positions).

BEGIN;

INSERT INTO companies (name) VALUES ('Acme Corp');                                  -- company 1

INSERT INTO ranks (company_id, name, rank_order) VALUES
  (1, 'Executive', 1),
  (1, 'Manager',   2),
  (1, 'Staff',     3);

INSERT INTO departments (company_id, name, is_active) VALUES
  (1, 'Management',  TRUE),                                                          -- 1
  (1, 'Sales',       TRUE),                                                          -- 2
  (1, 'Engineering', TRUE);                                                          -- 3

-- one seat per position; same job = several positions with the same name
INSERT INTO positions (company_id, department_id, name, rank_id, parent_position_id, is_active) VALUES
  (1, 1, 'CEO',                 1, NULL, TRUE),                                      -- 1
  (1, 2, 'Head of Sales',       2, 1,    TRUE),                                      -- 2
  (1, 3, 'Head of Engineering', 2, 1,    TRUE),                                      -- 3
  (1, 2, 'Sales Associate',     3, 2,    TRUE),                                      -- 4
  (1, 2, 'Sales Associate',     3, 2,    TRUE),                                      -- 5
  (1, 3, 'Engineer',            3, 3,    TRUE),                                      -- 6
  (1, 3, 'Engineer',            3, 3,    TRUE),                                      -- 7 (ends vacant)
  (1, 3, 'Trainee Seat',        3, 3,    TRUE),                                      -- 8
  (1, 3, 'Legacy Role',         3, 3,    FALSE),                                     -- 9 (inactive)
  (1, 3, 'Engineer',            3, 3,    TRUE);                                      -- 10

-- everyone starts without a position; placement happens via position_history
INSERT INTO users (company_id, employee_no, first_name, last_name, birth_date, start_date, user_status) VALUES
  (1, 'E001', 'Mina', 'Kim',  '1975-03-02', '2015-01-05', 'waiting_position'),       -- 1 CEO
  (1, 'E002', 'Jun',  'Lee',  '1982-07-19', '2017-03-01', 'waiting_position'),       -- 2 Head of Sales
  (1, 'E003', 'Sora', 'Park', '1984-11-30', '2018-06-11', 'waiting_position'),       -- 3 Head of Engineering
  (1, 'E004', 'Hana', 'Choi', '1993-02-14', '2021-09-01', 'waiting_position'),       -- 4 Sales Associate
  (1, 'E005', 'Tae',  'Kang', '1995-05-05', '2022-01-10', 'waiting_position'),       -- 5 Sales Associate
  (1, 'E006', 'Yuna', 'Jung', '1994-08-21', '2020-04-01', 'waiting_position'),       -- 6 Engineer (moved 7 -> 6)
  (1, 'E007', 'Min',  'Seo',  '2001-12-01', '2026-09-01', 'in_training'),            -- 7 trainee with a seat
  (1, 'E008', 'Ara',  'Han',  '2002-04-09', '2026-10-01', 'in_training'),            -- 8 trainee without a seat
  (1, 'E009', 'Dae',  'Yoon', '1990-01-25', '2019-02-01', 'waiting_position'),       -- 9 leaves
  (1, 'E010', 'Ji',   'Oh',   '1991-10-10', '2019-07-15', 'waiting_position');       -- 10 suspended later

-- placements
INSERT INTO position_history (company_id, user_id, position_id, start_date) VALUES
  (1, 1, 1, '2015-01-05'),
  (1, 2, 2, '2017-03-01'),
  (1, 3, 3, '2018-06-11'),
  (1, 4, 4, '2021-09-01'),
  (1, 5, 5, '2022-01-10'),
  (1, 6, 7, '2020-04-01'),
  (1, 7, 8, '2026-09-01'),
  (1, 10, 10, '2019-07-15');

-- user 6 moves from position 7 to position 6
UPDATE position_history SET end_date = '2023-03-31', end_reason = 'position_changed'
WHERE company_id = 1 AND user_id = 6 AND end_date IS NULL;
INSERT INTO position_history (company_id, user_id, position_id, start_date) VALUES (1, 6, 6, '2023-04-01');

-- user 9 takes position 7, then leaves the company
INSERT INTO position_history (company_id, user_id, position_id, start_date) VALUES (1, 9, 7, '2023-04-01');
UPDATE position_history SET end_date = '2025-12-31', end_reason = 'left'
WHERE company_id = 1 AND user_id = 9 AND end_date IS NULL;

-- user 10 is suspended (disciplinary) while keeping the seat
UPDATE users SET user_status = 'suspended' WHERE company_id = 1 AND id = 10;

INSERT INTO task_types (name, parent_task_type_id) VALUES
  ('Research', NULL),                                                                -- 1
  ('Market Research', 1),                                                            -- 2
  ('Development', NULL),                                                             -- 3
  ('Point Correction', NULL);                                                        -- 4

INSERT INTO goal_templates (company_id, name, task_type_id, description, estimate_days_needed, min_point_worth, max_point_worth) VALUES
  (1, 'Market report', 2, 'Short market report for one segment', 5, 10, 30);         -- 1

INSERT INTO goals (company_id, name, task_type_id, goal_tier, description, parent_goal_id, created_by_position_id, created_by_user_id, due_date, points_worth, referenced_template_id) VALUES
  (1, 'Q4 sales strategy',      1, 1, 'Plan Q4 sales targets',      NULL, 1, 1, '2026-12-31', 50, NULL),  -- 1
  (1, 'Compile candidate list', 2, 2, 'Prospects for Q4',           1,    2, 2, '2026-11-15', 20, 1),     -- 2
  (1, 'Build login page',       3, 2, 'New login page',             NULL, 3, 3, '2026-11-30', 30, NULL),  -- 3
  (1, 'Write API tests',        3, 3, 'Tests for auth API',         3,    3, 3, '2026-11-20', 10, NULL),  -- 4
  (1, 'Fix typo in docs',       3, 3, 'Small docs fix for trainee', NULL, 3, 3, '2026-10-30', 5,  NULL);  -- 5

INSERT INTO goal_assignments (company_id, goal_id, issued_at, issued_by_position_id, issued_by_user_id, assigned_position_id, assigned_user_id, completed_at, goal_status) VALUES
  (1, 1, '2026-10-01', 1, 1, 2, 2, NULL,         'in_progress'),                     -- 1
  (1, 2, '2026-10-02', 2, 2, 4, 4, '2026-10-10', 'complete'),                        -- 2
  (1, 3, '2026-10-03', 3, 3, 6, 6, NULL,         'reported'),                        -- 3
  (1, 4, '2026-10-03', 3, 3, 6, 6, '2026-10-12', 'complete'),                        -- 4
  (1, 5, '2026-10-05', 3, 3, 8, 7, NULL,         'in_progress');                     -- 5

INSERT INTO goal_events (company_id, goal_assignment_id, actor_user_id, event_time, event_type) VALUES
  (1, 1, 1, '2026-10-01', 'assigned'),
  (1, 2, 2, '2026-10-02', 'assigned'),
  (1, 2, 4, '2026-10-09', 'reported'),
  (1, 2, 2, '2026-10-10', 'approved'),
  (1, 3, 3, '2026-10-03', 'assigned'),
  (1, 3, 6, '2026-10-14', 'reported'),
  (1, 4, 3, '2026-10-03', 'assigned'),
  (1, 4, 6, '2026-10-11', 'reported'),
  (1, 4, 3, '2026-10-12', 'approved'),
  (1, 5, 3, '2026-10-05', 'assigned');

INSERT INTO rewards (company_id, name, points_needed, description, created_by_user_id, limit_type, limit_number, is_active) VALUES
  (1, 'Extra day off',   30, 'One extra paid day off',  1, 'monthly',   1,    TRUE),   -- 1
  (1, 'Remote work day',  5, 'Work from home one day',  1, 'weekly',    2,    TRUE),   -- 2
  (1, 'Old perk',        10, 'Discontinued perk',       1, 'limitless', NULL, FALSE);  -- 3

INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, related_goal_assignment_id, reward_id) VALUES
  (1, 4, 'gain',       20, 'Completed: Compile candidate list', 2,    NULL),
  (1, 6, 'gain',       10, 'Completed: Write API tests',        4,    NULL),
  (1, 4, 'usage',      -5, 'Used: Remote work day',             NULL, 2),
  (1, 6, 'adjustment', -2, 'Correction: double-counted bonus',  NULL, NULL);

COMMIT;
