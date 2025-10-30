-- PostgreSQL initialization script
-- Note: The main database is already created by the container (POSTGRES_DB)
-- This script sets up additional configuration for the test database

-- Connect to postgres database first
-- \c postgres;

-- -- Create test database with UTF8 encoding
-- CREATE DATABASE test WITH ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;

-- -- Connect to test database
-- \c test;

-- -- Create test user with password
-- DO $$
-- BEGIN
--   IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'test') THEN
--     CREATE USER test WITH PASSWORD 'test123';
--   END IF;
-- END
-- $$;

-- -- Grant privileges to test user
-- GRANT ALL PRIVILEGES ON DATABASE test TO test;

-- -- Grant schema privileges
-- GRANT ALL ON SCHEMA public TO test;

-- -- Set default privileges for future tables
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO test;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO test;
