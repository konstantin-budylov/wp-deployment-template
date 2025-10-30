-- MySQL initialization script
-- Create databases
CREATE DATABASE IF NOT EXISTS test CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Create test user with password
CREATE USER IF NOT EXISTS 'test'@'%' IDENTIFIED BY 'test123';

-- Grant privileges to test user
GRANT ALL PRIVILEGES ON test.* TO 'test'@'%';

-- Flush privileges to apply changes
FLUSH PRIVILEGES;
