!cls
set sqlformat ansiconsole
set serveroutput on
set echo on


-- Determine if the database is in a Multitenant environment (CDB/PDB)
select name, open_mode, con_id
     , decode(cdb,'YES','Multitenant DB','Single instance DB') "CDB/PDB Yes/No?"
  from v$database;

-- For CDB/PDB environment
alter session set container=PDB$SEED;

-- Check if Oracle Spatial database component is valid
select comp_id, status from sys.dba_registry where comp_id = 'SDO';

-- Check if there are invalid database objects
select object_name, object_type, status from dba_objects
 where status = 'INVALID' and owner = 'MDSYS' order by 1,2;

-- If there are invalid objects, follow the instructions in MyOracleSupport
-- "How To Reload Oracle Spatial (SDO)" (Doc ID 2796890.1)


set echo off
set serveroutput off

