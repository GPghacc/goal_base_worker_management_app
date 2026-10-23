-- Quest Format Goals app DB
-- 006_views
-- views that are convinient or needed for usage

BEGIN;

CREATE VIEW user_history AS
SELECT 
  ph.company_id,
  d.id AS department_id,
  p.id AS position_id,
  u.id AS user_id,
  u.employee_no,
  u.first_name || ' ' || u.last_name AS user_name, 
  d.name AS department_name, 
  p.name AS position_name, 
  ph.start_date AS position_start_date, 
  ph.end_date AS position_end_date, 
  ph.end_reason AS end_reason
FROM position_history ph
JOIN users u
  ON u.company_id = ph.company_id AND u.id = ph.user_id
JOIN positions p
  ON p.company_id = ph.company_id AND p.id = ph.position_id
JOIN departments d
  ON d.company_id = ph.company_id AND d.id = p.department_id;


CREATE VIEW goal_assignment_specifics AS
SELECT
  ga.company_id,
  ga.id AS goal_assignment_id,
  ga.goal_id,
  g.name AS goal_name,
  ga.issued_by_user_id,
  pi.id AS issued_by_position_id,
  ui.first_name || ' ' || ui.last_name AS issued_by_user_name,
  pa.id AS assigned_position_id,
  ga.assigned_user_id,
  ua.first_name || ' ' || ua.last_name AS assigned_user_name,
  ga.issued_at,
  g.due_date,
  ga.completed_at,
  ga.goal_status,
  g.points_worth
FROM goal_assignments ga
JOIN goals g
  ON g.company_id = ga.company_id AND g.id = ga.goal_id
JOIN users ui
  ON ui.company_id = ga.company_id AND ui.id = ga.issued_by_user_id
JOIN positions pi
  ON pi.company_id = ga.company_id AND pi.id = ga.issued_by_position_id
JOIN users ua
  ON ua.company_id = ga.company_id AND ua.id = ga.assigned_user_id
JOIN positions pa
  ON pa.company_id = ga.company_id AND pa.id = ga.assigned_position_id;
  

CREATE VIEW user_info AS
SELECT
  u.company_id,
  u.id AS user_id,
  u.first_name || ' ' || u.last_name AS user_name,
  u.employee_no,
  u.position_id,
  p.name AS position_name,
  p.department_id,
  d.name AS department_name,
  u.start_date,
  u.end_date,
  u.user_status,
  u.current_points,
  u.total_exp
FROM users u
LEFT JOIN positions p
  ON p.company_id = u.company_id AND p.id = u.position_id
LEFT JOIN departments d
  ON d.company_id = u.company_id AND d.id = p.department_id;


CREATE VIEW point_events_user_view AS
SELECT
  pe.company_id,
  pe.id AS point_event_id,
  pe.point_event_user_id AS user_id,
  u.first_name || ' ' || u.last_name AS user_name,
  pe.event_time,
  pe.point_action,
  pe.point_amount,
  pe.description,
  pe.related_goal_assignment_id,
  g.name AS goal_name,
  pe.reward_id,
  r.name AS reward_name
FROM point_events pe
JOIN users u
  ON u.company_id = pe.company_id AND u.id = pe.point_event_user_id
LEFT JOIN goal_assignments ga
  ON ga.company_id = pe.company_id AND ga.id = pe.related_goal_assignment_id
LEFT JOIN goals g
  ON g.company_id = pe.company_id AND g.id = ga.goal_id
LEFT JOIN rewards r
  ON r.company_id = pe.company_id AND r.id = pe.reward_id;



CREATE VIEW positions_with_direct_supervisor AS
SELECT
  p.company_id,
  p.id AS position_id,
  p.name AS position_name,
  p.department_id,
  d.name AS department_name,
  ps.id AS superior_position_id,
  ps.name AS superior_position_name,
  p.is_active,
  p.is_filled,
  u.id AS current_in_position_user_id,
  u.first_name || ' ' || u.last_name AS current_in_position_user_name
FROM positions p
JOIN departments d 
  ON d.company_id = p.company_id AND d.id = p.department_id
LEFT JOIN positions ps
  ON ps.company_id = p.company_id AND ps.id = p.parent_position_id
LEFT JOIN users u
  ON u.company_id = p.company_id AND u.position_id = p.id;


  
  
  



COMMIT;
