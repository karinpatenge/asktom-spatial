drop table geometry_errors purge;

create table geometry_errors (
  table_name      varchar2(30),
  column_name     varchar2(30),
  obj_rowid       rowid,
  geometry        sdo_geometry,
  tolerance       number,
  error_code      char(5),
  error_message   varchar2(256),
  error_context   varchar2(256)
);

declare
  DEFAULT_TOLERANCE   number := 0.0000005;
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
      into v_diminfo, v_srid
      from user_sdo_geom_metadata
      where table_name = t.table_name
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

      -- Validate the geometry
      v_status := sdo_geom.validate_geometry_with_context (v_geometry, v_tolerance);

      -- Log he error (if any)
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

    end loop;

  end loop;

  -- Final commit
  commit;
end;
/

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
