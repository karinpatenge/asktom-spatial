set define off
set sqlblanklines on
set echo on

drop table crs_errors purge;

create table crs_errors (
  srid            number,
  error_code      char(5),
  error_message   varchar2(256),
  error_context   varchar2(256)
);

declare
  v_srid              number;
  v_error_code        char(5);
  v_error_message     varchar2(256);
  v_error_context     varchar2(256);
  v_status            varchar2(256);

begin
  -- Process MDSYS.CS_SRS
  for cur in (
    select cs_name, srid, auth_name, wktext
    from cs_srs
    order by srid
  )
  loop
    v_status := NULL;
    v_srid := cur.srid;

    -- Validate the CRS
    v_status := sdo_cs.validate_wkt (v_srid);


    -- Log the error (if any)
    if v_status <> 'TRUE' then

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
      insert into crs_errors (
        srid,
        error_code,
        error_message,
        error_context
      )
      values (
        v_srid,
        v_error_code,
        v_error_message,
        v_error_context
      );
      end if;

  end loop;
  commit;
end;
/

/*
 * Stats for CRS errors
 */

-- Error details
select srid, error_message, error_context
from crs_errors
order by srid;