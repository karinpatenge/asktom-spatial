-------------------------
-- AskTOM Spatial Series
-- Session: February 2025
--
-- Author: Karin Patenge
-- Date: Feb 2025
-------------------------

------------------------------------------
-- Topic 2: Load GeoJSON using Data Studio
------------------------------------------

-- Drop any existing tables
begin
    for cur in (select * from user_tables where table_name like 'FEB25%')
    loop
        execute immediate ('drop table ' || cur.table_name || ' purge');
    end loop;
end;
/

-- Remove existing SDO metadata for dropped tables
delete from user_sdo_geom_metadata where table_name like 'FEB25%';
commit;

--------------------------------------------------
-- Action: Load new GeoJSON data using Data Studio
--------------------------------------------------



-- Drop data load logging tables
begin
    for cur in (select * from user_tables where table_name like 'COPY$%')
    loop
        execute immediate ('drop table ' || cur.table_name || ' purge');
    end loop;
end;
/

-----------------------
-- Validate loaded data
-----------------------

-- Check geometry types
select distinct b.geometry.sdo_gtype as geom_type from feb25_gadm41_mar_2 b;
select distinct p.geometry.sdo_gtype as geom_type from feb25_ne_110m_populated_places p;

-- Drop table containing validation errors
drop table if exists geometry_errors purge;

-- Create table to contain validation errors
create table if not exists geometry_errors (
  table_name      varchar2(100),
  column_name     varchar2(100),
  obj_rowid       rowid,
  geometry        sdo_geometry,
  tolerance       number,
  error_code      char(5),
  error_message   varchar2(256),
  error_context   varchar2(256)
);

--------------------------
-- Validate geometries
-- Author: Albert Godfrind
--------------------------

-- Clean up any existing errors
truncate table geometry_errors drop storage;

-- Run the validation
declare
  DEFAULT_TOLERANCE   number := 0.005;
  COMMIT_FREQUENCY    number := 100;
  geom_cursor         sys_refcursor;
  v_diminfo           sdo_dim_array;
  v_srid              number;
  v_tolerance         number;
  v_rowid             rowid;
  v_geometry          sdo_geometry;
  v_num_rows          number;
  v_num_errors        number;
  v_error_code        char(5);
  v_error_message     varchar2(256);
  v_error_context     varchar2(256);
  v_status            varchar2(256);

begin
  -- Process all spatial tables
  for t in (
    select table_name, column_name
    from   user_tab_columns
    where  data_type = 'SDO_GEOMETRY'
       and table_name <> 'GEOMETRY_ERRORS'
    order by table_name, column_name
  )
  loop

    -- Get tolerance from the metadata
    begin
      select diminfo, srid
      into   v_diminfo, v_srid
      from   user_sdo_geom_metadata
      where  table_name = t.table_name
         and column_name = t.column_name;
    exception
      when no_data_found then
        v_diminfo := null;
        v_srid := null;
    end;

    -- If no metadata, then use the default tolerance
    if v_diminfo is null then
      v_tolerance := DEFAULT_TOLERANCE;
    else
      v_tolerance := v_diminfo(1).sdo_tolerance;
    end if;

    -- Process the geometries
    v_num_rows := 0;
    v_num_errors := 0;
    open geom_cursor for
      'select rowid,' || t.column_name || ' from ' || t.table_name;
    loop

      v_status := NULL;

      -- Fetch the geometry
      fetch geom_cursor into v_rowid, v_geometry;
        exit when geom_cursor%notfound;
      v_num_rows := v_num_rows + 1;

      if v_geometry is not null then
        -- Validate the geometry
        v_status := sdo_geom.validate_geometry_with_context (v_geometry, v_tolerance);

        -- Log the error (if any)
        if v_status <> 'TRUE' then
          -- Count the errors
          v_num_errors := v_num_errors + 1;
          -- Format the error message
          if length(v_status) >= 5 then
            v_error_code := substr(v_status, 1, 5);
            v_error_message := sqlerrm(-v_error_code);
            v_error_context := substr(v_status,7);
          else
            v_error_code := v_status;
            v_error_message := null;
            v_error_context := null;
          end if;
          -- Write the error
          insert into geometry_errors (
            table_name,
            column_name,
            obj_rowid,
            geometry,
            tolerance,
            error_code,
            error_message,
            error_context
          )
          values (
            t.table_name,
            t.column_name,
            v_rowid,
            v_geometry,
            v_tolerance,
            v_error_code,
            v_error_message,
            v_error_context
          );
        end if;

        -- Commit as necessary
        if mod(v_num_rows,COMMIT_FREQUENCY) = 0 then
          commit;
        end if;

      end if;

    end loop;

  end loop;

  -- Final commit
  commit;
end;
/

-- Show processing errors
show errors;

----------------
-- Check results
----------------

-- Error summary by table, error code
select table_name, error_code, count(*)
from geometry_errors
group by table_name, error_code
order by table_name, error_code;

-- Error summary by error code, table
select error_code, table_name, count(*)
from geometry_errors
group by error_code, table_name
order by error_code, table_name;

-- Error details
select table_name, obj_rowid, error_message, error_context
from geometry_errors
order by table_name, obj_rowid;

--------------------------
-- Fix geometry errors
-- Author: Albert Godfrind
--------------------------

declare
  -- Declare a custom exception for uncorrectable geometries
  -- "ORA-13199: the given geometry cannot be rectified"
  cannot_rectify exception;
  pragma exception_init(cannot_rectify, -13199);

  v_geometry_fixed sdo_geometry;

begin
  -- Process the invalid geometries
  for e in (
    select rowid, table_name, column_name, obj_rowid, tolerance, geometry
    from geometry_errors
    -- order by table_name, column_name
  )
  loop
    -- Try and rectify the geometry.
    begin
      v_geometry_fixed := sdo_util.rectify_geometry (e.geometry, e.tolerance);
    exception
      when cannot_rectify then
        v_geometry_fixed := null;
    end;

    if v_geometry_fixed is not null and sdo_geom.validate_geometry_with_context (v_geometry_fixed, e.tolerance) = 'TRUE' then
      -- Update the base table with the rectified geometry
      execute immediate 'update ' || e.table_name || ' set '|| e.column_name || ' = :g where rowid = :r'
        using v_geometry_fixed, e.obj_rowid;

      -- Remove the fixed and validated geometry from the error log
      delete from geometry_errors where rowid = e.rowid;
    end if;

    commit;

  end loop;
end;
/

-- Show processing errors
show errors;

-------------------------
-- Check remaining errors
-------------------------

-- Error summary by table, error code
select table_name, error_code, count(*)
from geometry_errors
group by table_name, error_code
order by table_name, error_code;

-- Error summary by error code, table
select error_code, table_name, count(*)
from geometry_errors
group by error_code, table_name
order by error_code, table_name;

-- Error details
select table_name, obj_rowid, error_message, error_context
from geometry_errors
order by table_name, obj_rowid;


-------------------------
-- Create spatial indexes
-------------------------
CREATE INDEX feb25_gadm41_mar_2_sidx
ON feb25_gadm41_mar_2 (geometry)
INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;

CREATE INDEX feb25_ne_110m_populated_places_sidx
ON feb25_ne_110m_populated_places (geometry)
INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2 PARAMETERS ('LAYER_GTYPE=POINT CBTREE_INDEX=TRUE');

----------------------------------------------------------------------------------
-- Check SDO metadata: Are automatically created after/with spatial index creation
----------------------------------------------------------------------------------
-- Run as script
SELECT *
FROM user_sdo_geom_metadata
ORDER BY 1;

-- Verify geometries visually using Spatial Studio
