select r.georaster.metadata from raster_images r;

declare
  v_raster    sdo_georaster;
  v_nbands    number;
begin
  -- Process rasters onne by one
  for g in (
    select *
    from raster_images
  )
  loop
    -- Read the raster object (metadata only)
    v_raster := g.georaster;

    -- Get the number of bands
    v_nbands := SDO_GEOR.getBandDimSize(v_raster);

    -- Clear the statistics for all bands. Need
    for i in 0..v_nbands loop
      sdo_geor.setStatistics(
        georaster => v_raster,
        layerNumber => i,
        statistics => NULL
      );
    end loop;

    -- Update the raster object
    update raster_images set
      georaster = v_raster
    where georid = g.georid;
    commit;

  end loop;
end;
/