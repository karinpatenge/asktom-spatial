!cls
set sqlformat ansiconsole
set serveroutput on
set echo on

-- Check the current VPA parameter setting
show parameter spatial_vector_acceleration;

--
-- Options to set the parameter to TRUE if FALSE:
--

-- Option 1 : As a user with SYSDBA privileges
alter system set spatial_vector_acceleration=true scope=both;

-- Option 2: As a user granted with ALTER SESSION privilege
alter session set spatial_vector_acceleration = true;

-- Verify the result
show parameter spatial_vector_acceleration;

set echo off
set serveroutput off

