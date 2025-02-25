# WFS Sample Requests

[OGC WFS - Official web page](https://www.ogc.org/publications/standard/wfs/)

The OGC Web Feature Service (WFS) Interface Standard defines a set of interfaces for accessing geographic information at the feature and feature property level over the Internet. A feature is an abstraction of real world phenomena, that is it is a representation of anything that can be found in the world. The attributes or characteristics of a geographic feature are referred to as feature properties. WFS offer the means to retrieve or query geographic features in a manner independent of the underlying data stores they publish.

## getCapabilities

* [WFS 2.0.0 sample request](https://sgx.geodatenzentrum.de/geoserver/vg250-ew/wfs?service=wfs&version=2.0.0&request=GetCapabilities)
* [WFS 1.1.0 sample request](https://ca.nfis.org/mapserver/cgi-bin/ccfm_managed_forests_eng.cgi?SERVICE=WFS&REQUEST=GetCapabilities)

## getFeature

* [WFS 2.0.0 sample request](https://sgx.geodatenzentrum.de/geoserver/vg250-ew/wfs?service=wfs&version=2.0.0&request=GetFeature&typenames=vg250-ew:vg250_rbz&outputFormat=json&srsName=urn:ogc:def:crs:EPSG::4326)
* [WFS 1.1.0 sample request](https://ca.nfis.org/mapserver/cgi-bin/ccfm_managed_forests_eng.cgi?SERVICE=WFS&REQUEST=GetFeature&version=1.1.0&typename=managed_forest_tenure,Map_of_Forest_Management_in_Canada&outputFormat=geojson&srsName=urn:ogc:def:crs:EPSG::4326)
