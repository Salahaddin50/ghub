-- First, let's identify any custom triggers on the steps and obstacles tables
DO $$ 
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN 
        SELECT t.tgname, t.tgrelid::regclass as table_name
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname IN ('steps', 'obstacles')
        AND NOT EXISTS (
            SELECT 1 
            FROM pg_constraint con 
            WHERE con.conrelid = t.tgrelid 
            AND t.tgname LIKE 'RI_ConstraintTrigger_%'
        )
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I', 
                      trigger_record.tgname, 
                      trigger_record.table_name);
        RAISE NOTICE 'Dropped trigger % on table %', 
                    trigger_record.tgname, 
                    trigger_record.table_name;
    END LOOP;
END $$;

-- Check and remove any RLS policies that might reference updated_at
DO $$ 
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname, tablename
        FROM pg_policies 
        WHERE tablename IN ('steps', 'obstacles')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', 
                      policy_record.policyname, 
                      policy_record.tablename);
        RAISE NOTICE 'Dropped policy % on table %', 
                    policy_record.policyname, 
                    policy_record.tablename;
    END LOOP;
END $$;

-- Let's check for any updated_at references in functions
DO $$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN
        SELECT p.proname, n.nspname
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
        AND p.prosrc LIKE '%updated_at%'
    LOOP
        RAISE NOTICE 'Function % in schema % contains updated_at reference',
                    func_record.proname,
                    func_record.nspname;
    END LOOP;
END $$;

-- Re-create necessary RLS policies for steps
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for authenticated users"
ON steps FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable insert access for authenticated users"
ON steps FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users"
ON steps FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Enable delete access for authenticated users"
ON steps FOR DELETE
TO authenticated
USING (true);

-- Re-create necessary RLS policies for obstacles
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for authenticated users"
ON obstacles FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable insert access for authenticated users"
ON obstacles FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users"
ON obstacles FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Enable delete access for authenticated users"
ON obstacles FOR DELETE
TO authenticated
USING (true);
