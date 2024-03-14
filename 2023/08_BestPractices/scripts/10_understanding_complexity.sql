-------------------------------------------------------------------------
-- Oracle Spatial Workshop
-- labs\04-loading\03_checks_and_validate\10_understanding_complexity.sql
--
-- Author: Albert Godfrind
-- Last revision: Karin Patenge, Feb 2024
-------------------------------------------------------------------------

-- Check number of points and size of geometries in bytes
-- IMPORTANT: the VSIZE function caps the result out to 32k (32766). So the MAX and SUM results for size for the US_PARKS is wrong
select count(*) as num_geom,
  sum(num_points), min(num_points), max(num_points), round(avg(num_points)), median(num_points),
  sum(bytes), min(bytes), max(bytes), round(avg(bytes)), round(median(bytes))
from (
  select sdo_util.getnumvertices(geom) as num_points, vsize(geom) as bytes
  from us_counties
);

create or replace view us_parks_s as
select name, fcc, sdo_util.simplify(geom, 10, 0.005) as geom, id from us_parks;

select count(*) as num_geom,
  sum(num_points), min(num_points), max(num_points), round(avg(num_points)), median(num_points),
  sum(bytes), min(bytes), max(bytes), round(avg(bytes)), round(median(bytes))
from (
  select sdo_util.getnumvertices(geom) as num_points, vsize(geom) as bytes
  from us_parks_s
);

-- Check number of points distribution by percentiles
select count(*) as num_geom,
  min(num_points) as min, max(num_points) as max, round(avg(num_points)) as avg, median(num_points) as median,
  percentile_disc(0.90) WITHIN GROUP (ORDER BY num_points ASC) as pct90,
  percentile_disc(0.95) WITHIN GROUP (ORDER BY num_points ASC) as pct95,
  percentile_disc(0.99) WITHIN GROUP (ORDER BY num_points ASC) as pct99
from (
  select sdo_util.getnumvertices(geom) as num_points
  from us_parks
);
