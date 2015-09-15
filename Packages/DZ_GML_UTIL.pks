CREATE OR REPLACE PACKAGE dz_gml_util
AUTHID CURRENT_USER
AS
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gz_split(
       p_str              IN VARCHAR2
      ,p_regex            IN VARCHAR2
      ,p_match            IN VARCHAR2 DEFAULT NULL
      ,p_end              IN NUMBER   DEFAULT 0
      ,p_trim             IN VARCHAR2 DEFAULT 'FALSE'
   ) RETURN MDSYS.SDO_STRING2_ARRAY DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION safe_to_number(
       p_input            IN VARCHAR2
      ,p_null_replacement IN NUMBER DEFAULT NULL
   ) RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION strings2numbers(
      p_input            IN MDSYS.SDO_STRING2_ARRAY
   ) RETURN MDSYS.SDO_NUMBER_ARRAY;
   
   ----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION true_point(
      p_input      IN  MDSYS.SDO_GEOMETRY
   ) RETURN MDSYS.SDO_GEOMETRY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION downsize_2d(
      p_input   IN MDSYS.SDO_GEOMETRY
   ) RETURN MDSYS.SDO_GEOMETRY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION smart_transform(
      p_input     IN  MDSYS.SDO_GEOMETRY,
      p_srid      IN  NUMBER
   ) RETURN MDSYS.SDO_GEOMETRY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE parse_ogc_urn(
       p_input          IN  VARCHAR2
      ,p_urn            OUT VARCHAR2
      ,p_ogc            OUT VARCHAR2
      ,p_def            OUT VARCHAR2
      ,p_objectType     OUT VARCHAR2
      ,p_authority      OUT VARCHAR2
      ,p_version        OUT VARCHAR2
      ,p_code           OUT VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION epsg2srid(
      p_input   IN  NUMBER
   ) RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE srs2srid(
       p_input        IN  VARCHAR2
      ,p_srid         OUT NUMBER
      ,p_axes_latlong OUT VARCHAR2
      ,p_default_srid IN  NUMBER DEFAULT 8265
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION srs2srid(
       p_input        IN  VARCHAR2
      ,p_default_srid IN  NUMBER DEFAULT 8265
   ) RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION srid2srs(
       p_input        IN  NUMBER
      ,p_default_srid IN  NUMBER DEFAULT 8265
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION test_ordinate_rotation(
       p_input       IN MDSYS.SDO_ORDINATE_ARRAY
      ,p_lower_bound IN NUMBER DEFAULT 1
      ,p_upper_bound IN NUMBER DEFAULT NULL
      ,p_num_dims    IN NUMBER DEFAULT 2
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE reverse_ordinate_rotation(
       p_input       IN OUT NOCOPY MDSYS.SDO_ORDINATE_ARRAY
      ,p_lower_bound IN            PLS_INTEGER DEFAULT 1
      ,p_upper_bound IN            PLS_INTEGER DEFAULT NULL
      ,p_num_dims    IN            PLS_INTEGER DEFAULT 2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION reverse_ordinate_rotation(
       p_input       IN  MDSYS.SDO_ORDINATE_ARRAY
      ,p_lower_bound IN  NUMBER DEFAULT 1
      ,p_upper_bound IN  NUMBER DEFAULT NULL
      ,p_num_dims    IN  NUMBER DEFAULT 2
   ) RETURN MDSYS.SDO_ORDINATE_ARRAY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE append2(
       p_input              IN OUT MDSYS.SDO_ELEM_INFO_ARRAY
      ,p_value              IN     NUMBER
      ,p_value_2            IN     NUMBER DEFAULT NULL
      ,p_value_3            IN     NUMBER DEFAULT NULL
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE append2(
       p_input              IN OUT MDSYS.SDO_ELEM_INFO_ARRAY
      ,p_value              IN     MDSYS.SDO_ELEM_INFO_ARRAY
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE append2(
       p_input              IN OUT MDSYS.SDO_ORDINATE_ARRAY
      ,p_value              IN     NUMBER
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE append2(
       p_input              IN OUT MDSYS.SDO_ORDINATE_ARRAY
      ,p_value              IN     MDSYS.SDO_ORDINATE_ARRAY
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION pretty(
       p_input      IN CLOB
      ,p_level      IN NUMBER
      ,p_amount     IN VARCHAR2 DEFAULT '   '
      ,p_linefeed   IN VARCHAR2 DEFAULT CHR(10)
   ) RETURN CLOB;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION xml2date(
      p_input       IN VARCHAR2
   ) RETURN DATE;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_guid
   RETURN VARCHAR2;

END dz_gml_util;
/

GRANT EXECUTE ON dz_gml_util TO PUBLIC;


