#DZ_GML
PL/SQL utilities for the conversion between GML geometry and Oracle Spatial SDO geometry.
For the most up-to-date documentation see the auto-build [dz_gml_deploy.pdf](https://github.com/pauldzy/DZ_GML/blob/master/dz_gml_deploy.pdf).

##### geogml2sdo
```
dz_gml_main.geogml2sdo(
       p_input            IN  CLOB (or XMLTYPE)
      ,p_gml_version      IN  NUMBER   DEFAULT NULL
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
) RETURN MDSYS.SDO_GEOMETRY
```
Utility to convert various flavors of GML geometries into Oracle Spatial SDO_GEOMETRY.

Parameters:
 
1. **p_input** - input GML geometry as either CLOB or XMLTYPE.  All input must be able to be parsed as Oracle SYS.XMLTYPE so users are encouraged to do that step themselves to avoid issues.  The XML snippet should be presented as the geometry alone, without any parent tags - the same as SDO_UTIL.FROM_GMLGEOMETRY and SDO_UTIL.FROM_GML311GEOMETRY expect.
2. **p_gml_version** - non functional at this time, was intended as hint for parsing GML when the version is unclear.  May still be needed in the future.
3. **p_srid** - override for output SDO_SRID value.  The srid is normally extracted from the srsName on the GML object.  Use this parameter to force to a given value and skip the logic to search for the value.
4. **p_num_dims** - the number of dimensions is required to properly unpack GML coordinates.  This value is normally provided in the srsDimension attribute.  Set this parameter to force to a given value and skip the logic to search for the value.  Setting this to 2 when you know you just have 2D geometries will provide a modest performance boost.
5. **p_axes_latlong** - Set to TRUE if your input GML has longitude and latitude reversed with the Y value first (e.g. WFS 1.1 and 2.0).

Notes:

* This utility does **not** utilize SDO_UTIL.FROM_GMLGEOMETRY or SDO_UTIL.FROM_GML311GEOMETRY in any fashion.
* GML is a rather complex way to encode geometries.  This utility has been created to convert the geometries that I encounter as GML and you may have items that are not covered.  At the moment th logic includes GML Point, Curve, LineString, Polygon, MultiPoint, MultiSurface, MultiCurve and Surface.  Feel free to fork things for yourself or drop me a line or create an issue on the matter if you have other objects to convert.  
* If you need to persist the gml:id value of the input geometry, use the PROCEDURE version of geogml2sdo which has the **p_gml_id** output parameter.

##### sdo2geogml
```
dz_gml_main.sdo2geogml(
      p_input            IN  MDSYS.SDO_GEOMETRY
     ,p_pretty_print     IN  NUMBER   DEFAULT 0
     ,p_2d_flag          IN  VARCHAR2 DEFAULT 'FALSE'
     ,p_output_srid      IN  NUMBER   DEFAULT NULL
     ,p_geometry_format  IN  VARCHAR2 DEFAULT 'GML3'
     ,p_prune_number     IN  NUMBER   DEFAULT NULL
     ,p_output_srs       IN  VARCHAR2 DEFAULT NULL
     ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
     ,p_gml_id           IN  VARCHAR2 DEFAULT NULL
) RETURN CLOB
```
Wrapper around MDSYS.SDO_UTIL.TO_GMLGEOMETRY and MDSYS.SDO_UTIL.TO_GML311GEOMETRY to allow GML 3.2 output and more OGC compliant srs information.

Parameters:
 
1. **p_input** - input MDSYS.SDO_GEOMETRY.  Only geometry types supported by SDO_UTIL GML packages are supported.
2. **p_pretty_print** - nonfunctional at this time
3. **p_2d_flag** - set to TRUE to remove all 3D and LRS information from input geometry before conversion.
4. **p_output_srid** - set to desired output coordinate reference system.  srsName will be populated as defined in dz_gml_util.srid2srs utility function.  
5. **p_geometry_format** - hint to push logic to use TO_GMLGEOMETRY or TO_GML311GEOMETRY.  Default is to assume output should be GML 3.2.  The only need for this parameter is when you do really want old GML 2.0.
6. **p_prune_number** - nonfunctional at this time, the idea here would be to remove large amounts of precision from the source Oracle coordinate numbers.
7. **p_output_srs** - nonfunctional at this time, the idea would be to allow an URN as input to replace or override p_output_srid parameter.
8. **p_axes_latlong** - nonfunctional at this time, the idea would be to swap around the longitude for latitude in the output to match desired WFS specification. 
8. **p_gml_id** - The gml:id value to add to GML 3.2 output.  The default value is "1".

Notes:

* This function is the flip-side of geogml2sdo and never had a production implementation in my work so its a bit of a place holder.  Ideally the logic to unpack SDO into GML would be done in PLSQL and the dependence on the SDO_UTIL utilities removed.  I just never have had the need.

##Installation
Simply execute the deployment script into the schema of your choice.  Then execute the code using either the same or a different schema.  All procedures and functions are publically executable and utilize AUTHID CURRENT_USER for permissions handling.

##Collaboration
Forks and pulls are **most** welcome.  The deployment script and deployment documentation files in the repository root are generated by my [build system](https://github.com/pauldzy/Speculative_PLSQL_CI) which obviously you do not have.  You can just ignore those files and when I merge your pull my system will autogenerate updated files for GitHub.

##Oracle Licensing Disclaimer
Oracle places the burden of matching functionality usage with server licensing entirely upon the user.  In the realm of Oracle Spatial, some features are "[spatial](http://download.oracle.com/otndocs/products/spatial/pdf/12c/oraspatitalandgraph_12_fo.pdf)" (and thus a separate purchased "option" beyond enterprise) and some are "[locator](http://download.oracle.com/otndocs/products/spatial/pdf/12c/oraspatialfeatures_12c_fo_locator.pdf)" (bundled with standard and enterprise).  This differentiation is ever changing.  Thus the definition for 11g is not exactly the same as the definition for 12c.  If you are seeking to utilize my code **without** a full Spatial option license, I do provide a good faith estimate of the licensing required and when coding I am conscious of keeping repository functionality to the simplest licensing level when possible.  However - as all such things go - the final burden of determining if functionality in a given repository matches your server licensing is entirely placed upon the user.  You should **always** fully inspect the code and its usage of Oracle functionality in light of your licensing.  Any reliance you place on my estimation is therefore strictly at your own risk.

In my estimation functionality in the DZ_GML repository requires the full Oracle Spatial option for 10g, 11g and 12c.
