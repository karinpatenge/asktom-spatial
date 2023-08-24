!cls
set sqlformat ansiconsole
set serveroutput on
set echo on

-- Turn VPA on
alter session set spatial_vector_acceleration = false;
show parameter spatial_vector_acceleration;

set echo off
set serveroutput off
