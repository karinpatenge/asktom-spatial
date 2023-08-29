set define off
set sqlblanklines on
set serveroutput on
set echo on

----------------------
-- Simplify geometries
----------------------
with test as
( select * from gadm_fra_level2 where rownum <= 10)
select
  g.name_2 as name,
  sdo_util.getnumvertices(geom) num_vertices_geom,
  sdo_util.getnumvertices(
    sdo_util.simplify(
      geom,
      60,  -- Threshold Douglas-Peucker algorithm (positive number)
      0.05)) num_vertices_simplified_dp,
  sdo_util.getnumvertices(
    sdo_util.simplifyvw(
      geom,
      60,  -- Threshold Visvalingham-Whyatt algorithm (values between 0 and 100)
      0.05)) num_vertices_simplified_vw
from test g;


set echo off
set timing off