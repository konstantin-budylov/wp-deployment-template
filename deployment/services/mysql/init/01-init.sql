-- MySQL initialization script
-- Create databases
CREATE DATABASE IF NOT EXISTS wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Create test user with password
CREATE USER IF NOT EXISTS 'wp'@'%' IDENTIFIED BY 'wp_pass';

-- Grant privileges to test user
GRANT ALL PRIVILEGES ON wordpress.* TO 'wp'@'%';

-- Flush privileges to apply changes
FLUSH PRIVILEGES;
