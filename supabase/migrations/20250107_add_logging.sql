-- Enable logging for policy checks
CREATE OR REPLACE FUNCTION log_policy_check()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Policy check for user % on table %', auth.uid(), TG_TABLE_NAME;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add logging triggers for steps and obstacles
CREATE TRIGGER log_steps_policy_check
    BEFORE SELECT ON steps
    FOR EACH ROW EXECUTE FUNCTION log_policy_check();

CREATE TRIGGER log_obstacles_policy_check
    BEFORE SELECT ON obstacles
    FOR EACH ROW EXECUTE FUNCTION log_policy_check(); 