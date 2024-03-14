create or replace function rectify_geometry (geometry sdo_geometry, tolerance number)
return sdo_geometry
as
  cannot_rectify exception;
  pragma exception_init(cannot_rectify, -13199);
  geometry_fixed sdo_geometry;
begin
  begin
    geometry_fixed := sdo_util.rectify_geometry (geometry, tolerance);
  exception
    when cannot_rectify then
      geometry_fixed := geometry;
  end;
  return geometry_fixed;
end;
/
show errors
