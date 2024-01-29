-----------------
-- Create DB user
-----------------

-- Log into your DB instance as user with SYS/SYSDBA privileges
-- or as user ADMIN (in case of Autonomous DB).

-- Create user
create user asktom identified by Welcome_123#;

-- Grant default permissions
grant create session, resource, connect to asktom;

-- Assign quota
-- Note: For Autonomous Databases the default tablespace is DATA
alter user asktom quota unlimited on data;