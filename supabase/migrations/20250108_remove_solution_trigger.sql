-- Drop the trigger and function that tries to set user_id
DROP TRIGGER IF EXISTS set_solution_defaults_trigger ON solutions;
DROP FUNCTION IF EXISTS set_solution_defaults() CASCADE; 