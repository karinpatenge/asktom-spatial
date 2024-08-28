declare
   v_raster    sdo_georaster;
   v_status    varchar2(16);
   v_window    sdo_geometry;
begin
   -- Process rasters on by one
   for g in (
      select *
      from raster_images
   )
   loop
      -- Read the raster object (metadata only)
      v_raster := g.georaster;

      v_window := g.georaster.spatialextent;

      -- Generate the statistics for all layers, including layer 0
      v_status := sdo_geor.generateStatistics(
         georaster => v_raster,
         samplingFactor => 'samplingFactor=1',
         samplingWindow => v_window,
         histogram => 'TRUE',                   -- Histogram is generated
         layerNumbers => '0-2'                  -- Apply to all three layers
      );

      -- Update the raster object
      update raster_images set
         georaster = v_raster
      where georid = g.georid;
   commit;

   end loop;
end;
/

select r.georaster.metadata from raster_images r;