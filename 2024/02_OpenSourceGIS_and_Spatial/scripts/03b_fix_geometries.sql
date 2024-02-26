-------------------------
-- Fix invalid geometries
-------------------------

-- Check errors
select table_name, error_code, count(*)
from geometry_errors
group by table_name, error_code
order by table_name, error_code;

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
    -- In 11.1.0.6, the function returns NULL if it cannot correct the errors.
    -- In 11.1.0.7 and 11.2 the function throws exception -13199
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

-- Check remaining errors

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


