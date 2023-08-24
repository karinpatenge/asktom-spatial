
/*
 * Check if parameter for Vector Performance Accelerator is set to TRUE.
 * Default for 12c-19c is FALSE, for 21c and higher it is TRUE.
 * Default for Autonomous Database is TRUE.
 *
 * Demo environment:
 * - DBCS 19c
 * - spatialuser@localhost:1521/pdb1.sub03231001460.sgvcn.oraclevcn.com
 */

!cls
set serveroutput on
set sqlformat ansiconsole
set echo on
/******************* Begin: 01_vpa.sql **************************/

show user;

show parameter spatial_vector_acceleration;

-- If FALSE, set it to TRUE as user with SYSDBA privileges.
-- alter system set spatial_vector_acceleration=true scope=both;

-- If you are granted with ALTER SESSION privileges, set it TRUE for the session
alter session set spatial_vector_acceleration=true;

-- Verify the result
show parameter spatial_vector_acceleration;

/******************* End: 01_vpa.sql ****************************/
