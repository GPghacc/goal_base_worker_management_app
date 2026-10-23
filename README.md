# goal_base_worker_management_app

PostgreSQL schema for a quest-style workplace task app: managers issue goals, workers complete and report them, and approved work earns points (spendable on rewards) and experience.

## Layout

```
migrations/   schema, run in numeric order on an empty database
  001_company_structure.sql   companies, departments, ranks, positions
  002_users.sql               users, position_history
  003_goals.sql               task_types, goal_templates, goals, goal_assignments, goal_events
  004_points_and_rewards.sql  rewards, point_events
  005_triggers.sql            ledger rules, point validation, position change flow
  006_views.sql               views used by the app screens
tests/
  seed.sql                    sample company data (run once on a fresh schema)
  tests.sql                   checks for constraints, triggers and views
```

## Running

Build the schema on an empty database:

```
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f migrations/001_company_structure.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f migrations/002_users.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f migrations/003_goals.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f migrations/004_points_and_rewards.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f migrations/005_triggers.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f migrations/006_views.sql
```

Then, on a test database only:

```
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/seed.sql
psql "$DATABASE_URL" -f tests/tests.sql
```

`tests.sql` runs every check inside its own rolled-back subtransaction, so the seed data is left unchanged. The last row of output is a pass/fail summary.
