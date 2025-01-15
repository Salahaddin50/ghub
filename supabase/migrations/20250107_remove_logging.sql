-- Remove logging triggers
DROP TRIGGER IF EXISTS log_steps_policy_check ON steps;
DROP TRIGGER IF EXISTS log_obstacles_policy_check ON obstacles;

-- Remove the logging function
DROP FUNCTION IF EXISTS log_policy_check; 