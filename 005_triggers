-- Quest Format Goals app DB
-- 005_triggers
-- trigger functions to work on data updates and setting limitations between tables

BEGIN;


--updates current points and exp when point event occurs for the user
CREATE OR REPLACE FUNCTION update_user_current_points_and_exp()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $$
  BEGIN

    IF NEW.reward_id IS NULL THEN
      UPDATE users SET current_points = current_points + NEW.point_amount, total_exp = total_exp + NEW.point_amount WHERE company_id = NEW.company_id AND id = NEW.point_event_user_id;
    ELSE
      UPDATE users SET current_points = current_points + NEW.point_amount WHERE company_id = NEW.company_id AND id = NEW.point_event_user_id;
    END IF;

    RETURN NULL;
  
  END;
  $$;
--users current point and exp are updated on point event
CREATE OR REPLACE TRIGGER trg_update_user_current_points_and_exp
  AFTER INSERT
  ON point_events
  FOR EACH ROW
  EXECUTE FUNCTION update_user_current_points_and_exp();

--general rule for events are append only.
CREATE OR REPLACE FUNCTION disallow_update_or_delete()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $$
  BEGIN
    RAISE EXCEPTION 'Cannot % %. Table is append only', TG_OP, TG_TABLE_NAME ;
    RETURN NULL;
  END;
  $$;

--point_events are final after they go through validity check on insert. 
CREATE OR REPLACE TRIGGER trg_disallow_point_event_update_or_delete
  BEFORE UPDATE OR DELETE
  ON point_events
  FOR EACH ROW
  EXECUTE FUNCTION disallow_update_or_delete();

--goal events are final and cannot be deleted or updated
CREATE OR REPLACE TRIGGER trg_disallow_goal_event_update_or_delete
  BEFORE UPDATE OR DELETE
  ON goal_events
  FOR EACH ROW
  EXECUTE FUNCTION disallow_update_or_delete();

--position history should not be deleted
CREATE OR REPLACE TRIGGER trg_disallow_position_history_delete
  BEFORE DELETE
  ON position_history
  FOR EACH ROW
  EXECUTE FUNCTION disallow_update_or_delete();

--only allows update on end_date that is nulled and end_reason follows from constraint on table
CREATE OR REPLACE FUNCTION limit_position_history_update()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $$
  BEGIN
    IF (OLD.company_id IS DISTINCT FROM NEW.company_id) 
    OR (OLD.id IS DISTINCT FROM NEW.id) OR (OLD.position_id IS DISTINCT FROM NEW.position_id) 
    OR (OLD.user_id IS DISTINCT FROM NEW.user_id) OR (OLD.start_date IS DISTINCT FROM NEW.start_date) 
    OR (OLD.end_date IS NOT NULL) THEN
      RAISE EXCEPTION 'Cannot % %. Only closing an open row is allowed.', TG_OP, TG_TABLE_NAME ;
    ELSIF (NEW.end_date IS NULL) THEN
      RAISE EXCEPTION 'Have to close position on update';
    END IF;
    RETURN NEW;
    
  END;
  $$;

CREATE OR REPLACE TRIGGER trg_limit_position_history_update
  BEFORE UPDATE
  ON position_history
  FOR EACH ROW
  EXECUTE FUNCTION limit_position_history_update();



--checks if the gaining point event is valid by checking goal state is complete and the point amount is correct
--checks if the usage of point event is valid by checking if reward is usable and the amount is correct
CREATE OR REPLACE FUNCTION point_events_validity_check()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $$
  DECLARE
    v_assignment_goal_status TEXT;
    v_goal_points_worth INT;
    v_assignment_assigned_user_id BIGINT;
    v_reward_price INT;
    v_reward_status BOOLEAN;
  BEGIN
    IF NEW.point_action = 'gain' THEN
      SELECT ga.goal_status, ga.assigned_user_id, g.points_worth
      INTO v_assignment_goal_status, v_assignment_assigned_user_id, v_goal_points_worth
      FROM goal_assignments ga
      JOIN goals g
      ON g.company_id = ga.company_id AND g.id = ga.goal_id
      WHERE ga.company_id = NEW.company_id AND ga.id = NEW.related_goal_assignment_id;


      IF (v_assignment_goal_status <> 'complete') THEN
        RAISE EXCEPTION 'Cannot gain points from incomplete goal';
      END IF;
      IF (v_goal_points_worth <> NEW.point_amount) THEN
        RAISE EXCEPTION 'Gained point amount does not match the goal worth';
      END IF;
      IF (v_assignment_assigned_user_id <> NEW.point_event_user_id) THEN
        RAISE EXCEPTION 'Gaining user_id does not match user_id that the goal was assigned to';
      END IF;
    ELSIF NEW.point_action = 'usage' THEN
      SELECT r.points_needed, r.is_active
      INTO v_reward_price, v_reward_status
      FROM rewards r
      WHERE r.company_id = NEW.company_id AND r.id = NEW.reward_id;

      IF NOT v_reward_status THEN
        RAISE EXCEPTION 'Cannot use points on inactive rewards';
      END IF;
      IF (NEW.point_amount <> (-(v_reward_price))) THEN
        RAISE EXCEPTION 'reward price and usage price mismatch';
      END IF;      
    END IF;
    RETURN NEW;
  END;
  $$;

--validity check for point_event comes before insert 
CREATE OR REPLACE TRIGGER trg_point_events_validity_check
  BEFORE INSERT
  ON point_events
  FOR EACH ROW
  EXECUTE FUNCTION point_events_validity_check();





--trg_limit_position_history_update only allows update on nulled end_date and reason.
--which means when it is updated, the user in that position is done in that position.
--needs to open that position, and nullify the user's position id. 
--filling position only happens by insert therefore no need to consider that here.
--may need to update user status options for waiting for new position and waiting to retire or leave in future
CREATE OR REPLACE FUNCTION position_and_users_update_on_position_history_update()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $$
  BEGIN
    UPDATE positions SET is_filled = FALSE WHERE company_id = NEW.company_id AND id = NEW.position_id;

    IF NEW.end_reason IN ('retired', 'left') THEN
      UPDATE users SET end_date = NEW.end_date, user_status = NEW.end_reason, position_id = NULL WHERE company_id = NEW.company_id AND id = NEW.user_id;
    ELSE
      UPDATE users SET position_id = NULL, user_status = 'waiting_position' WHERE company_id = NEW.company_id AND id = NEW.user_id;
    END IF;

    RETURN NEW;
  END;
  $$;

CREATE OR REPLACE TRIGGER trg_position_and_users_update_on_position_history_update
  AFTER UPDATE
  ON position_history
  FOR EACH ROW
  EXECUTE FUNCTION position_and_users_update_on_position_history_update();


CREATE OR REPLACE FUNCTION user_update_on_position_history_insert()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $$
  DECLARE
    v_position_is_active BOOLEAN;
    v_position_is_filled BOOLEAN;
    v_user_status TEXT;
    v_user_position_id BIGINT;
  BEGIN
    IF NEW.end_date IS NOT NULL THEN 
      RAISE EXCEPTION 'Cannot insert closed position record';
    END IF;

    SELECT p.is_active, p.is_filled
    INTO v_position_is_active, v_position_is_filled
    FROM positions p
    WHERE p.company_id = NEW.company_id AND p.id = NEW.position_id;

    IF NOT v_position_is_active THEN
      RAISE EXCEPTION 'Cannot fill closed position';
    END IF;
  
    IF v_position_is_filled THEN
      RAISE EXCEPTION 'position is already filled';
    END IF;   
  

    SELECT u.user_status, u.position_id
    INTO v_user_status, v_user_position_id
    FROM users u
    WHERE u.company_id = NEW.company_id AND u.id = NEW.user_id;
  
    IF v_user_status NOT IN ('in_training', 'waiting_position') THEN
      RAISE EXCEPTION 'user status not fit for new position';
    ELSIF v_user_status = 'in_training' THEN
      IF v_user_position_id IS NOT NULL THEN
        RAISE EXCEPTION 'user in training already has position';
      END IF;
      UPDATE users SET position_id = NEW.position_id, user_status = 'in_training' WHERE company_id = NEW.company_id AND id = NEW.user_id;  
    ELSE
      UPDATE users SET position_id = NEW.position_id, user_status = 'working' WHERE company_id = NEW.company_id AND id = NEW.user_id;
    END IF;

    UPDATE positions SET is_filled = TRUE WHERE company_id = NEW.company_id AND id = NEW.position_id;
  
    RETURN NEW;
  END;
  $$;

CREATE OR REPLACE TRIGGER trg_user_update_on_position_history_insert
  AFTER INSERT
  ON position_history
  FOR EACH ROW
  EXECUTE FUNCTION user_update_on_position_history_insert();


COMMIT;
