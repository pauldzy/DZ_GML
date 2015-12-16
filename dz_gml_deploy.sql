
--*************************--
PROMPT sqlplus_header.sql;

WHENEVER SQLERROR EXIT -99;
WHENEVER OSERROR  EXIT -98;
SET DEFINE OFF;



--*************************--
PROMPT DZ_GML_ORDS_VRY.tps;

CREATE OR REPLACE TYPE dz_gml_ords_vry FORCE
AS 
VARRAY(1048576) OF MDSYS.SDO_ORDINATE_ARRAY;
/

GRANT EXECUTE ON dz_gml_ords_vry TO PUBLIC;


--*************************--
PROMPT DZ_GML_UTIL.pks;

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


--*************************--
PROMPT DZ_GML_UTIL.pkb;

CREATE OR REPLACE PACKAGE BODY dz_gml_util
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gz_split(
       p_str              IN VARCHAR2
      ,p_regex            IN VARCHAR2
      ,p_match            IN VARCHAR2 DEFAULT NULL
      ,p_end              IN NUMBER   DEFAULT 0
      ,p_trim             IN VARCHAR2 DEFAULT 'FALSE'
   ) RETURN MDSYS.SDO_STRING2_ARRAY DETERMINISTIC 
   AS
      int_delim      PLS_INTEGER;
      int_position   PLS_INTEGER := 1;
      int_counter    PLS_INTEGER := 1;
      ary_output     MDSYS.SDO_STRING2_ARRAY;
      num_end        NUMBER      := p_end;
      str_trim       VARCHAR2(5 Char) := UPPER(p_trim);
      
      FUNCTION trim_varray(
         p_input            IN MDSYS.SDO_STRING2_ARRAY
      ) RETURN MDSYS.SDO_STRING2_ARRAY
      AS
         ary_output MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY();
         int_index  PLS_INTEGER := 1;
         str_check  VARCHAR2(4000 Char);
         
      BEGIN

         --------------------------------------------------------------------------
         -- Step 10
         -- Exit if input is empty
         --------------------------------------------------------------------------
         IF p_input IS NULL
         OR p_input.COUNT = 0
         THEN
            RETURN ary_output;
            
         END IF;

         --------------------------------------------------------------------------
         -- Step 20
         -- Trim the strings removing anything utterly trimmed away
         --------------------------------------------------------------------------
         FOR i IN 1 .. p_input.COUNT
         LOOP
            str_check := TRIM(p_input(i));
            
            IF str_check IS NULL
            OR str_check = ''
            THEN
               NULL;
               
            ELSE
               ary_output.EXTEND(1);
               ary_output(int_index) := str_check;
               int_index := int_index + 1;
               
            END IF;

         END LOOP;

         --------------------------------------------------------------------------
         -- Step 10
         -- Return the results
         --------------------------------------------------------------------------
         RETURN ary_output;

      END trim_varray;

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Create the output array and check parameters
      --------------------------------------------------------------------------
      ary_output := MDSYS.SDO_STRING2_ARRAY();

      IF str_trim IS NULL
      THEN
         str_trim := 'FALSE';
         
      ELSIF str_trim NOT IN ('TRUE','FALSE')
      THEN
         RAISE_APPLICATION_ERROR(-20001,'boolean error');
         
      END IF;

      IF num_end IS NULL
      THEN
         num_end := 0;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Exit early if input is empty
      --------------------------------------------------------------------------
      IF p_str IS NULL
      OR p_str = ''
      THEN
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 30
      -- Account for weird instance of pure character breaking
      --------------------------------------------------------------------------
      IF p_regex IS NULL
      OR p_regex = ''
      THEN
         FOR i IN 1 .. LENGTH(p_str)
         LOOP
            ary_output.EXTEND(1);
            ary_output(i) := SUBSTR(p_str,i,1);
            
         END LOOP;
         
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 40
      -- Break string using the usual REGEXP functions
      --------------------------------------------------------------------------
      LOOP
         EXIT WHEN int_position = 0;
         int_delim  := REGEXP_INSTR(p_str,p_regex,int_position,1,0,p_match);
         
         IF  int_delim = 0
         THEN
            -- no more matches found
            ary_output.EXTEND(1);
            ary_output(int_counter) := SUBSTR(p_str,int_position);
            int_position  := 0;
            
         ELSE
            IF int_counter = num_end
            THEN
               -- take the rest as is
               ary_output.EXTEND(1);
               ary_output(int_counter) := SUBSTR(p_str,int_position);
               int_position  := 0;
               
            ELSE
               --dbms_output.put_line(ary_output.COUNT);
               ary_output.EXTEND(1);
               ary_output(int_counter) := SUBSTR(p_str,int_position,int_delim-int_position);
               int_counter := int_counter + 1;
               int_position := REGEXP_INSTR(p_str,p_regex,int_position,1,1,p_match);
               
            END IF;
            
         END IF;
         
      END LOOP;

      --------------------------------------------------------------------------
      -- Step 50
      -- Trim results if so desired
      --------------------------------------------------------------------------
      IF str_trim = 'TRUE'
      THEN
         RETURN trim_varray(
            p_input => ary_output
         );
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 60
      -- Cough out the results
      --------------------------------------------------------------------------
      RETURN ary_output;
      
   END gz_split;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION safe_to_number(
       p_input            IN VARCHAR2
      ,p_null_replacement IN NUMBER DEFAULT NULL
   ) RETURN NUMBER
   AS
   BEGIN
      RETURN TO_NUMBER(
         REPLACE(
            REPLACE(
               p_input,
               CHR(10),
               ''
            ),
            CHR(13),
            ''
         ) 
      );
      
   EXCEPTION
      WHEN VALUE_ERROR
      THEN
         RETURN p_null_replacement;
         
   END safe_to_number;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION strings2numbers(
      p_input            IN MDSYS.SDO_STRING2_ARRAY
   ) RETURN MDSYS.SDO_NUMBER_ARRAY
   AS
      ary_output MDSYS.SDO_NUMBER_ARRAY := MDSYS.SDO_NUMBER_ARRAY();
      num_tester NUMBER;
      int_index  PLS_INTEGER := 1;

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Exit if input is empty
      --------------------------------------------------------------------------
      IF p_input IS NULL
      OR p_input.COUNT = 0
      THEN
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Convert anything that is a valid number to a number, dump the rest
      --------------------------------------------------------------------------
      FOR i IN 1 .. p_input.COUNT
      LOOP
         IF p_input(i) IS NOT NULL
         THEN
            num_tester := safe_to_number(
               p_input => p_input(i)
            );
            
            IF num_tester IS NOT NULL
            THEN
               ary_output.EXTEND();
               ary_output(int_index) := num_tester;
               int_index := int_index + 1;
               
            END IF;
            
         END IF;
         
      END LOOP;

      RETURN ary_output;

   END strings2numbers;

   ----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION true_point(
      p_input      IN  MDSYS.SDO_GEOMETRY
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
   BEGIN

      IF p_input.SDO_POINT IS NOT NULL
      THEN
         RETURN p_input;
         
      END IF;

      IF p_input.get_gtype() = 1
      THEN
         IF p_input.get_dims() = 2
         THEN
            RETURN MDSYS.SDO_GEOMETRY(
                p_input.SDO_GTYPE
               ,p_input.SDO_SRID
               ,MDSYS.SDO_POINT_TYPE(
                   p_input.SDO_ORDINATES(1)
                  ,p_input.SDO_ORDINATES(2)
                  ,NULL
                )
               ,NULL
               ,NULL
            );
            
         ELSIF p_input.get_dims() = 3
         THEN
            RETURN MDSYS.SDO_GEOMETRY(
                p_input.SDO_GTYPE
               ,p_input.SDO_SRID
               ,MDSYS.SDO_POINT_TYPE(
                    p_input.SDO_ORDINATES(1)
                   ,p_input.SDO_ORDINATES(2)
                   ,p_input.SDO_ORDINATES(3)
                )
               ,NULL
               ,NULL
            );
            
         ELSE
            RAISE_APPLICATION_ERROR(
                -20001
               ,'function true_point can only work on 2 and 3 dimensional points - dims=' || p_input.get_dims() || ' '
            );
            
         END IF;
         
      ELSE
         RAISE_APPLICATION_ERROR(
             -20001
            ,'function true_point can only work on point geometries'
         );
         
      END IF;
      
   END true_point;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION downsize_2d(
      p_input   IN MDSYS.SDO_GEOMETRY
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      geom_2d       MDSYS.SDO_GEOMETRY;
      dim_count     PLS_INTEGER;
      gtype         PLS_INTEGER;
      n_points      PLS_INTEGER;
      n_ordinates   PLS_INTEGER;
      i             PLS_INTEGER;
      j             PLS_INTEGER;
      k             PLS_INTEGER;
      offset        PLS_INTEGER;
      
   BEGIN

      IF p_input IS NULL
      THEN
         RETURN NULL;
         
      END IF;

      IF LENGTH (p_input.SDO_GTYPE) = 4
      THEN
         dim_count := p_input.get_dims();
         gtype     := p_input.get_gtype();
         
      ELSE
         RAISE_APPLICATION_ERROR(
             -20001
            ,'Unable to determine dimensionality from gtype'
         );
         
      END IF;

      IF dim_count = 2
      THEN
         RETURN p_input;
         
      END IF;

      geom_2d := MDSYS.SDO_GEOMETRY(
          2000 + gtype
         ,p_input.SDO_SRID
         ,p_input.SDO_POINT
         ,MDSYS.SDO_ELEM_INFO_ARRAY()
         ,MDSYS.SDO_ORDINATE_ARRAY()
      );

      IF geom_2d.SDO_POINT IS NOT NULL
      THEN
         geom_2d.SDO_POINT.z   := NULL;
         geom_2d.SDO_ELEM_INFO := NULL;
         geom_2d.SDO_ORDINATES := NULL;
         
      ELSE
         n_points    := p_input.SDO_ORDINATES.COUNT / dim_count;
         n_ordinates := n_points * 2;
         geom_2d.SDO_ORDINATES.EXTEND(n_ordinates);
         j := p_input.SDO_ORDINATES.FIRST;
         k := 1;
         FOR i IN 1 .. n_points
         LOOP
            geom_2d.SDO_ORDINATES(k) := p_input.SDO_ORDINATES(j);
            geom_2d.SDO_ORDINATES(k + 1) := p_input.SDO_ORDINATES(j + 1);
            j := j + dim_count;
            k := k + 2;
         
         END LOOP;

         geom_2d.sdo_elem_info := p_input.sdo_elem_info;

         i := geom_2d.SDO_ELEM_INFO.FIRST;
         WHILE i < geom_2d.SDO_ELEM_INFO.LAST
         LOOP
            offset := geom_2d.SDO_ELEM_INFO(i);
            geom_2d.SDO_ELEM_INFO(i) := (offset - 1) / dim_count * 2 + 1;
            i := i + 3;
            
         END LOOP;

      END IF;

      IF geom_2d.SDO_GTYPE = 2001
      THEN
         RETURN true_point(geom_2d);
         
      ELSE
         RETURN geom_2d;
         
      END IF;

   END downsize_2d;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION smart_transform(
       p_input     IN  MDSYS.SDO_GEOMETRY
      ,p_srid      IN  NUMBER
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output     MDSYS.SDO_GEOMETRY;
      
      -- preferred SRIDs
      num_wgs84_pref NUMBER := 4326;
      num_nad83_pref NUMBER := 8265;
      
   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Check incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         RETURN p_input;
         
      END IF;

      IF p_srid IS NULL
      THEN
         RAISE_APPLICATION_ERROR(-20001,'function requires srid in parameter 2');
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Check if SRID values match
      --------------------------------------------------------------------------
      IF p_srid = p_input.SDO_SRID
      THEN
         RETURN p_input;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 30
      -- Check for equivalents and adjust geometry SRID if required
      --------------------------------------------------------------------------
      IF  p_srid IN (4269,8265)
      AND p_input.SDO_SRID IN (4269,8265)
      THEN
         sdo_output := p_input;
         sdo_output.SDO_SRID := num_nad83_pref;
         RETURN sdo_output;
         
      ELSIF p_srid IN (4326,8307)
      AND   p_input.SDO_SRID IN (4326,8307)
      THEN
         sdo_output := p_input;
         sdo_output.SDO_SRID := num_wgs84_pref;
         RETURN sdo_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 40
      -- Run the transformation then
      --------------------------------------------------------------------------
      IF p_srid = 3785
      THEN
         sdo_output := MDSYS.SDO_CS.TRANSFORM(
             geom     => p_input
            ,use_case => 'USE_SPHERICAL'
            ,to_srid  => p_srid
         );
         
      ELSE
         sdo_output := MDSYS.SDO_CS.TRANSFORM(
             geom     => p_input
            ,to_srid  => p_srid
         );
      
      END IF;
      
      RETURN sdo_output;

   END smart_transform;
   
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
   )
   AS
      ary_string  MDSYS.SDO_STRING2_ARRAY;
      
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Split by colons
      --------------------------------------------------------------------------
      ary_string := gz_split(p_input,':');
      IF ary_string.COUNT != 7
      THEN
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Assign results
      --------------------------------------------------------------------------
      p_urn        := ary_string(1);
      p_ogc        := ary_string(2);
      p_def        := ary_string(3);
      p_objectType := ary_string(4);
      p_authority  := ary_string(5);
      p_version    := ary_string(6);
      p_code       := ary_string(7);
      RETURN;
   
   END parse_ogc_urn;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION epsg2srid(
      p_input   IN  NUMBER
   ) RETURN NUMBER
   AS
   BEGIN

      IF p_input = 4269
      THEN
         RETURN 8265;
         
      ELSE
         RETURN p_input;
         
      END IF;

   END epsg2srid;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE srs2srid(
       p_input        IN  VARCHAR2
      ,p_srid         OUT NUMBER
      ,p_axes_latlong OUT VARCHAR2
      ,p_default_srid IN  NUMBER DEFAULT 8265
   )
   AS
      str_input      VARCHAR2(4000 Char) := UPPER(p_input);
      str_urn        VARCHAR2(4000 Char);
      str_ogc        VARCHAR2(4000 Char);
      str_def        VARCHAR2(4000 Char);
      str_objectType VARCHAR2(4000 Char);
      str_authority  VARCHAR2(4000 Char);
      str_version    VARCHAR2(4000 Char);
      str_code       VARCHAR2(4000 Char);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF str_input IS NULL
      THEN
         p_srid         := p_default_srid;
         p_axes_latlong := 'FALSE';
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Check for SDO: and EPSG: patterns - valid but not wanted
      -- Note that leaving p_axes_latlong NULL means we just don't know
      --------------------------------------------------------------------------
      IF SUBSTR(str_input,1,4) = 'SDO:'
      THEN
         p_srid := safe_to_number(SUBSTR(str_input,5));
         p_axes_latlong := 'FALSE';
         RETURN;
         
      ELSIF SUBSTR(str_input,1,5) = 'EPSG:'
      THEN
         p_srid := safe_to_number(
            epsg2srid(SUBSTR(str_input,6))
         );
         p_axes_latlong := 'FALSE';
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Assume is OGC urn at this point
      --------------------------------------------------------------------------
      parse_ogc_urn(
          p_input      => str_input
         ,p_urn        => str_urn
         ,p_ogc        => str_ogc
         ,p_def        => str_def
         ,p_objectType => str_objectType
         ,p_authority  => str_authority
         ,p_version    => str_version
         ,p_code       => str_code
      );
      
      IF str_urn IS NULL
      THEN
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Okay try to make some sense of things
      --------------------------------------------------------------------------
      IF str_urn = 'URN'
      AND str_ogc = 'OGC'
      AND str_def = 'DEF'
      AND str_objectType = 'CRS'
      THEN
         IF str_authority = 'OGC'
         AND str_code = 'CRS84'
         THEN
            p_srid := 8307;
            p_axes_latlong := 'FALSE';
            
         ELSIF str_authority = 'OGC'
         AND str_code = 'CRS83'
         THEN
            p_srid := 8265;
            p_axes_latlong := 'FALSE';
            
         ELSIF str_authority = 'EPSG'
         THEN
            p_srid := safe_to_number(
               epsg2srid(str_code)
            );
            p_axes_latlong := 'TRUE';
            
         END IF;

      ELSE
         RETURN;
         
      END IF;
   
   END srs2srid;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION srs2srid(
       p_input        IN  VARCHAR2
      ,p_default_srid IN  NUMBER DEFAULT 8265
   ) RETURN NUMBER
   AS
      num_srid         NUMBER;
      str_axes_latlong VARCHAR2(4000 Char);
      
   BEGIN
      
      srs2srid(
          p_input        => p_input
         ,p_srid         => num_srid
         ,p_axes_latlong => str_axes_latlong
         ,p_default_srid => p_default_srid
      );
      
      RETURN num_srid;
   
   END srs2srid;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION srid2srs(
       p_input        IN  NUMBER
      ,p_default_srid IN  NUMBER DEFAULT 8265
   ) RETURN VARCHAR2
   AS
   
   BEGIN
   
      IF p_input IS NULL
      THEN
         RETURN 'SDO:' || TO_CHAR(p_default_srid);
         
      ELSIF p_input = 8265
      THEN
         RETURN 'urn:ogc:def:crs:OGC::CRS83';
          
      ELSIF p_input = 8307
      THEN
         RETURN 'urn:ogc:def:crs:OGC::CRS84';
         
      ELSE
         RETURN 'SDO:' || TO_CHAR(p_input);
         
      END IF;
   
   END srid2srs;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE test_ordinate_rotation(
       p_input       IN  MDSYS.SDO_ORDINATE_ARRAY
      ,p_lower_bound IN  NUMBER DEFAULT 1
      ,p_upper_bound IN  NUMBER DEFAULT NULL
      ,p_num_dims    IN  NUMBER DEFAULT 2
      ,p_results     OUT VARCHAR2
      ,p_area        OUT NUMBER
   )
   AS
      int_dims      PLS_INTEGER := p_num_dims;
      int_lb        PLS_INTEGER := p_lower_bound;
      int_ub        PLS_INTEGER := p_upper_bound;
      num_x         NUMBER;
      num_y         NUMBER;
      num_lastx     NUMBER;
      num_lasty     NUMBER;

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF int_dims IS NULL
      THEN
        int_dims := 2;
        
      END IF;
      
      IF int_ub IS NULL
      THEN
         int_ub  := p_input.COUNT;
         
      END IF;

      IF int_lb IS NULL
      THEN
         int_lb  := 1;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Loop through the ordinates create the area value
      --------------------------------------------------------------------------
      p_area  := 0;
      num_lastx := 0;
      num_lasty := 0;
      WHILE int_lb <= int_ub
      LOOP
         num_x := p_input(int_lb);
         num_y := p_input(int_lb + 1);
         p_area := p_area + ( (num_lasty * num_x ) - ( num_lastx * num_y) );
         num_lastx := num_x;
         num_lasty := num_y;
         int_lb := int_lb + int_dims;
         
      END LOOP;

      --------------------------------------------------------------------------
      -- Step 40
      -- If area is positive, then its clockwise
      --------------------------------------------------------------------------
      IF p_area > 0
      THEN
         p_results := 'CW';
         
      ELSE
         p_results := 'CCW';
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 50
      -- Preserve the area value if required by the caller
      --------------------------------------------------------------------------
      p_area := ABS(p_area);

   END test_ordinate_rotation;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION test_ordinate_rotation(
       p_input       IN MDSYS.SDO_ORDINATE_ARRAY
      ,p_lower_bound IN NUMBER DEFAULT 1
      ,p_upper_bound IN NUMBER DEFAULT NULL
      ,p_num_dims    IN NUMBER DEFAULT 2
   ) RETURN VARCHAR2
   AS
      str_results   VARCHAR2(3 Char);
      num_area      NUMBER;

   BEGIN

      test_ordinate_rotation(
          p_input
         ,p_lower_bound
         ,p_upper_bound
         ,p_num_dims
         ,str_results
         ,num_area
      );

      RETURN str_results;

   END test_ordinate_rotation;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE reverse_ordinate_rotation(
       p_input       IN OUT NOCOPY MDSYS.SDO_ORDINATE_ARRAY
      ,p_lower_bound IN            PLS_INTEGER DEFAULT 1
      ,p_upper_bound IN            PLS_INTEGER DEFAULT NULL
      ,p_num_dims    IN            PLS_INTEGER DEFAULT 2
   ) 
   AS
      int_n         PLS_INTEGER;
      int_m         PLS_INTEGER;
      int_li        PLS_INTEGER;
      int_ui        PLS_INTEGER;
      num_tempx     NUMBER;
      num_tempy     NUMBER;
      num_tempz     NUMBER;
      num_tempm     NUMBER;
      int_lb        PLS_INTEGER := p_lower_bound;
      int_ub        PLS_INTEGER := p_upper_bound;
      int_dims      PLS_INTEGER := p_num_dims;
      
   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF int_lb IS NULL
      THEN
         int_lb := 1;
         
      END IF;
      
      IF int_ub IS NULL
      THEN
         int_ub  := p_input.COUNT;
         
      END IF;
      
      IF int_dims IS NULL
      THEN
         int_dims := 2;
         
      END IF;

      int_n := int_ub - int_lb + 1;

      -- Exit if only a single ordinate
      IF int_n <= int_dims
      THEN
         RETURN;
         
      END IF;

      -- Calculate the start n1, the end n2, and the middle m
      int_m  := int_lb + (int_n / 2);
      int_li := int_lb;
      int_ui := int_ub;
      WHILE int_li < int_m
      LOOP

         IF int_dims = 2
         THEN
            num_tempx := p_input(int_li);
            num_tempy := p_input(int_li + 1);

            p_input(int_li)     := p_input(int_ui - 1);
            p_input(int_li + 1) := p_input(int_ui);

            p_input(int_ui - 1) := num_tempx;
            p_input(int_ui)     := num_tempy;

         ELSIF int_dims = 3
         THEN
            num_tempx := p_input(int_li);
            num_tempy := p_input(int_li + 1);
            num_tempz := p_input(int_li + 2);

            p_input(int_li)     := p_input(int_ui - 2);
            p_input(int_li + 1) := p_input(int_ui - 1);
            p_input(int_li + 2) := p_input(int_ui);

            p_input(int_ui - 2) := num_tempx;
            p_input(int_ui - 1) := num_tempy;
            p_input(int_ui)     := num_tempz;
            
         ELSIF int_dims = 4
         THEN
            num_tempx := p_input(int_li);
            num_tempy := p_input(int_li + 1);
            num_tempz := p_input(int_li + 2);
            num_tempm := p_input(int_li + 3);

            p_input(int_li)     := p_input(int_ui - 3);
            p_input(int_li + 1) := p_input(int_ui - 2);
            p_input(int_li + 2) := p_input(int_ui - 1);
            p_input(int_li + 3) := p_input(int_ui);

            p_input(int_ui - 3) := num_tempx;
            p_input(int_ui - 2) := num_tempy;
            p_input(int_ui - 1) := num_tempz;
            p_input(int_ui)     := num_tempm;
            
         END IF;

         int_li := int_li + int_dims;
         int_ui := int_ui - int_dims;

      END LOOP;

   END reverse_ordinate_rotation;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION reverse_ordinate_rotation(
       p_input       IN  MDSYS.SDO_ORDINATE_ARRAY
      ,p_lower_bound IN  NUMBER DEFAULT 1
      ,p_upper_bound IN  NUMBER DEFAULT NULL
      ,p_num_dims    IN  NUMBER DEFAULT 2
   ) RETURN MDSYS.SDO_ORDINATE_ARRAY
   AS
      sdo_ord_output MDSYS.SDO_ORDINATE_ARRAY;
      
   BEGIN
   
      sdo_ord_output := p_input;
      
      reverse_ordinate_rotation(
          sdo_ord_output
         ,p_lower_bound
         ,p_upper_bound
         ,p_num_dims
      );
      
      RETURN sdo_ord_output;
      
   END reverse_ordinate_rotation;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE append2(
       p_input              IN OUT MDSYS.SDO_ELEM_INFO_ARRAY
      ,p_value              IN     NUMBER
      ,p_value_2            IN     NUMBER DEFAULT NULL
      ,p_value_3            IN     NUMBER DEFAULT NULL
   )
   AS
      int_index PLS_INTEGER;
      
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_value IS NULL
      THEN
         RETURN;
         
      END IF;

      IF p_input IS NULL
      THEN
         p_input := MDSYS.SDO_ELEM_INFO_ARRAY();
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Add first value
      --------------------------------------------------------------------------
      int_index := p_input.COUNT;
      p_input.EXTEND();
      p_input(int_index + 1) := p_value;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Add extra values
      --------------------------------------------------------------------------
      IF p_value_2 IS NOT NULL
      THEN
         p_input.EXTEND();
         p_input(int_index + 2) := p_value_2;
      
         IF p_value_3 IS NOT NULL
         THEN
            p_input.EXTEND();
            p_input(int_index + 3) := p_value_3;
         
         END IF;
      
      END IF;

   END append2;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE append2(
       p_input              IN OUT MDSYS.SDO_ELEM_INFO_ARRAY
      ,p_value              IN     MDSYS.SDO_ELEM_INFO_ARRAY
   )
   AS
   BEGIN

      IF p_value IS NULL
      THEN
         RETURN;
         
      END IF;

      FOR i IN 1 .. p_value.COUNT
      LOOP
         append2(p_input,p_value(i));
         
      END LOOP;

   END append2;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE append2(
       p_input              IN OUT MDSYS.SDO_ORDINATE_ARRAY
      ,p_value              IN     NUMBER
   )
   AS
      int_index PLS_INTEGER;
      
   BEGIN

      IF p_value IS NULL
      THEN
         RETURN;
         
      END IF;

      IF p_input IS NULL
      THEN
         p_input := MDSYS.SDO_ORDINATE_ARRAY();
         
      END IF;

      int_index := p_input.COUNT;
      
      p_input.EXTEND();
      
      p_input(int_index + 1) := p_value;

   END append2;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE append2(
       p_input              IN OUT MDSYS.SDO_ORDINATE_ARRAY
      ,p_value              IN     MDSYS.SDO_ORDINATE_ARRAY
   )
   AS
   BEGIN

      IF p_value IS NULL
      THEN
         RETURN;
         
      END IF;

      FOR i IN 1 .. p_value.COUNT
      LOOP
         append2(p_input,p_value(i));
         
      END LOOP;

   END append2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION indent(
      p_level      IN NUMBER,
      p_amount     IN VARCHAR2 DEFAULT '   '
   ) RETURN VARCHAR2
   AS
      str_output VARCHAR2(4000 Char) := '';
      
   BEGIN
   
      IF  p_level IS NOT NULL
      AND p_level > 0
      THEN
         FOR i IN 1 .. p_level
         LOOP
            str_output := str_output || p_amount;
            
         END LOOP;
         
         RETURN str_output;
         
      ELSE
         RETURN '';
         
      END IF;
      
   END indent;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION pretty(
      p_input      IN CLOB,
      p_level      IN NUMBER,
      p_amount     IN VARCHAR2 DEFAULT '   ',
      p_linefeed   IN VARCHAR2 DEFAULT CHR(10)
   ) RETURN CLOB
   AS
      str_amount   VARCHAR2(4000 Char) := p_amount;
      str_linefeed VARCHAR2(2 Char)    := p_linefeed;
      
   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Process Incoming Parameters
      --------------------------------------------------------------------------
      IF p_amount IS NULL
      THEN
         str_amount := '   ';
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- If input is NULL, then do nothing
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         RETURN NULL;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 30
      -- Return indented and line fed results
      --------------------------------------------------------------------------
      IF p_level IS NULL
      THEN
         RETURN p_input;
         
      ELSIF p_level = -1
      THEN
         RETURN p_input || TO_CLOB(str_linefeed);
         
      ELSE
         RETURN TO_CLOB(
            indent(p_level,str_amount)
         ) || p_input || TO_CLOB(str_linefeed);
         
      END IF;

   END pretty;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION xml2date(
      p_input       IN VARCHAR2
   ) RETURN DATE
   AS
      date_attempt DATE;
      time_attempt TIMESTAMP;
      tzon_attempt TIMESTAMP WITH TIME ZONE;
      boo_check    BOOLEAN;
      
   BEGIN
   
      boo_check := TRUE;
      
      BEGIN
         date_attempt := TO_DATE(p_input,'yyyy-mm-dd');
         
      EXCEPTION
         WHEN OTHERS
         THEN
            IF SQLCODE = -1830
            THEN
               boo_check := FALSE;
               
            ELSE
               RAISE;
               
            END IF;
            
      END;
      
      IF boo_check = TRUE
      THEN
         RETURN date_attempt;
         
      END IF;
      
      boo_check := TRUE;
      BEGIN
         time_attempt := TO_TIMESTAMP(p_input,'yyyy-mm-dd"T"hh24:mi:ss');
         
      EXCEPTION
         WHEN OTHERS
         THEN
            IF SQLCODE = -1830
            THEN
               boo_check := FALSE;
               
            ELSE
               RAISE;
               
            END IF;
      END;
      
      IF boo_check = TRUE
      THEN
         RETURN TO_DATE(
             TO_CHAR(time_attempt,'DD-MON-YYYY HH24:MI:SS')
            ,'DD-MON-YYYY HH24:MI:SS'
         );
         
      END IF;
      
      boo_check := TRUE;
      BEGIN
         tzon_attempt := TO_TIMESTAMP_TZ(p_input,'yyyy-mm-dd"T"hh24:mi:ssTZD');
         
      EXCEPTION
         WHEN OTHERS
         THEN
            IF SQLCODE = -1830
            THEN
               boo_check := FALSE;
               
            ELSE
               RAISE;
               
            END IF;
            
      END;
      
      IF boo_check = TRUE
      THEN
         RETURN TO_DATE(
             TO_CHAR(tzon_attempt,'DD-MON-YYYY HH24:MI:SS')
            ,'DD-MON-YYYY HH24:MI:SS'
         );
         
      END IF;
      
      boo_check := TRUE;
      BEGIN
         tzon_attempt := TO_TIMESTAMP_TZ(p_input,'yyyy-mm-dd"T"hh24:mi:ss.fftzh:tzm');
         
      EXCEPTION
         WHEN OTHERS
         THEN
            IF SQLCODE = -1830
            THEN
               boo_check := FALSE;
               
            ELSE
               RAISE;
               
            END IF;
            
      END;
      
      IF boo_check = TRUE
      THEN
         RETURN TO_DATE(
             TO_CHAR(tzon_attempt,'DD-MON-YYYY HH24:MI:SS')
            ,'DD-MON-YYYY HH24:MI:SS'
         );
         
      END IF;
      
      raise_application_error(-20001,p_input);
      
   END xml2date;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_guid
   RETURN VARCHAR2
   AS
      str_sysguid VARCHAR2(40 Char);
      
   BEGIN
   
      str_sysguid := UPPER(RAWTOHEX(SYS_GUID()));
      
      RETURN '{' 
         || SUBSTR(str_sysguid,1,8)  || '-'
         || SUBSTR(str_sysguid,9,4)  || '-'
         || SUBSTR(str_sysguid,13,4) || '-'
         || SUBSTR(str_sysguid,17,4) || '-'
         || SUBSTR(str_sysguid,21,12)|| '}';
   
   END get_guid;
   
END dz_gml_util;
/


--*************************--
PROMPT DZ_GML_MAIN.pks;

CREATE OR REPLACE PACKAGE dz_gml_main
AUTHID CURRENT_USER
AS
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   header: DZ_GML
     
   - Build ID: 6
   - TFS Change Set: 8262
   
   Utilities for the exchange of geometries between Oracle Spatial and OGC
   GML 3.x formats.
   
   */
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_gml_main.sdo2geogml
   
   Wrapper around MDSYS.SDO_UTIL.TO_GMLGEOMETRY and 
   MDSYS.SDO_UTIL.TO_GML311GEOMETRY for conversion of Oracle Spatial SDO_GEOMETRY 
   into GML geospatial tags allowing GML 3.2 output and more OGC compliant 
   srs information.
   
   Parameters:

      p_input - input SDO_GEOMETRY. Only geometry types supported by SDO_UTIL GML 
      packages are supported.
      p_pretty_print - nonfunctional at this time.
      p_2d_flag - set to TRUE to remove all 3D and LRS information from input 
      geometry before conversion.
      p_output_srid - set to desired output coordinate reference system. srsName 
      will be populated as defined in dz_gml_util.srid2srs utility function.
      p_geometry_format - hint to push logic to use TO_GMLGEOMETRY or 
      TO_GML311GEOMETRY. Default is to assume output should be GML 3.2. The only 
      need for this parameter is when you do really want old GML 2.0.
      p_prune_number - nonfunctional at this time, the idea here would be to 
      remove large amounts of precision from the source Oracle coordinate numbers.
      p_output_srs - nonfunctional at this time, the idea would be to allow an 
      URN as input to replace or override p_output_srid parameter.
      p_axes_latlong - nonfunctional at this time, the idea would be to swap around 
      the longitude for latitude in the output to match desired WFS specification.
      p_gml_id - The gml:id value to add to GML 3.2 output. The default value is "1".      
   
   Returns:

      CLOB text in GML format
   
   Notes:
   
    - This function is the flip-side of geogml2sdo and never had a production implementation 
      in my work so its a bit of a place holder. Ideally the logic to unpack SDO into GML 
      would be done in PLSQL and the dependence on the SDO_UTIL utilities removed. I just 
      never have had the need.
   
   */
   FUNCTION sdo2geogml(
       p_input            IN  MDSYS.SDO_GEOMETRY
      ,p_pretty_print     IN  NUMBER   DEFAULT 0
      ,p_2d_flag          IN  VARCHAR2 DEFAULT 'FALSE'
      ,p_output_srid      IN  NUMBER   DEFAULT NULL
      ,p_geometry_format  IN  VARCHAR2 DEFAULT 'GML3'
      ,p_prune_number     IN  NUMBER   DEFAULT NULL
      ,p_output_srs       IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_gml_id           IN  VARCHAR2 DEFAULT NULL
   ) RETURN CLOB;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_gml_main.fetch_gml_namespace
   
   Direct exposure of the GML version number to namespace utility to test if your 
   gml version is supported as you expect by the DZ_GML package.  
   To verify, execute "SELECT dz_gml_main.fetch_gml_namespace(3.2) FROM dual;"
   Replace 3.2 with the version of GML you wish to test is supported.
   
   Parameters:
      p_input - GML version desired for conversion
      
   Returns:
      
      GML namespace text value
      
   Notes:
   
    - Fairly simple logic currently, if less than 3.2 then 
      xmlns:gml="http://www.opengis.net/gml"
      if more than 3.2 and less than 3.3 then
      xmlns:gml="http://www.opengis.net/gml/3.2"
      if more than 3.3 and less than 3.4 then
      xmlns:gml="http://www.opengis.net/gml/3.3"
      else err
   
   */
   FUNCTION fetch_gml_namespace(
      p_input           IN  NUMBER
   ) RETURN VARCHAR2; 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE geogml2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_gml_version      IN  NUMBER   DEFAULT NULL
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
      ,p_status_code      OUT NUMBER
      ,p_status_message   OUT VARCHAR2
   );
   
   PROCEDURE geogml2sdo(
       p_input            IN  CLOB
      ,p_gml_version      IN  NUMBER   DEFAULT NULL
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
      ,p_status_code      OUT NUMBER
      ,p_status_message   OUT VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_gml_main.geogml2sdo
   
   Function for conversion of GML geospatial tags into Oracle Spatial SDO_GEOMETRY
   geometry objects.  This utility does not utilize the java SDO_UTIL.FROM_GMLGEOMETRY 
   or SDO_UTIL.FROM_GML311GEOMETRY utilities in any fashion.  Being a pure PL/SQL
   conversion allows more flexibility in the interpretation of more modern forms of 
   GML.
   
   Parameters:

      p_input - input GML geometry as SYS.XMLTYPE or CLOB. All input must be 
      able to be parsed as Oracle SYS.XMLTYPE so users are encouraged to do that 
      step themselves to avoid issues. The XML snippet should be presented as the 
      geometry alone, without any parent tags - the same as 
      SDO_UTIL.FROM_GMLGEOMETRY and SDO_UTIL.FROM_GML311GEOMETRY expect.
      p_gml_version - nonfunctional at this time.  The parameter was intended as
      a hint when parsing GML when the version is unclear. May still be needed in 
      the future.
      p_srid - override for output SDO_SRID value. The srid is normally extracted 
      from the srsName on the GML object. Use this parameter to force to a given 
      value and skip the logic to search for the value.
      p_num_dims - the number of dimensions is required to properly unpack GML 
      coordinates. This value is normally provided in the srsDimension attribute. 
      Set this parameter to force to a given number and skip the logic to search 
      for the value. Setting this to 2 when you know you just have 2D geometries 
      will provide a modest performance boost.
      p_axes_latlong - Set to TRUE if your input GML has longitude and latitude 
      reversed (e.g. WFS 1.1 and 2.0).
   
   Returns:

      CLOB text in WKT or EWKT format
   
   Notes:
   
    - For more control over conversion attempts which generate specific errors
      utilize the procedure versions which return an error code and status message.  
   
   */
   FUNCTION geogml2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_gml_version      IN  NUMBER   DEFAULT NULL
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY;
   
   FUNCTION geogml2sdo(
       p_input            IN  CLOB
      ,p_gml_version      IN  NUMBER   DEFAULT NULL
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlpolygon2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   ); 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlpolygon2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlsurface2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   ); 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlsurface2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlmultisurface2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   ); 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlmultisurface2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY; 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlpoint2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlpoint2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlmultipoint2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   ); 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlmultipoint2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY; 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlcurve2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlcurve2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmllinestring2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmllinestring2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlmulticurve2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   ); 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlmulticurve2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY; 

END dz_gml_main;
/

GRANT EXECUTE ON dz_gml_main TO PUBLIC;


--*************************--
PROMPT DZ_GML_MAIN.pkb;

CREATE OR REPLACE PACKAGE BODY dz_gml_main
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION sdo2geogml(
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
   AS
      sdo_input        MDSYS.SDO_GEOMETRY := p_input;
      str_2d_flag      VARCHAR2(5 Char)  := UPPER(p_2d_flag);
      str_gml_version  VARCHAR2(8 Char)  := UPPER(p_geometry_format);
      str_axes_latlong VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      str_gml_id       VARCHAR2(4000 Char) := p_gml_id;
      clb_output       CLOB;
      
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Process incoming parameters
      --------------------------------------------------------------------------
      IF str_2d_flag IS NULL
      THEN
         str_2d_flag := 'FALSE';
         
      ELSIF str_2d_flag NOT IN ('TRUE','FALSE')
      THEN
         RAISE_APPLICATION_ERROR(-20001,'boolean error');
         
      END IF;
      
      IF str_gml_version IS NULL
      THEN
         str_gml_version := 'GML2';
         
      END IF;
      
      IF str_axes_latlong IS NULL
      THEN
         str_axes_latlong := 'FALSE';
         
      END IF;
      
      IF str_axes_latlong = 'TRUE'
      THEN 
         RAISE_APPLICATION_ERROR(
             -20001
            ,'reverse axes ordering for GML output not currently supported'
         );
         
      END IF;
      
      IF str_gml_id IS NULL
      THEN
         str_gml_id := '1';
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Downsize to 2D if required
      --------------------------------------------------------------------------      
      IF str_2d_flag = 'TRUE'
      THEN
         sdo_input := dz_gml_util.downsize_2d(
            p_input => sdo_input
         );
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Transform cs if required
      --------------------------------------------------------------------------    
      IF p_output_srid IS NOT NULL
      AND p_output_srid != sdo_input.SDO_SRID
      THEN
         sdo_input := dz_gml_util.smart_transform(
             p_input   => sdo_input
            ,p_srid    => p_output_srid
         );
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Generate the raw GML2 with oracle tools
      --------------------------------------------------------------------------
      IF str_gml_version = 'GML2'
      THEN
         clb_output := MDSYS.SDO_UTIL.TO_GMLGEOMETRY(
            geometry => sdo_input
         );
         
      ELSE
         clb_output := MDSYS.SDO_UTIL.TO_GML311GEOMETRY(
            geometry => sdo_input
         );
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Overrule srs if requested
      --------------------------------------------------------------------------
      IF p_output_srs IS NOT NULL
      THEN
         clb_output := REPLACE(
             clb_output
            ,'srsName="SDO:' || TO_CHAR(sdo_input.SDO_SRID) || '"'
            ,'srsName="' || p_output_srs || '"'
         );
         
      ELSE
         clb_output := REPLACE(
             clb_output
            ,'srsName="SDO:' || TO_CHAR(sdo_input.SDO_SRID) || '"'
            ,'srsName="' || dz_gml_util.srid2srs(sdo_input.SDO_SRID) || '"'
         );
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 60
      -- Push 311 to 32
      --------------------------------------------------------------------------
      IF str_gml_version <> 'GML2'
      THEN
         clb_output := REGEXP_REPLACE(
             clb_output
            ,'xmlns:gml="http://www.opengis.net/gml"'
            ,'gml:id="' || str_gml_id || '" xmlns:gml="http://www.opengis.net/gml/3.2"'
            ,1
            ,1
         );
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 70
      -- Return what we go
      --------------------------------------------------------------------------
      RETURN clb_output;
      
   END sdo2geogml;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION fetch_gml_namespace(
      p_input           IN  NUMBER
   ) RETURN VARCHAR2
   AS
   BEGIN
   
      IF p_input IS NULL
      THEN
         RETURN NULL;
         
      END IF;
   
      IF p_input < 3.2
      THEN
         RETURN 'xmlns:gml="http://www.opengis.net/gml"';
         
      ELSIF p_input >= 3.2 AND p_input < 3.3
      THEN
         RETURN 'xmlns:gml="http://www.opengis.net/gml/3.2"';
         
      ELSIF p_input >= 3.3 AND p_input < 3.4
      THEN
         RETURN 'xmlns:gml="http://www.opengis.net/gml/3.3"';
         
      ELSE
         RAISE_APPLICATION_ERROR(-20001,'unknown gml version');
         
      END IF;
      
   END fetch_gml_namespace;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION sniff_srsDimension(
       p_input            IN  SYS.XMLTYPE
      ,p_namespace        IN  VARCHAR2
      ,p_geometry_type    IN  VARCHAR2
   ) RETURN NUMBER
   AS
      num_dims          NUMBER;
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check the posList or pos first
      --------------------------------------------------------------------------   
      IF p_geometry_type = 'Point'
      THEN
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Point/gml:pos/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;

         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Point/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
         
      ELSIF p_geometry_type = 'Curve'
      THEN
      
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Curve/gml:segments/gml:LineStringSegment/gml:posList/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;

         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Curve/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;

         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Curve/gml:segments/gml:LineStringSegment/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;

         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Curve/gml:segments/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
         
      ELSIF p_geometry_type = 'LineString'
      THEN
      
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:LineString/gml:posList/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:LineString/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF; 
         
      ELSIF p_geometry_type = 'Polygon'
      THEN
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Polygon/gml:exterior/gml:LinearRing/gml:posList/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Polygon/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Polygon/gml:exterior/gml:LinearRing/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;

         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Polygon/gml:exterior/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
      
      ELSIF p_geometry_type = 'MultiPoint'
      THEN
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:MultiPoint/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:MultiPoint/gml:pointMember/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
      
      ELSIF p_geometry_type = 'MultiCurve'
      THEN
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:MultiCurve/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:MultiCurve/gml:curveMember/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
      
      ELSIF p_geometry_type = 'MultiSurface'
      THEN
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:MultiSurface/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;

         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:MultiSurface/gml:surfaceMember/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
         
      ELSIF p_geometry_type = 'Surface'
      THEN
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Surface/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
         
         SELECT EXTRACTVALUE(
             p_input
            ,'/gml:Surface/gml:surfaceMember/@srsDimension'
            ,p_namespace
         ) 
         INTO num_dims
         FROM dual;
         
         IF num_dims IS NOT NULL
         THEN
            RETURN num_dims;
            
         END IF;
      
      ELSE
         RAISE_APPLICATION_ERROR(-20001,'unimplemented geometry type');
         
      END IF;
      
      RETURN num_dims;
         
   END sniff_srsDimension;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION sniff_srsName(
       p_input            IN  SYS.XMLTYPE
      ,p_namespace        IN  VARCHAR2
      ,p_geometry_type    IN  VARCHAR2
   ) RETURN VARCHAR2
   AS
      str_name  VARCHAR2(4000 Char);
      
   BEGIN
      SELECT EXTRACTVALUE(
          p_input
         ,'/gml:' || p_geometry_type || '/@srsName'
         ,p_namespace
      ) 
      INTO str_name
      FROM dual;
      
      RETURN str_name;
      
   END sniff_srsName;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gml_coords2sdo_point(
       p_input            IN  CLOB
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN MDSYS.SDO_POINT_TYPE
   AS
      int_offset       PLS_INTEGER := 1;
      int_index        PLS_INTEGER := 1;
      int_start        PLS_INTEGER := 0;
      num_x            NUMBER;
      num_y            NUMBER;
      num_z            NUMBER;
      int_length       PLS_INTEGER;
      str_axes_latlong VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF str_axes_latlong IS NULL
      THEN
         str_axes_latlong := 'FALSE';
         
      END IF;
   
      --------------------------------------------------------------------------
      -- Step 20
      -- Loop through the input gml point clob breaking on commas
      --------------------------------------------------------------------------
      WHILE int_offset <= int_length
      LOOP
         IF SUBSTR(p_input,int_offset,1) IN (',',' ')
         THEN
            IF int_index = 1
            THEN
               num_x := dz_gml_util.safe_to_number(
                  SUBSTR(p_input,(int_start + 1),(int_offset - (int_start + 1)))
               );
               
            ELSIF int_index = 2
            THEN
               num_y := dz_gml_util.safe_to_number(
                  SUBSTR(p_input,(int_start + 1),(int_offset - (int_start + 1)))
               );
               
            ELSIF int_index = 3
            THEN
               num_z := dz_gml_util.safe_to_number(
                  SUBSTR(p_input,int_start,(int_offset - (int_start + 1)))
               );
               
            END IF;
            
            int_index := int_index + 1;
            int_start := int_offset;
            
         END IF;
         
         int_offset := int_offset + 1;
            
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Check for remaining coordinates
      --------------------------------------------------------------------------
      IF int_start + 1 = int_offset
      THEN
         NULL;
         
      ELSE
         IF int_index = 1
         THEN
            num_x := dz_gml_util.safe_to_number(
               SUBSTR(p_input,int_start + 1,(int_offset - (int_start + 1)))
            );
            
         ELSIF int_index = 2
         THEN
            num_y := dz_gml_util.safe_to_number(
               SUBSTR(p_input,int_start + 1,(int_offset - (int_start + 1)))
            );
            
         ELSIF int_index = 3
         THEN
            num_z := dz_gml_util.safe_to_number(
               SUBSTR(p_input,int_start,(int_offset - (int_start + 1)))
            );
            
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Cough out the results
      --------------------------------------------------------------------------
      IF str_axes_latlong = 'TRUE'
      THEN
         RETURN MDSYS.SDO_POINT_TYPE(num_y,num_x,num_z);
         
      ELSE
         RETURN MDSYS.SDO_POINT_TYPE(num_x,num_y,num_z); 
           
      END IF;
      
   END gml_coords2sdo_point;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gml_coords2sdo_ords(
       p_input            IN  CLOB
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_ORDINATE_ARRAY
   AS
      int_offset       PLS_INTEGER := 1;
      int_start        PLS_INTEGER := 0;
      int_ary_index    PLS_INTEGER := 1;
      ary_output       MDSYS.SDO_ORDINATE_ARRAY;
      int_length       PLS_INTEGER;
      num_check        NUMBER;
      str_axes_latlong VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      int_position     SIMPLE_INTEGER := 1;
      
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF str_axes_latlong IS NULL
      THEN
         str_axes_latlong := 'FALSE';
         
      END IF;
      
      IF str_axes_latlong = 'TRUE'
      AND p_num_dims IS NULL
      THEN
         RAISE_APPLICATION_ERROR(
             -20001
            ,'unable to unpack X and Y without number of dimensions'
         );
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Loop through the input gml coordinate clob breaking on commas and spaces
      --------------------------------------------------------------------------
      int_length := LENGTH(p_input);
      ary_output := MDSYS.SDO_ORDINATE_ARRAY();
      
      WHILE int_offset <= int_length
      LOOP
         
         IF SUBSTR(p_input,int_offset,1) IN (',',' ')
         THEN
            num_check := dz_gml_util.safe_to_number(
               SUBSTR(p_input,int_start + 1,(int_offset - (int_start + 1)))
            );
            
            IF num_check IS NOT NULL
            THEN
               ary_output.EXTEND();
               
               IF str_axes_latlong = 'TRUE'
               AND int_position = 2
               THEN
                  ary_output(int_ary_index) := ary_output(int_ary_index-1);
                  ary_output(int_ary_index-1) := num_check;
                  
               ELSE
                  ary_output(int_ary_index) := num_check;
                  
               END IF;
               
               int_ary_index := int_ary_index + 1;
               int_start := int_offset;
               
            END IF;
            
            int_position := int_position + 1;
            IF int_position > p_num_dims
            THEN
               int_position := 1;
               
            END IF;
            
         END IF;
         
         int_offset := int_offset + 1;
            
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Check for remaining coordinates
      --------------------------------------------------------------------------
      IF int_start + 1 = int_offset
      THEN
         NULL;
         
      ELSE
         ary_output.EXTEND();
         
         IF str_axes_latlong = 'TRUE'
         AND int_position = 2
         THEN
            ary_output(int_ary_index)   := ary_output(int_ary_index-1);
            ary_output(int_ary_index-1) := dz_gml_util.safe_to_number(
               SUBSTR(p_input,int_start + 1,(int_offset - (int_start + 1)))
            );
            
         ELSE
            ary_output(int_ary_index) := dz_gml_util.safe_to_number(
               SUBSTR(p_input,int_start + 1,(int_offset - (int_start + 1)))
            );
                  
         END IF;
                  
         int_ary_index := int_ary_index + 1;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Cough out the results
      --------------------------------------------------------------------------
      RETURN ary_output; 
      
   END gml_coords2sdo_ords;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE geogml2sdo(
       p_input            IN  CLOB
      ,p_gml_version      IN  NUMBER   DEFAULT NULL
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
      ,p_status_code      OUT NUMBER
      ,p_status_message   OUT VARCHAR2
   )
   AS
      xml_input SYS.XMLTYPE;
      
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      p_status_code := 0;
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Convert incoming GML into XMLTYPE
      --------------------------------------------------------------------------
      xml_input := XMLTYPE(p_input);
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Process results
      --------------------------------------------------------------------------
      geogml2sdo(
          p_input          => xml_input
         ,p_gml_version    => p_gml_version
         ,p_srid           => p_srid
         ,p_num_dims       => p_num_dims
         ,p_axes_latlong   => p_axes_latlong
         ,p_output         => p_output
         ,p_gml_id         => p_gml_id
         ,p_status_code    => p_status_code
         ,p_status_message => p_status_message
      );
   
   END geogml2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE geogml2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_gml_version      IN  NUMBER   DEFAULT NULL
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
      ,p_status_code      OUT NUMBER
      ,p_status_message   OUT VARCHAR2
   )
   AS
      str_namespace      VARCHAR2(4000 Char);
      str_rootnode       VARCHAR2(4000 Char);
      num_srid           NUMBER := p_srid;
      num_dims           NUMBER := p_num_dims;
      str_axes_latlong   VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      str_srs            VARCHAR2(4000 Char);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      p_status_code := 0;
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Test the gml namespace
      --------------------------------------------------------------------------
      IF p_input.getNamespace() IS NULL
      THEN
         p_status_code    := -100;
         p_status_message := 'gml namespace required';
         RETURN;
         
      END IF;
      
      str_namespace := 'xmlns:gml="' || p_input.getNamespace() || '"';
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Determine what is in the input
      --------------------------------------------------------------------------
      SELECT EXTRACT(
          p_input
         ,'/*'
         ,str_namespace
      ).getRootElement() 
      INTO str_rootnode
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Sniff for the srsName, may be deeper
      --------------------------------------------------------------------------
      IF num_srid IS NULL
      THEN
         str_srs := sniff_srsName(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => str_rootnode
         );
         
         dz_gml_util.srs2srid(
             p_input        => str_srs
            ,p_srid         => num_srid
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF p_axes_latlong IS NOT NULL
         THEN
             str_axes_latlong := UPPER(p_axes_latlong);
             
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Branch as needed
      --------------------------------------------------------------------------
      IF str_rootnode = 'Point'
      THEN
         gmlpoint2sdo(
             p_input        => p_input
            ,p_srid         => num_srid
            ,p_num_dims     => num_dims
            ,p_namespace    => str_namespace
            ,p_axes_latlong => str_axes_latlong
            ,p_output       => p_output
            ,p_gml_id       => p_gml_id
         );
      
      ELSIF str_rootnode = 'Curve'
      THEN
         gmlcurve2sdo(
             p_input        => p_input
            ,p_srid         => num_srid
            ,p_num_dims     => num_dims
            ,p_namespace    => str_namespace
            ,p_axes_latlong => str_axes_latlong
            ,p_output       => p_output
            ,p_gml_id       => p_gml_id
         );
         
      ELSIF str_rootnode = 'LineString'
      THEN
         gmllinestring2sdo(
             p_input        => p_input
            ,p_srid         => num_srid
            ,p_num_dims     => num_dims
            ,p_namespace    => str_namespace
            ,p_axes_latlong => str_axes_latlong
            ,p_output       => p_output
            ,p_gml_id       => p_gml_id
         );
         
      ELSIF str_rootnode = 'Polygon'
      THEN
         gmlpolygon2sdo(
             p_input        => p_input
            ,p_srid         => num_srid
            ,p_num_dims     => num_dims
            ,p_namespace    => str_namespace
            ,p_axes_latlong => str_axes_latlong
            ,p_output       => p_output
            ,p_gml_id       => p_gml_id
         );
         
      ELSIF str_rootnode = 'MultiPoint'
      THEN
         gmlmultipoint2sdo(
             p_input        => p_input
            ,p_srid         => num_srid
            ,p_num_dims     => num_dims
            ,p_namespace    => str_namespace
            ,p_axes_latlong => str_axes_latlong
            ,p_output       => p_output
            ,p_gml_id       => p_gml_id
         );
      
      ELSIF str_rootnode = 'MultiSurface'
      THEN
         gmlmultisurface2sdo(
             p_input        => p_input
            ,p_srid         => num_srid
            ,p_num_dims     => num_dims
            ,p_namespace    => str_namespace
            ,p_axes_latlong => str_axes_latlong
            ,p_output       => p_output
            ,p_gml_id       => p_gml_id
         );
         
      ELSIF str_rootnode = 'MultiCurve'
      THEN
         gmlmulticurve2sdo(
             p_input        => p_input
            ,p_srid         => num_srid
            ,p_num_dims     => num_dims
            ,p_namespace    => str_namespace
            ,p_axes_latlong => str_axes_latlong
            ,p_output       => p_output
            ,p_gml_id       => p_gml_id
         );
      
      ELSIF str_rootnode = 'Surface'
      THEN
         gmlsurface2sdo(
             p_input        => p_input
            ,p_srid         => num_srid
            ,p_num_dims     => num_dims
            ,p_namespace    => str_namespace
            ,p_axes_latlong => str_axes_latlong
            ,p_output       => p_output
            ,p_gml_id       => p_gml_id
         );
      
      ELSE 
         RAISE_APPLICATION_ERROR(
             -20001
            ,'not able to process, ' || str_rootnode || ' not implemented'
         );
         
      END IF;
      
   END geogml2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION geogml2sdo(
       p_input            IN  CLOB
      ,p_gml_version      IN  NUMBER   DEFAULT NULL
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output         MDSYS.SDO_GEOMETRY;
      str_id             VARCHAR2(4000 Char);
      num_status_code    NUMBER;
      str_status_message VARCHAR2(4000 Char);
      
   BEGIN
   
      geogml2sdo(
          p_input          => p_input
         ,p_gml_version    => p_gml_version
         ,p_srid           => p_srid
         ,p_num_dims       => p_num_dims
         ,p_axes_latlong   => p_axes_latlong
         ,p_output         => sdo_output
         ,p_gml_id         => str_id
         ,p_status_code    => num_status_code
         ,p_status_message => str_status_message
      );
      
      IF num_status_code = 0
      THEN
         RETURN sdo_output;
      
      ELSE
         RAISE_APPLICATION_ERROR(-20001,str_status_message);
         
      END IF;
      
   END geogml2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION geogml2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_gml_version      IN  NUMBER   DEFAULT NULL
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output         MDSYS.SDO_GEOMETRY;
      str_id             VARCHAR2(4000 Char);
      num_status_code    NUMBER;
      str_status_message VARCHAR2(4000 Char);
   
   BEGIN
   
      geogml2sdo(
          p_input          => p_input
         ,p_gml_version    => p_gml_version
         ,p_srid           => p_srid
         ,p_num_dims       => p_num_dims
         ,p_axes_latlong   => p_axes_latlong
         ,p_output         => sdo_output
         ,p_gml_id         => str_id
         ,p_status_code    => num_status_code
         ,p_status_message => str_status_message
      );
      
      IF num_status_code = 0
      THEN
         RETURN sdo_output;
      
      ELSE
         RAISE_APPLICATION_ERROR(-20001,str_status_message);
         
      END IF;
      
   END geogml2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlpolygon2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   )
   AS
      clb_exterior_ring   CLOB;
      ary_interior_rings  dz_gml_ords_vry;
      int_index           PLS_INTEGER;
      sdoord_exterior     MDSYS.SDO_ORDINATE_ARRAY;
      str_srs             VARCHAR2(4000 Char);
      num_srid            NUMBER := p_srid;
      num_dims            NUMBER := p_num_dims;
      sdo_info            MDSYS.SDO_ELEM_INFO_ARRAY;
      num_offset          NUMBER;
      str_namespace       VARCHAR2(4000 Char) := p_namespace;
      str_axes_latlong    VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Validate the namespace
      --------------------------------------------------------------------------
      IF str_namespace IS NULL
      THEN
         IF p_input.getNamespace() IS NULL
         THEN
            RAISE_APPLICATION_ERROR(-20001,'gml namespace is required');
         END IF;
         
         str_namespace := 'xmlns:gml="' || p_input.getNamespace() || '"';
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Pull out the polygon id
      --------------------------------------------------------------------------
      SELECT EXTRACTVALUE(
          p_input
         ,'/gml:Polygon/@gml:id'
         ,str_namespace
      ) 
      INTO p_gml_id
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Pull out the srs information if incoming srid is null
      --------------------------------------------------------------------------
      IF num_srid IS NULL
      THEN
         str_srs := sniff_srsName(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'Polygon'
         );
         
         dz_gml_util.srs2srid(
             p_input        => str_srs
            ,p_srid         => num_srid
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF p_axes_latlong IS NOT NULL
         THEN
             str_axes_latlong := UPPER(p_axes_latlong);
             
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Sniff for the dimensions of the deal
      --------------------------------------------------------------------------
      IF num_dims IS NULL
      THEN
         num_dims := sniff_srsDimension(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'Polygon'
         );
         
         IF num_dims IS NULL
         THEN
            num_dims := 2;
            
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Slurp out the exterior ring
      --------------------------------------------------------------------------
      SELECT EXTRACT(
          p_input
         ,'/gml:Polygon/gml:exterior/gml:LinearRing/gml:posList/text()'
         ,str_namespace
      ).getClobVal() 
      INTO clb_exterior_ring
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 60
      -- Convert exterior ring to sdo_ordinate_array
      --------------------------------------------------------------------------
      sdoord_exterior := gml_coords2sdo_ords(
          p_input        => clb_exterior_ring
         ,p_num_dims     => num_dims
         ,p_axes_latlong => str_axes_latlong
      );
      
      clb_exterior_ring := NULL;
      IF dz_gml_util.test_ordinate_rotation(
          p_input    => sdoord_exterior
         ,p_num_dims => num_dims
      ) = 'CW'
      THEN
         dz_gml_util.reverse_ordinate_rotation(
             p_input     => sdoord_exterior
            ,p_num_dims  => num_dims
         );
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 70
      -- Slurp out the interior rings
      --------------------------------------------------------------------------
      int_index := 1;
      ary_interior_rings := dz_gml_ords_vry();
      FOR i IN (
         SELECT
         EXTRACT(
             VALUE(t)
            ,'/gml:LinearRing/gml:posList/text()'
            ,str_namespace
         ) poslist
         FROM
         TABLE(
            XMLSEQUENCE(
               EXTRACT(
                   p_input
                  ,'/gml:Polygon/gml:interior/gml:LinearRing'
                  ,str_namespace
               )
            )
         ) t
      )
      LOOP
         ary_interior_rings.EXTEND();
         ary_interior_rings(int_index) := gml_coords2sdo_ords(
             p_input        => i.poslist.getClobVal()
            ,p_num_dims     => num_dims
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF dz_gml_util.test_ordinate_rotation(ary_interior_rings(int_index)) = 'CCW'
         THEN
            dz_gml_util.reverse_ordinate_rotation(
                p_input => ary_interior_rings(int_index)
               ,p_num_dims => num_dims
            );
         END IF;

         int_index := int_index + 1;
            
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 80
      -- Build the info and ordinates
      --------------------------------------------------------------------------
      num_offset := 1;
      sdo_info   := MDSYS.SDO_ELEM_INFO_ARRAY(num_offset,1003,1);
      num_offset := num_offset + sdoord_exterior.COUNT;
      
      --------------------------------------------------------------------------
      -- Step 90
      -- Add in the holes
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_interior_rings.COUNT
      LOOP
         dz_gml_util.append2(
             p_input   => sdo_info
            ,p_value   => num_offset
            ,p_value_2 => 2003
            ,p_value_3 => 1
         );
         num_offset := num_offset + ary_interior_rings(i).COUNT;
         
         dz_gml_util.append2(
             p_input   => sdoord_exterior
            ,p_value   => ary_interior_rings(i)
         );
         
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 100
      -- Build the new geometry
      --------------------------------------------------------------------------
      p_output := MDSYS.SDO_GEOMETRY(
          TO_NUMBER(TO_CHAR(num_dims) || '003')
         ,num_srid
         ,NULL
         ,sdo_info
         ,sdoord_exterior
      );
      
   END gmlpolygon2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlpolygon2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output MDSYS.SDO_GEOMETRY;
      str_id     VARCHAR2(4000 Char);
      
   BEGIN
      gmlpolygon2sdo(
          p_input        => p_input
         ,p_srid         => p_srid
         ,p_num_dims     => p_num_dims
         ,p_namespace    => p_namespace
         ,p_axes_latlong => p_axes_latlong
         ,p_output       => sdo_output
         ,p_gml_id       => str_id
      );
      
      RETURN sdo_output;      
      
   END gmlpolygon2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlpolygonpatch2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   )
   AS
      clb_exterior_ring   CLOB;
      ary_interior_rings  dz_gml_ords_vry;
      int_index           PLS_INTEGER;
      sdoord_exterior     MDSYS.SDO_ORDINATE_ARRAY;
      str_srs             VARCHAR2(4000 Char);
      num_srid            NUMBER := p_srid;
      num_dims            NUMBER := p_num_dims;
      sdo_info            MDSYS.SDO_ELEM_INFO_ARRAY;
      num_offset          NUMBER;
      str_namespace       VARCHAR2(4000 Char) := p_namespace;
      str_axes_latlong    VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Validate the namespace
      --------------------------------------------------------------------------
      IF str_namespace IS NULL
      THEN
         IF p_input.getNamespace() IS NULL
         THEN
            RAISE_APPLICATION_ERROR(-20001,'gml namespace is required');
         END IF;
         
         str_namespace := 'xmlns:gml="' || p_input.getNamespace() || '"';
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Pull out the polygon id
      --------------------------------------------------------------------------
      SELECT EXTRACTVALUE(
          p_input
         ,'/gml:PolygonPatch/@gml:id'
         ,str_namespace
      ) 
      INTO p_gml_id
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Pull out the srs information if incoming srid is null
      --------------------------------------------------------------------------
      IF num_srid IS NULL
      THEN
         str_srs := sniff_srsName(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'PolygonPatch'
         );
         
         dz_gml_util.srs2srid(
             p_input        => str_srs
            ,p_srid         => num_srid
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF p_axes_latlong IS NOT NULL
         THEN
             str_axes_latlong := UPPER(p_axes_latlong);
             
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Sniff for the dimensions of the deal
      --------------------------------------------------------------------------
      IF num_dims IS NULL
      THEN
         num_dims := sniff_srsDimension(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'PolygonPatch'
         );
         
         IF num_dims IS NULL
         THEN
            num_dims := 2;
            
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Slurp out the exterior ring
      --------------------------------------------------------------------------
      SELECT EXTRACT(
          p_input
         ,'/gml:PolygonPatch/gml:exterior/gml:LinearRing/gml:posList/text()'
         ,str_namespace
      ).getClobVal() 
      INTO clb_exterior_ring
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 60
      -- Convert exterior ring to sdo_ordinate_array
      --------------------------------------------------------------------------
      sdoord_exterior := gml_coords2sdo_ords(
          p_input        => clb_exterior_ring
         ,p_num_dims     => num_dims
         ,p_axes_latlong => str_axes_latlong
      );
      
      clb_exterior_ring := NULL;
      IF dz_gml_util.test_ordinate_rotation(
          p_input    => sdoord_exterior
         ,p_num_dims => num_dims
      ) = 'CW'
      THEN
         dz_gml_util.reverse_ordinate_rotation(
             p_input     => sdoord_exterior
            ,p_num_dims  => num_dims
         );
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 70
      -- Slurp out the interior rings
      --------------------------------------------------------------------------
      int_index := 1;
      ary_interior_rings := dz_gml_ords_vry();
      FOR i IN (
         SELECT
         EXTRACT(
             VALUE(t)
            ,'/gml:LinearRing/gml:posList/text()'
            ,str_namespace
         ) poslist
         FROM
         TABLE(
            XMLSEQUENCE(
               EXTRACT(
                   p_input
                  ,'/gml:PolygonPatch/gml:interior/gml:LinearRing'
                  ,str_namespace
               )
            )
         ) t
      )
      LOOP
         ary_interior_rings.EXTEND();
         ary_interior_rings(int_index) := gml_coords2sdo_ords(
             p_input        => i.poslist.getClobVal()
            ,p_num_dims     => num_dims
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF dz_gml_util.test_ordinate_rotation(ary_interior_rings(int_index)) = 'CCW'
         THEN
            dz_gml_util.reverse_ordinate_rotation(
                p_input => ary_interior_rings(int_index)
               ,p_num_dims => num_dims
            );
         END IF;

         int_index := int_index + 1;
            
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 80
      -- Build the info and ordinates
      --------------------------------------------------------------------------
      num_offset := 1;
      sdo_info   := MDSYS.SDO_ELEM_INFO_ARRAY(num_offset,1003,1);
      num_offset := num_offset + sdoord_exterior.COUNT;
      
      --------------------------------------------------------------------------
      -- Step 90
      -- Add in the holes
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_interior_rings.COUNT
      LOOP
         dz_gml_util.append2(
             p_input   => sdo_info
            ,p_value   => num_offset
            ,p_value_2 => 2003
            ,p_value_3 => 1
         );
         num_offset := num_offset + ary_interior_rings(i).COUNT;
         
         dz_gml_util.append2(
             p_input   => sdoord_exterior
            ,p_value   => ary_interior_rings(i)
         );
         
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 100
      -- Build the new geometry
      --------------------------------------------------------------------------
      p_output := MDSYS.SDO_GEOMETRY(
          TO_NUMBER(TO_CHAR(num_dims) || '003')
         ,num_srid
         ,NULL
         ,sdo_info
         ,sdoord_exterior
      );
      
   END gmlpolygonpatch2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlsurface2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   )
   AS
      str_id              VARCHAR2(4000 Char);
      sdo_temp            MDSYS.SDO_GEOMETRY;
      int_index           PLS_INTEGER;
      str_srs             VARCHAR2(4000 Char);
      num_srid            NUMBER := p_srid;
      num_dims            NUMBER := p_num_dims;
      str_namespace       VARCHAR2(4000 Char) := p_namespace;
      str_axes_latlong    VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Validate the namespace
      --------------------------------------------------------------------------
      IF str_namespace IS NULL
      THEN
         IF p_input.getNamespace() IS NULL
         THEN
            RAISE_APPLICATION_ERROR(-20001,'gml namespace is required');
            
         END IF;
         
         str_namespace := 'xmlns:gml="' || p_input.getNamespace() || '"';
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Pull out the Surface id
      --------------------------------------------------------------------------
      SELECT EXTRACTVALUE(
          p_input
         ,'/gml:Surface/@gml:id'
         ,str_namespace
      ) 
      INTO p_gml_id
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Pull out the srs information if incoming srid is null
      --------------------------------------------------------------------------
      IF num_srid IS NULL
      THEN
         str_srs := sniff_srsName(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'Surface'
         );
         
         dz_gml_util.srs2srid(
             p_input        => str_srs
            ,p_srid         => num_srid
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF p_axes_latlong IS NOT NULL
         THEN
             str_axes_latlong := UPPER(p_axes_latlong);
             
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Sniff for the dimensions of the deal
      --------------------------------------------------------------------------
      IF num_dims IS NULL
      THEN
         num_dims := sniff_srsDimension(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'Surface'
         );
         
         IF num_dims IS NULL
         THEN
            num_dims := 2;
            
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Extract the patches
      --------------------------------------------------------------------------
      int_index := 1;
      FOR i IN (
         SELECT
         VALUE(t) poslist
         FROM
         TABLE(
            XMLSEQUENCE(
               EXTRACT(
                   p_input
                  ,'/gml:Surface/gml:patches/gml:PolygonPatch'
                  ,str_namespace
               )
            )
         ) t
      )
      LOOP
         gmlpolygonpatch2sdo(
              p_input        => i.poslist
             ,p_srid         => num_srid
             ,p_num_dims     => num_dims
             ,p_namespace    => str_namespace
             ,p_axes_latlong => str_axes_latlong
             ,p_output       => sdo_temp
             ,p_gml_id       => str_id
         );
         
         IF p_output IS NULL
         THEN
            p_output := sdo_temp;
            
         ELSE
            p_output := MDSYS.SDO_UTIL.APPEND(
                p_output
               ,sdo_temp
            );
            
         END IF;
                    
      END LOOP;
      
   END gmlsurface2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlsurface2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output MDSYS.SDO_GEOMETRY;
      str_id     VARCHAR2(4000 Char);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         RETURN NULL;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      gmlsurface2sdo(
          p_input        => p_input
         ,p_srid         => p_srid
         ,p_num_dims     => p_num_dims
         ,p_namespace    => p_namespace
         ,p_axes_latlong => p_axes_latlong
         ,p_output       => sdo_output
         ,p_gml_id       => str_id
      );
      
   END gmlsurface2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlmultisurface2sdo(
       p_input           IN  SYS.XMLTYPE
      ,p_srid            IN  NUMBER   DEFAULT NULL
      ,p_num_dims        IN  NUMBER   DEFAULT NULL
      ,p_namespace       IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong    IN  VARCHAR2 DEFAULT NULL
      ,p_output          OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id          OUT VARCHAR2
   )
   AS
      sdo_temp            MDSYS.SDO_GEOMETRY;
      int_index           PLS_INTEGER;
      str_srs             VARCHAR2(4000 Char);
      num_srid            NUMBER := p_srid;
      num_dims            NUMBER := p_num_dims;
      str_id              VARCHAR2(4000 Char);
      str_namespace       VARCHAR2(4000 Char) := p_namespace;
      str_axes_latlong    VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Validate the namespace
      --------------------------------------------------------------------------
      IF str_namespace IS NULL
      THEN
         IF p_input.getNamespace() IS NULL
         THEN
            RAISE_APPLICATION_ERROR(-20001,'gml namespace is required');
            
         END IF;
         
         str_namespace := 'xmlns:gml="' || p_input.getNamespace() || '"';
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Pull out the polygon id
      --------------------------------------------------------------------------
      SELECT EXTRACTVALUE(
          p_input
         ,'/gml:MultiSurface/@gml:id'
         ,str_namespace
      ) 
      INTO p_gml_id
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Pull out the srs information if srid is null
      --------------------------------------------------------------------------
      IF num_srid IS NULL
      THEN
         str_srs := sniff_srsName(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'MultiSurface'
         );
         
         dz_gml_util.srs2srid(
             p_input        => str_srs
            ,p_srid         => num_srid
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF p_axes_latlong IS NOT NULL
         THEN
             str_axes_latlong := UPPER(p_axes_latlong);
             
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Sniff for dimension information up top
      --------------------------------------------------------------------------
      IF num_dims IS NULL
      THEN
         num_dims := sniff_srsDimension(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'MultiSurface'
         );
      
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 60
      -- Slurp out the component polygons
      --------------------------------------------------------------------------
      int_index := 1;
      FOR i IN (
         SELECT
         VALUE(t) poslist
         FROM
         TABLE(
            XMLSEQUENCE(
               EXTRACT(
                   p_input
                  ,'/gml:MultiSurface/gml:surfaceMember/gml:Polygon'
                  ,str_namespace
               )
            )
         ) t
      )
      LOOP
         gmlpolygon2sdo(
              p_input        => i.poslist
             ,p_srid         => num_srid
             ,p_num_dims     => num_dims
             ,p_namespace    => str_namespace
             ,p_axes_latlong => str_axes_latlong
             ,p_output       => sdo_temp
             ,p_gml_id       => str_id
         );
         
         IF p_output IS NULL
         THEN
            p_output := sdo_temp;
            
         ELSE
            p_output := MDSYS.SDO_UTIL.APPEND(
                p_output
               ,sdo_temp
            );
            
         END IF;
                    
      END LOOP;
      
   END gmlmultisurface2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlmultisurface2sdo(
       p_input           IN  SYS.XMLTYPE
      ,p_srid            IN  NUMBER   DEFAULT NULL
      ,p_num_dims        IN  NUMBER   DEFAULT NULL
      ,p_namespace       IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong    IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output MDSYS.SDO_GEOMETRY;
      str_id     VARCHAR2(4000 Char);
      
   BEGIN
   
      gmlmultisurface2sdo(
          p_input        => p_input
         ,p_srid         => p_srid
         ,p_num_dims     => p_num_dims
         ,p_namespace    => p_namespace
         ,p_axes_latlong => p_axes_latlong
         ,p_output       => sdo_output
         ,p_gml_id       => str_id
      );
      
      RETURN sdo_output; 
      
   END gmlmultisurface2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlpoint2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   )
   AS
      str_srs             VARCHAR2(4000 Char);
      num_srid            NUMBER := p_srid;
      num_dims            NUMBER := p_num_dims;
      str_namespace       VARCHAR2(4000 Char) := p_namespace;
      str_point_val       VARCHAR2(4000 Char);
      ary_ordinates       MDSYS.SDO_STRING2_ARRAY;
      num_1st             NUMBER;
      num_2nd             NUMBER;
      num_3rd             NUMBER;
      num_4th             NUMBER;
      str_axes_latlong    VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Validate the namespace
      --------------------------------------------------------------------------
      IF str_namespace IS NULL
      THEN
         IF p_input.getNamespace() IS NULL
         THEN
            RAISE_APPLICATION_ERROR(-20001,'gml namespace is required');
            
         END IF;
         
         str_namespace := 'xmlns:gml="' || p_input.getNamespace() || '"';
      
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Pull out the point id
      --------------------------------------------------------------------------
      SELECT EXTRACTVALUE(
          p_input
         ,'/gml:Point/@gml:id'
         ,str_namespace
      ) 
      INTO p_gml_id
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Pull out the srs information if srid is null
      --------------------------------------------------------------------------
      IF num_srid IS NULL
      THEN
         str_srs := sniff_srsName(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'Point'
         );
         
         dz_gml_util.srs2srid(
             p_input        => str_srs
            ,p_srid         => num_srid
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF p_axes_latlong IS NOT NULL
         THEN
             str_axes_latlong := UPPER(p_axes_latlong);
             
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Sniff for the dimensions of the deal
      --------------------------------------------------------------------------
      IF num_dims IS NULL
      THEN
         num_dims := sniff_srsDimension(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'Point'
         );
      
         IF num_dims IS NULL
         THEN
            num_dims := 2;
            
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 60
      -- Extract the point value string
      --------------------------------------------------------------------------   
      SELECT EXTRACT(
          p_input
         ,'/gml:Point/gml:pos/text()'
         ,str_namespace
      ).getStringVal() 
      INTO str_point_val
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 70
      -- Split into X and Y
      --------------------------------------------------------------------------
      ary_ordinates := dz_gml_util.gz_split(
          p_str   => str_point_val
         ,p_regex => ' |,'
      );
      
      IF ary_ordinates IS NULL
      OR ary_ordinates.COUNT < num_dims
      THEN
         RAISE_APPLICATION_ERROR(
             -20001
            ,'unable to parse gml:Point coordinates! => ' || str_point_val
         );
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 80
      -- Return results
      --------------------------------------------------------------------------
      IF num_dims = 2
      THEN
         IF str_axes_latlong = 'TRUE'
         THEN
            num_1st := ary_ordinates(2);
            num_2nd := ary_ordinates(1);
            
         ELSE
            num_1st := ary_ordinates(1);
            num_2nd := ary_ordinates(2);
            
         END IF;
      
         p_output := MDSYS.SDO_GEOMETRY(
             2001
            ,num_srid
            ,MDSYS.SDO_POINT_TYPE(
                 num_1st
                ,num_2nd
                ,NULL
             )
            ,NULL
            ,NULL
         );
         
      ELSIF num_dims = 3
      THEN
         IF str_axes_latlong = 'TRUE'
         THEN
            num_1st := ary_ordinates(2);
            num_2nd := ary_ordinates(1);
            num_3rd := ary_ordinates(3);
            
         ELSE
            num_1st := ary_ordinates(1);
            num_2nd := ary_ordinates(2);
            num_3rd := ary_ordinates(3);
            
         END IF;
      
         p_output := MDSYS.SDO_GEOMETRY(
             3001
            ,num_srid
            ,MDSYS.SDO_POINT_TYPE(
                 num_1st
                ,num_2nd
                ,num_3rd
             )
            ,NULL
            ,NULL
         );
         
      ELSIF num_dims = 4
      THEN
         IF str_axes_latlong = 'TRUE'
         THEN
            num_1st := ary_ordinates(2);
            num_2nd := ary_ordinates(1);
            num_3rd := ary_ordinates(3);
            num_4th := ary_ordinates(4);
            
         ELSE
            num_1st := ary_ordinates(1);
            num_2nd := ary_ordinates(2);
            num_3rd := ary_ordinates(3);
            num_4th := ary_ordinates(4);
            
         END IF;
      
         p_output := MDSYS.SDO_GEOMETRY(
             4001
            ,num_srid
            ,NULL
            ,MDSYS.SDO_ELEM_INFO_ARRAY(1,1,1)
            ,MDSYS.SDO_ORDINATE_ARRAY(
                 num_1st
                ,num_2nd
                ,num_3rd
                ,num_4th
             )
         );
      ELSE
         RAISE_APPLICATION_ERROR(
             -20001
            ,'strange number of dimensions => ' || TO_CHAR(num_dims)
         );
         
      END IF;
   
   END gmlpoint2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlpoint2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output MDSYS.SDO_GEOMETRY;
      str_id     VARCHAR2(4000 Char);
      
   BEGIN
   
      gmlpoint2sdo(
          p_input        => p_input
         ,p_srid         => p_srid
         ,p_num_dims     => p_num_dims
         ,p_namespace    => p_namespace
         ,p_axes_latlong => p_axes_latlong
         ,p_output       => sdo_output
         ,p_gml_id       => str_id
      );
      
      RETURN sdo_output;
      
   END gmlpoint2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlcurve2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   )
   AS
      int_index           PLS_INTEGER;
      sdo_temp            MDSYS.SDO_GEOMETRY;
      str_srs             VARCHAR2(4000 Char);
      num_srid            NUMBER := p_srid;
      num_dims            NUMBER := p_num_dims;
      str_namespace       VARCHAR2(4000 Char) := p_namespace;
      clb_linestring      CLOB;
      str_axes_latlong    VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      
      FUNCTION build_linestring(
          p_input MDSYS.SDO_ORDINATE_ARRAY
         ,p_srid  NUMBER
         ,p_dims  NUMBER
      ) RETURN MDSYS.SDO_GEOMETRY
      AS
         num_dims    NUMBER := p_dims;
         
      BEGIN
      
         IF num_dims IS NULL
         THEN
            num_dims := 2;
            
         END IF;
         
         IF num_dims = 2
         THEN
            RETURN MDSYS.SDO_GEOMETRY(
                2002
               ,p_srid
               ,NULL
               ,MDSYS.SDO_ELEM_INFO_ARRAY(1,2,1)
               ,p_input
            );
            
         ELSIF num_dims = 3
         THEN
            RETURN MDSYS.SDO_GEOMETRY(
                3002
               ,p_srid
               ,NULL
               ,MDSYS.SDO_ELEM_INFO_ARRAY(1,2,1)
               ,p_input
            );
            
         ELSIF num_dims = 4
         THEN
            RETURN MDSYS.SDO_GEOMETRY(
                4002
               ,p_srid
               ,NULL
               ,MDSYS.SDO_ELEM_INFO_ARRAY(1,2,1)
               ,p_input
            );
            
         ELSE
            RAISE_APPLICATION_ERROR(-20001,'odd dimensions!');
            
         END IF;
      
      END build_linestring;
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         RETURN;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Validate the namespace
      --------------------------------------------------------------------------
      IF str_namespace IS NULL
      THEN
         IF p_input.getNamespace() IS NULL
         THEN
            RAISE_APPLICATION_ERROR(-20001,'gml namespace is required');
            
         END IF;
         
         str_namespace := 'xmlns:gml="' || p_input.getNamespace() || '"';
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Pull out the polygon id
      --------------------------------------------------------------------------
      SELECT EXTRACTVALUE(
          p_input
         ,'/gml:Curve/@gml:id'
         ,str_namespace
      ) 
      INTO p_gml_id
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Pull out the srs information if srid is null
      --------------------------------------------------------------------------
      IF num_srid IS NULL
      THEN
         str_srs := sniff_srsName(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'Curve'
         );
         
         dz_gml_util.srs2srid(
             p_input        => str_srs
            ,p_srid         => num_srid
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF p_axes_latlong IS NOT NULL
         THEN
             str_axes_latlong := UPPER(p_axes_latlong);
             
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Sniff for the dimensions of the deal
      --------------------------------------------------------------------------
      IF num_dims IS NULL
      THEN
         num_dims := sniff_srsDimension(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'Curve'
         );
         
         IF num_dims IS NULL
         THEN
            num_dims := 2;
            
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 60
      -- Slurp out the component segments
      --------------------------------------------------------------------------
      int_index := 1;
      FOR i IN (
         SELECT
         VALUE(t) poslist
         FROM
         TABLE(
            XMLSEQUENCE(
               EXTRACT(
                   p_input
                  ,'/gml:Curve/gml:segments/gml:LineStringSegment'
                  ,str_namespace
               )
            )
         ) t
      )
      LOOP
         SELECT EXTRACT(
             i.poslist
            ,'/gml:LineStringSegment/gml:posList/text()'
            ,str_namespace
         ).getClobVal() 
         INTO clb_linestring
         FROM
         dual; 
         
         IF sdo_temp IS NULL
         THEN
            sdo_temp := build_linestring(
               gml_coords2sdo_ords(
                   p_input        => clb_linestring
                  ,p_num_dims     => num_dims
                  ,p_axes_latlong => str_axes_latlong
               ),
               num_srid,
               num_dims               
            );
         ELSE
            ---  THIS SEEMS RATHER UGLY BUT GOOD ENOUGH FOR NOW
            sdo_temp := MDSYS.SDO_GEOM.SDO_UNION(
                sdo_temp
               ,build_linestring(
                    gml_coords2sdo_ords(
                        p_input        => clb_linestring
                       ,p_num_dims     => num_dims
                       ,p_axes_latlong => str_axes_latlong
                    )
                   ,num_srid
                   ,num_dims               
                )
               ,0.05
            );
         END IF;
                    
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 70
      -- This is what we got
      --------------------------------------------------------------------------
      p_output := sdo_temp; 
   
   END gmlcurve2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlcurve2sdo(
       p_input           IN  SYS.XMLTYPE
      ,p_srid            IN  NUMBER   DEFAULT NULL
      ,p_num_dims        IN  NUMBER   DEFAULT NULL
      ,p_namespace       IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong    IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output MDSYS.SDO_GEOMETRY;
      str_id     VARCHAR2(4000 Char);
      
   BEGIN
      gmlcurve2sdo(
          p_input        => p_input
         ,p_srid         => p_srid
         ,p_num_dims     => p_num_dims
         ,p_namespace    => p_namespace
         ,p_axes_latlong => p_axes_latlong
         ,p_output       => sdo_output
         ,p_gml_id       => str_id
      );
      
      RETURN sdo_output;
      
   END gmlcurve2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmllinestring2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
      ,p_output           OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id           OUT VARCHAR2
   )
   AS
      sdo_temp            MDSYS.SDO_GEOMETRY;
      str_srs             VARCHAR2(4000 Char);
      num_srid            NUMBER := p_srid;
      num_dims            NUMBER := p_num_dims;
      str_namespace       VARCHAR2(4000 Char) := p_namespace;
      clb_linestring      CLOB;
      str_axes_latlong    VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      
      FUNCTION build_linestring(
          p_input MDSYS.SDO_ORDINATE_ARRAY
         ,p_srid  NUMBER
         ,p_dims  NUMBER
      ) RETURN MDSYS.SDO_GEOMETRY
      AS
         num_dims    NUMBER := p_dims;
         
      BEGIN
      
         IF num_dims IS NULL
         THEN
            num_dims := 2;
            
         END IF;
         
         IF num_dims = 2
         THEN
            RETURN MDSYS.SDO_GEOMETRY(
                2002
               ,p_srid
               ,NULL
               ,MDSYS.SDO_ELEM_INFO_ARRAY(1,2,1)
               ,p_input
            );
            
         ELSIF num_dims = 3
         THEN
            RETURN MDSYS.SDO_GEOMETRY(
                3002
               ,p_srid
               ,NULL
               ,MDSYS.SDO_ELEM_INFO_ARRAY(1,2,1)
               ,p_input
            );
            
         ELSIF num_dims = 4
         THEN
            RETURN MDSYS.SDO_GEOMETRY(
                4002
               ,p_srid
               ,NULL
               ,MDSYS.SDO_ELEM_INFO_ARRAY(1,2,1)
               ,p_input
            );
            
         ELSE
            RAISE_APPLICATION_ERROR(-20001,'odd dimensions!');
            
         END IF;
      
      END build_linestring;
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         RETURN;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Validate the namespace
      --------------------------------------------------------------------------
      IF str_namespace IS NULL
      THEN
         IF p_input.getNamespace() IS NULL
         THEN
            RAISE_APPLICATION_ERROR(-20001,'gml namespace is required');
            
         END IF;
         
         str_namespace := 'xmlns:gml="' || p_input.getNamespace() || '"';
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Pull out the polygon id
      --------------------------------------------------------------------------
      SELECT EXTRACTVALUE(
          p_input
         ,'/gml:LineString/@gml:id'
         ,str_namespace
      ) 
      INTO p_gml_id
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Pull out the srs information if srid is null
      --------------------------------------------------------------------------
      IF num_srid IS NULL
      THEN
         str_srs := sniff_srsName(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'LineString'
         );
         
         dz_gml_util.srs2srid(
             p_input        => str_srs
            ,p_srid         => num_srid
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF p_axes_latlong IS NOT NULL
         THEN
             str_axes_latlong := UPPER(p_axes_latlong);
             
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Sniff for the dimensions of the deal
      --------------------------------------------------------------------------
      IF num_dims IS NULL
      THEN
         num_dims := sniff_srsDimension(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'LineString'
         );
         
         IF num_dims IS NULL
         THEN
            num_dims := 2;
            
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 60
      -- Slurp out the poslist
      --------------------------------------------------------------------------
      SELECT EXTRACT(
          p_input
         ,'/gml:LineString/gml:posList/text()'
         ,str_namespace
      ).getClobVal() 
      INTO clb_linestring
      FROM
      dual; 
         
      sdo_temp := build_linestring(
          gml_coords2sdo_ords(
              p_input        => clb_linestring
             ,p_num_dims     => num_dims
             ,p_axes_latlong => str_axes_latlong
          )
         ,num_srid
         ,num_dims               
      );
      
      --------------------------------------------------------------------------
      -- Step 70
      -- This is what we got
      --------------------------------------------------------------------------
      p_output := sdo_temp; 
   
   END gmllinestring2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmllinestring2sdo(
       p_input           IN  SYS.XMLTYPE
      ,p_srid            IN  NUMBER   DEFAULT NULL
      ,p_num_dims        IN  NUMBER   DEFAULT NULL
      ,p_namespace       IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong    IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output MDSYS.SDO_GEOMETRY;
      str_id     VARCHAR2(4000 Char);
      
   BEGIN
      gmllinestring2sdo(
          p_input        => p_input
         ,p_srid         => p_srid
         ,p_num_dims     => p_num_dims
         ,p_namespace    => p_namespace
         ,p_axes_latlong => p_axes_latlong
         ,p_output       => sdo_output
         ,p_gml_id       => str_id
      );
      
      RETURN sdo_output;
      
   END gmllinestring2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlmulticurve2sdo(
       p_input           IN  SYS.XMLTYPE
      ,p_srid            IN  NUMBER   DEFAULT NULL
      ,p_num_dims        IN  NUMBER   DEFAULT NULL
      ,p_namespace       IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong    IN  VARCHAR2 DEFAULT NULL
      ,p_output          OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id          OUT VARCHAR2
   )
   AS
      sdo_temp            MDSYS.SDO_GEOMETRY;
      int_index           PLS_INTEGER;
      str_srs             VARCHAR2(4000 Char);
      num_srid            NUMBER := p_srid;
      num_dims            NUMBER := p_num_dims;
      str_id              VARCHAR2(4000 Char);
      str_namespace       VARCHAR2(4000 Char) := p_namespace;
      str_axes_latlong    VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Validate the namespace
      --------------------------------------------------------------------------
      IF str_namespace IS NULL
      THEN
         IF p_input.getNamespace() IS NULL
         THEN
            RAISE_APPLICATION_ERROR(-20001,'gml namespace is required');
            
         END IF;
         
         str_namespace := 'xmlns:gml="' || p_input.getNamespace() || '"';
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Pull out the multicurve id
      --------------------------------------------------------------------------
      SELECT EXTRACTVALUE(
          p_input
         ,'/gml:MultiCurve/@gml:id'
         ,str_namespace
      ) 
      INTO p_gml_id
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Pull out the srs information if srid is null
      --------------------------------------------------------------------------
      IF num_srid IS NULL
      THEN
         str_srs := sniff_srsName(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'MultiCurve'
         );
         
         dz_gml_util.srs2srid(
             p_input        => str_srs
            ,p_srid         => num_srid
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF p_axes_latlong IS NOT NULL
         THEN
             str_axes_latlong := UPPER(p_axes_latlong);
             
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Sniff for dimension information up top
      --------------------------------------------------------------------------
      IF num_dims IS NULL
      THEN
         num_dims := sniff_srsDimension(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'MultiCurve'
         );
      
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 60
      -- Slurp out the component curves
      --------------------------------------------------------------------------
      int_index := 1;
      FOR i IN (
         SELECT
         VALUE(t) poslist
         FROM
         TABLE(
            XMLSEQUENCE(
               EXTRACT(
                   p_input
                  ,'/gml:MultiCurve/gml:curveMember/gml:Curve'
                  ,str_namespace
               )
            )
         ) t
      )
      LOOP
         gmlcurve2sdo(
              p_input        => i.poslist
             ,p_srid         => num_srid
             ,p_num_dims     => num_dims
             ,p_namespace    => str_namespace
             ,p_axes_latlong => str_axes_latlong
             ,p_output       => sdo_temp
             ,p_gml_id       => str_id
         );
         
         IF p_output IS NULL
         THEN
            p_output := sdo_temp;
            
         ELSE
            p_output := MDSYS.SDO_UTIL.APPEND(
                p_output
               ,sdo_temp
            );
            
         END IF;
                    
      END LOOP;
      
   END gmlmulticurve2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlmulticurve2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output MDSYS.SDO_GEOMETRY;
      str_id     VARCHAR2(4000 Char);
      
   BEGIN
      gmlmulticurve2sdo(
          p_input        => p_input
         ,p_srid         => p_srid
         ,p_num_dims     => p_num_dims
         ,p_namespace    => p_namespace
         ,p_axes_latlong => p_axes_latlong
         ,p_output       => sdo_output
         ,p_gml_id       => str_id
      );
      
      RETURN sdo_output; 
      
   END gmlmulticurve2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE gmlmultipoint2sdo(
       p_input           IN  SYS.XMLTYPE
      ,p_srid            IN  NUMBER   DEFAULT NULL
      ,p_num_dims        IN  NUMBER   DEFAULT NULL
      ,p_namespace       IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong    IN  VARCHAR2 DEFAULT NULL
      ,p_output          OUT MDSYS.SDO_GEOMETRY
      ,p_gml_id          OUT VARCHAR2
   )
   AS
      sdo_temp            MDSYS.SDO_GEOMETRY;
      int_index           PLS_INTEGER;
      str_srs             VARCHAR2(4000 Char);
      num_srid            NUMBER := p_srid;
      num_dims            NUMBER := p_num_dims;
      str_id              VARCHAR2(4000 Char);
      str_namespace       VARCHAR2(4000 Char) := p_namespace;
      str_axes_latlong    VARCHAR2(4000 Char) := UPPER(p_axes_latlong);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_input IS NULL
      THEN
         p_output := NULL;
         p_gml_id := NULL;
         
         RETURN;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Validate the namespace
      --------------------------------------------------------------------------
      IF str_namespace IS NULL
      THEN
         IF p_input.getNamespace() IS NULL
         THEN
            RAISE_APPLICATION_ERROR(-20001,'gml namespace is required');
            
         END IF;
         
         str_namespace := 'xmlns:gml="' || p_input.getNamespace() || '"';
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Pull out the multicurve id
      --------------------------------------------------------------------------
      SELECT EXTRACTVALUE(
          p_input
         ,'/gml:MultiPoint/@gml:id'
         ,str_namespace
      ) 
      INTO p_gml_id
      FROM dual;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Pull out the srs information if srid is null
      --------------------------------------------------------------------------
      IF num_srid IS NULL
      THEN
         str_srs := sniff_srsName(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'MultiPoint'
         );
         
         dz_gml_util.srs2srid(
             p_input        => str_srs
            ,p_srid         => num_srid
            ,p_axes_latlong => str_axes_latlong
         );
         
         IF p_axes_latlong IS NOT NULL
         THEN
             str_axes_latlong := UPPER(p_axes_latlong);
             
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Sniff for dimension information up top
      --------------------------------------------------------------------------
      IF num_dims IS NULL
      THEN
         num_dims := sniff_srsDimension(
             p_input         => p_input
            ,p_namespace     => str_namespace
            ,p_geometry_type => 'MultiPoint'
         );
      
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 60
      -- Slurp out the component curves
      --------------------------------------------------------------------------
      int_index := 1;
      FOR i IN (
         SELECT
         VALUE(t) poslist
         FROM
         TABLE(
            XMLSEQUENCE(
               EXTRACT(
                   p_input
                  ,'/gml:MultiPoint/gml:pointMember/gml:Point'
                  ,str_namespace
               )
            )
         ) t
      )
      LOOP
         gmlpoint2sdo(
             p_input        => i.poslist
            ,p_srid         => num_srid
            ,p_num_dims     => num_dims
            ,p_namespace    => str_namespace
            ,p_axes_latlong => str_axes_latlong
            ,p_output       => sdo_temp
            ,p_gml_id       => str_id
         );
         
         IF p_output IS NULL
         THEN
            p_output := sdo_temp;
            
         ELSE
            p_output := MDSYS.SDO_UTIL.APPEND(
                p_output
               ,sdo_temp
            );
            
         END IF;
                    
      END LOOP;
      
   END gmlmultipoint2sdo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gmlmultipoint2sdo(
       p_input            IN  SYS.XMLTYPE
      ,p_srid             IN  NUMBER   DEFAULT NULL
      ,p_num_dims         IN  NUMBER   DEFAULT NULL
      ,p_namespace        IN  VARCHAR2 DEFAULT NULL
      ,p_axes_latlong     IN  VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.SDO_GEOMETRY
   AS
      sdo_output MDSYS.SDO_GEOMETRY;
      str_id     VARCHAR2(4000 Char);
      
   BEGIN
      gmlmultipoint2sdo(
          p_input        => p_input
         ,p_srid         => p_srid
         ,p_num_dims     => p_num_dims
         ,p_namespace    => p_namespace
         ,p_axes_latlong => p_axes_latlong
         ,p_output       => sdo_output
         ,p_gml_id       => str_id
      );
      
      RETURN sdo_output; 
      
   END gmlmultipoint2sdo;
   
END dz_gml_main;
/


--*************************--
PROMPT DZ_GML_TEST.pks;

CREATE OR REPLACE PACKAGE dz_gml_test
AUTHID CURRENT_USER
AS

   C_TFS_CHANGESET CONSTANT NUMBER := 8262;
   C_JENKINS_JOBNM CONSTANT VARCHAR2(255 Char) := 'NULL';
   C_JENKINS_BUILD CONSTANT NUMBER := 6;
   C_JENKINS_BLDID CONSTANT VARCHAR2(255 Char) := 'NULL';
   
   C_PREREQUISITES CONSTANT MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY(
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION prerequisites
   RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION version
   RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION inmemory_test
   RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION scratch_test
   RETURN NUMBER;
      
END dz_gml_test;
/

GRANT EXECUTE ON dz_gml_test TO public;


--*************************--
PROMPT DZ_GML_TEST.pkb;

CREATE OR REPLACE PACKAGE BODY dz_gml_test
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION prerequisites
   RETURN NUMBER
   AS
      num_check NUMBER;
      
   BEGIN
      
      FOR i IN 1 .. C_PREREQUISITES.COUNT
      LOOP
         SELECT 
         COUNT(*)
         INTO num_check
         FROM 
         user_objects a
         WHERE 
             a.object_name = C_PREREQUISITES(i) || '_TEST'
         AND a.object_type = 'PACKAGE';
         
         IF num_check <> 1
         THEN
            RETURN 1;
         
         END IF;
      
      END LOOP;
      
      RETURN 0;
   
   END prerequisites;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION version
   RETURN VARCHAR2
   AS
   BEGIN
      RETURN '{"TFS":' || C_TFS_CHANGESET || ','
      || '"JOBN":"' || C_JENKINS_JOBNM || '",'   
      || '"BUILD":' || C_JENKINS_BUILD || ','
      || '"BUILDID":"' || C_JENKINS_BLDID || '"}';
      
   END version;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION inmemory_test
   RETURN NUMBER
   AS
   BEGIN
      RETURN 0;
      
   END inmemory_test;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION scratch_test
   RETURN NUMBER
   AS
   BEGIN
      RETURN 0;
      
   END scratch_test;

END dz_gml_test;
/


--*************************--
PROMPT sqlplus_footer.sql;


SHOW ERROR;

DECLARE
   l_num_errors PLS_INTEGER;

BEGIN

   SELECT
   COUNT(*)
   INTO l_num_errors
   FROM
   user_errors a
   WHERE
   a.name LIKE 'DZ_GML%';

   IF l_num_errors <> 0
   THEN
      RAISE_APPLICATION_ERROR(-20001,'COMPILE ERROR');

   END IF;

   l_num_errors := DZ_GML_TEST.inmemory_test();

   IF l_num_errors <> 0
   THEN
      RAISE_APPLICATION_ERROR(-20001,'INMEMORY TEST ERROR');

   END IF;

END;
/

EXIT;

