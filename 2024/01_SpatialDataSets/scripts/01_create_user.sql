-----------------
-- Create DB user
-----------------

-- Log into your DB instance as user with SYS/SYSDBA privileges
-- or as user ADMIN (in case of Autonomous DB).

-- Create user
create user asktom identified by Welcome_123#;
grant create session, resources, connect to asktom;

