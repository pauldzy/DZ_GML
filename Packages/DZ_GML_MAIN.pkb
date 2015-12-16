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

