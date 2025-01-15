-- First, ensure the trigger is removed
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Create a more robust function for handling new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    -- Ensure we have the minimum required data
    IF NEW.email IS NULL THEN
        RAISE LOG 'Cannot create user: email is null for user %', NEW.id;
        RETURN NEW;
    END IF;

    -- Insert the new user with all available data
    INSERT INTO public.users (
        id,
        email,
        name,
        created_at
    ) VALUES (
        NEW.id,
        NEW.email,
        COALESCE(
            NEW.raw_user_meta_data->>'name',
            split_part(NEW.email, '@', 1)
        ),
        COALESCE(NEW.created_at, now())
    )
    ON CONFLICT (id) DO UPDATE
    SET
        email = EXCLUDED.email,
        name = EXCLUDED.name,
        updated_at = now();

    RAISE LOG 'Successfully created/updated user with id: % and email: %', NEW.id, NEW.email;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Error in handle_new_user trigger: %', SQLERRM;
    RAISE LOG 'Error details - ID: %, Email: %, Raw Meta: %', NEW.id, NEW.email, NEW.raw_user_meta_data;
    RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Sync all existing users
DO $$
DECLARE
    auth_user RECORD;
    counter INTEGER := 0;
    success INTEGER := 0;
    failed INTEGER := 0;
BEGIN
    FOR auth_user IN (SELECT * FROM auth.users) LOOP
        BEGIN
            INSERT INTO public.users (
                id,
                email,
                name,
                created_at
            ) VALUES (
                auth_user.id,
                auth_user.email,
                COALESCE(
                    auth_user.raw_user_meta_data->>'name',
                    split_part(auth_user.email, '@', 1)
                ),
                COALESCE(auth_user.created_at, now())
            )
            ON CONFLICT (id) DO UPDATE
            SET
                email = EXCLUDED.email,
                name = EXCLUDED.name,
                updated_at = now();
            
            success := success + 1;
        EXCEPTION WHEN OTHERS THEN
            failed := failed + 1;
            RAISE LOG 'Failed to sync user: % - %', auth_user.id, SQLERRM;
        END;
        counter := counter + 1;
    END LOOP;
    
    RAISE LOG 'User sync completed. Total: %, Success: %, Failed: %', counter, success, failed;
END;
$$; 