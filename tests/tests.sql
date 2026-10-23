-- Test suite for the schema built from 001-006, run on top of tests/seed.sql.
-- Every test runs inside its own subtransaction and is rolled back, so the seed data is never changed.
-- t(name, statements, expected_error, check_query, expected_value)
--   expected_error: substring of the error message, or NULL if the statements should succeed
--   check_query:    optional query returning one text value, compared with expected_value after success

CREATE TEMP TABLE test_results (n serial, name text, pass boolean, detail text);

CREATE FUNCTION pg_temp.t(p_name text, p_sql text, p_err text, p_check text DEFAULT NULL, p_want text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_got text;
BEGIN
  BEGIN
    EXECUTE p_sql;
    IF p_check IS NOT NULL THEN
      EXECUTE p_check INTO v_got;
    END IF;
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = coalesce(v_got, '');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = 'P0099' THEN
      v_got := SQLERRM;
      IF p_err IS NOT NULL THEN
        INSERT INTO test_results(name, pass, detail) VALUES (p_name, FALSE, 'expected error "' || p_err || '" but succeeded');
      ELSIF p_check IS NOT NULL AND v_got IS DISTINCT FROM p_want THEN
        INSERT INTO test_results(name, pass, detail) VALUES (p_name, FALSE, 'got [' || v_got || '] want [' || p_want || ']');
      ELSE
        INSERT INTO test_results(name, pass, detail) VALUES (p_name, TRUE, coalesce(nullif(v_got, ''), 'ok'));
      END IF;
    ELSE
      IF p_err IS NOT NULL AND position(p_err IN SQLERRM) > 0 THEN
        INSERT INTO test_results(name, pass, detail) VALUES (p_name, TRUE, 'blocked: ' || SQLERRM);
      ELSE
        INSERT INTO test_results(name, pass, detail) VALUES (p_name, FALSE, 'unexpected error: ' || SQLERRM);
      END IF;
    END IF;
  END;
END;
$$;

-- ===== seed sanity =====
SELECT pg_temp.t('S1 seed: balances of user 4 and 6', 'SELECT 1', NULL,
  $q$SELECT string_agg(id || ':' || current_points || '/' || total_exp, ' ' ORDER BY id) FROM users WHERE id IN (4, 6)$q$, '4:15/20 6:8/8');
SELECT pg_temp.t('S2 seed: statuses after placement flow', 'SELECT 1', NULL,
  $q$SELECT string_agg(id || ':' || user_status, ' ' ORDER BY id) FROM users WHERE id IN (6, 7, 8, 9, 10)$q$,
  '6:working 7:in_training 8:in_training 9:left 10:suspended');
SELECT pg_temp.t('S3 seed: vacant positions are 7 and 9', 'SELECT 1', NULL,
  $q$SELECT string_agg(id::text, ',' ORDER BY id) FROM positions WHERE NOT is_filled$q$, '7,9');

-- ===== CHECK constraints =====
SELECT pg_temp.t('C1 goal_templates min > max',
  $q$INSERT INTO goal_templates (company_id, name, task_type_id, estimate_days_needed, min_point_worth, max_point_worth) VALUES (1, 'bad', 1, 1, 40, 10)$q$,
  'ck_goal_template_mix_less_than_max_points');
SELECT pg_temp.t('C2 goals negative points_worth',
  $q$INSERT INTO goals (company_id, name, task_type_id, goal_tier, created_by_position_id, created_by_user_id, points_worth) VALUES (1, 'bad', 3, 3, 3, 3, -1)$q$,
  'ck_goals_point_worth_not_negative');
SELECT pg_temp.t('C3 goals zero points_worth allowed',
  $q$INSERT INTO goals (company_id, name, task_type_id, goal_tier, created_by_position_id, created_by_user_id, points_worth) VALUES (1, 'zero', 3, 3, 3, 3, 0)$q$,
  NULL);
SELECT pg_temp.t('C4 removed status on_vacation',
  $q$UPDATE users SET user_status = 'on_vacation' WHERE id = 2$q$, 'ck_users_status');
SELECT pg_temp.t('C5 working user without position',
  $q$UPDATE users SET position_id = NULL WHERE id = 2$q$, 'ck_users_position_by_status');
SELECT pg_temp.t('C6 waiting_position user with a position',
  $q$UPDATE users SET user_status = 'waiting_position' WHERE id = 2$q$, 'ck_users_position_by_status');
SELECT pg_temp.t('C7 old action name penalized',
  $q$INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description) VALUES (1, 4, 'penalized', -1, 'x')$q$,
  'ck_point_events_point_actions');
SELECT pg_temp.t('C8 inactive position marked filled',
  $q$UPDATE positions SET is_filled = TRUE WHERE id = 9$q$, 'ck_invalid_position_active');

-- ===== points =====
SELECT pg_temp.t('P1 valid gain updates points and exp',
  $q$UPDATE goal_assignments SET goal_status = 'complete', completed_at = now() WHERE id = 5;
     INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, related_goal_assignment_id) VALUES (1, 7, 'gain', 5, 'x', 5)$q$,
  NULL, $q$SELECT current_points || '/' || total_exp FROM users WHERE id = 7$q$, '5/5');
SELECT pg_temp.t('P2 gain on in_progress assignment',
  $q$INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, related_goal_assignment_id) VALUES (1, 2, 'gain', 50, 'x', 1)$q$,
  'Cannot gain points from incomplete goal');
SELECT pg_temp.t('P3 gain on reported assignment',
  $q$INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, related_goal_assignment_id) VALUES (1, 6, 'gain', 30, 'x', 3)$q$,
  'Cannot gain points from incomplete goal');
SELECT pg_temp.t('P4 gain amount differs from points_worth',
  $q$UPDATE goal_assignments SET goal_status = 'complete', completed_at = now() WHERE id = 1;
     INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, related_goal_assignment_id) VALUES (1, 2, 'gain', 49, 'x', 1)$q$,
  'Gained point amount does not match the goal worth');
SELECT pg_temp.t('P5 gain to someone other than the assignee',
  $q$UPDATE goal_assignments SET goal_status = 'complete', completed_at = now() WHERE id = 1;
     INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, related_goal_assignment_id) VALUES (1, 3, 'gain', 50, 'x', 1)$q$,
  'Gaining user_id does not match');
SELECT pg_temp.t('P6 second gain for the same assignment',
  $q$INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, related_goal_assignment_id) VALUES (1, 4, 'gain', 20, 'x', 2)$q$,
  'uq_point_events_related_goal_assignment_id');
SELECT pg_temp.t('P7 valid usage lowers points, not exp',
  $q$INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, reward_id) VALUES (1, 4, 'usage', -5, 'x', 2)$q$,
  NULL, $q$SELECT current_points || '/' || total_exp FROM users WHERE id = 4$q$, '10/20');
SELECT pg_temp.t('P8 usage of inactive reward',
  $q$INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, reward_id) VALUES (1, 4, 'usage', -10, 'x', 3)$q$,
  'Cannot use points on inactive rewards');
SELECT pg_temp.t('P9 usage amount differs from reward price',
  $q$INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, reward_id) VALUES (1, 4, 'usage', -4, 'x', 2)$q$,
  'reward price and usage price mismatch');
SELECT pg_temp.t('P10 usage beyond current balance',
  $q$INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description, reward_id) VALUES (1, 4, 'usage', -30, 'x', 1)$q$,
  'ck_users_current_points_not_negative');
SELECT pg_temp.t('P11 adjustment lowers points and exp',
  $q$INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description) VALUES (1, 4, 'adjustment', -3, 'x')$q$,
  NULL, $q$SELECT current_points || '/' || total_exp FROM users WHERE id = 4$q$, '12/17');
SELECT pg_temp.t('P12 positive adjustment',
  $q$INSERT INTO point_events (company_id, point_event_user_id, point_action, point_amount, description) VALUES (1, 4, 'adjustment', 3, 'x')$q$,
  'ck_point_events_gain_not_negative');
SELECT pg_temp.t('P13 update point_events',
  $q$UPDATE point_events SET point_amount = 999 WHERE point_action = 'gain'$q$, 'append only');
SELECT pg_temp.t('P14 delete point_events',
  $q$DELETE FROM point_events$q$, 'append only');
SELECT pg_temp.t('P15 update goal_events',
  $q$UPDATE goal_events SET event_type = 'terminated'$q$, 'append only');

-- ===== position history flow =====
SELECT pg_temp.t('H1 close row as promotion',
  $q$UPDATE position_history SET end_date = current_date, end_reason = 'promotion' WHERE user_id = 4 AND end_date IS NULL$q$,
  NULL, $q$SELECT u.user_status || ' pos=' || coalesce(u.position_id::text, 'NULL') || ' p4filled=' || p.is_filled FROM users u, positions p WHERE u.id = 4 AND p.id = 4$q$,
  'waiting_position pos=NULL p4filled=false');
SELECT pg_temp.t('H2 waiting user takes a vacant seat',
  $q$UPDATE position_history SET end_date = current_date, end_reason = 'promotion' WHERE user_id = 4 AND end_date IS NULL;
     INSERT INTO position_history (company_id, user_id, position_id, start_date) VALUES (1, 4, 7, current_date)$q$,
  NULL, $q$SELECT u.user_status || ' pos=' || u.position_id || ' p7filled=' || p.is_filled FROM users u, positions p WHERE u.id = 4 AND p.id = 7$q$,
  'working pos=7 p7filled=true');
SELECT pg_temp.t('H3 close row as left',
  $q$UPDATE position_history SET end_date = current_date, end_reason = 'left' WHERE user_id = 5 AND end_date IS NULL$q$,
  NULL, $q$SELECT user_status || ' pos=' || coalesce(position_id::text, 'NULL') || ' end=' || (end_date = current_date) FROM users WHERE id = 5$q$,
  'left pos=NULL end=true');
SELECT pg_temp.t('H4 trainee without seat gets first seat',
  $q$INSERT INTO position_history (company_id, user_id, position_id, start_date) VALUES (1, 8, 7, current_date)$q$,
  NULL, $q$SELECT user_status || ' pos=' || position_id FROM users WHERE id = 8$q$, 'in_training pos=7');
SELECT pg_temp.t('H5 trainee who already has a seat',
  $q$INSERT INTO position_history (company_id, user_id, position_id, start_date) VALUES (1, 7, 7, current_date)$q$,
  'user in training already has position');
SELECT pg_temp.t('H6 working user with an open row',
  $q$INSERT INTO position_history (company_id, user_id, position_id, start_date) VALUES (1, 6, 7, current_date)$q$,
  'user status not fit for new position');
SELECT pg_temp.t('H7 occupied position',
  $q$INSERT INTO position_history (company_id, user_id, position_id, start_date) VALUES (1, 8, 1, current_date)$q$,
  'position is already filled');
SELECT pg_temp.t('H8 inactive position',
  $q$INSERT INTO position_history (company_id, user_id, position_id, start_date) VALUES (1, 8, 9, current_date)$q$,
  'Cannot fill closed position');
SELECT pg_temp.t('H9 insert an already closed row',
  $q$INSERT INTO position_history (company_id, user_id, position_id, start_date, end_date, end_reason) VALUES (1, 8, 7, '2020-01-01', '2021-01-01', 'promotion')$q$,
  'Cannot insert closed position record');
SELECT pg_temp.t('H10 change end_reason of a closed row',
  $q$UPDATE position_history SET end_reason = 'promotion' WHERE user_id = 6 AND end_date IS NOT NULL$q$,
  'Only closing an open row is allowed');
SELECT pg_temp.t('H11 update open row without closing it',
  $q$UPDATE position_history SET end_date = NULL WHERE user_id = 2 AND end_date IS NULL$q$,
  'Have to close position on update');
SELECT pg_temp.t('H12 change position_id of an open row',
  $q$UPDATE position_history SET position_id = 7 WHERE user_id = 2 AND end_date IS NULL$q$,
  'Only closing an open row is allowed');
SELECT pg_temp.t('H13 delete position_history',
  $q$DELETE FROM position_history WHERE user_id = 2$q$, 'append only');
SELECT pg_temp.t('H14 suspended user whose row closes goes to waiting',
  $q$UPDATE position_history SET end_date = current_date, end_reason = 'position_changed' WHERE user_id = 10 AND end_date IS NULL$q$,
  NULL, $q$SELECT user_status || ' pos=' || coalesce(position_id::text, 'NULL') FROM users WHERE id = 10$q$, 'waiting_position pos=NULL');

-- ===== views =====
SELECT pg_temp.t('V1 user_info keeps every user', 'SELECT 1', NULL,
  $q$SELECT (SELECT count(*) FROM user_info) || '/' || (SELECT count(*) FROM users) || ' no-seat=' || (SELECT count(*) FROM user_info WHERE position_id IS NULL)$q$,
  '10/10 no-seat=2');
SELECT pg_temp.t('V2 positions view: one row per seat, vacancies shown', 'SELECT 1', NULL,
  $q$SELECT (SELECT count(*) FROM positions_with_direct_supervisor) || '/' || (SELECT count(*) FROM positions) || ' vacant=' || (SELECT count(*) FROM positions_with_direct_supervisor WHERE current_in_position_user_id IS NULL) || ' top=' || (SELECT count(*) FROM positions_with_direct_supervisor WHERE superior_position_id IS NULL)$q$,
  '10/10 vacant=2 top=1');
SELECT pg_temp.t('V3 point events view fills goal/reward by action', 'SELECT 1', NULL,
  $q$SELECT (SELECT count(*) FROM point_events_user_view) || ' ' || (SELECT string_agg(point_action || ':' || (goal_name IS NOT NULL) || '/' || (reward_name IS NOT NULL), ' ' ORDER BY point_action) FROM point_events_user_view)$q$,
  '4 adjustment:false/false gain:true/false gain:true/false usage:false/true');
SELECT pg_temp.t('V4 assignment view: my quests and review queue', 'SELECT 1', NULL,
  $q$SELECT (SELECT count(*) FROM goal_assignment_specifics) || ' mine(u6)=' || (SELECT count(*) FROM goal_assignment_specifics WHERE assigned_user_id = 6) || ' review(u3)=' || (SELECT count(*) FROM goal_assignment_specifics WHERE issued_by_user_id = 3 AND goal_status = 'reported')$q$,
  '5 mine(u6)=2 review(u3)=1');
SELECT pg_temp.t('V5 user_history rows and per-user filter', 'SELECT 1', NULL,
  $q$SELECT (SELECT count(*) FROM user_history) || '/' || (SELECT count(*) FROM position_history) || ' u6=' || (SELECT count(*) FROM user_history WHERE user_id = 6)$q$,
  '10/10 u6=2');

SELECT
  (SELECT count(*) FILTER (WHERE pass) || ' passed / ' || count(*) || ' total' FROM test_results) AS summary,
  (SELECT string_agg(CASE WHEN pass THEN 'PASS ' ELSE 'FAIL ' END || name || ' -- ' || detail, E'\n' ORDER BY n) FROM test_results) AS results;
