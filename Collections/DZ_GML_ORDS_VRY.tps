CREATE OR REPLACE TYPE dz_gml_ords_vry FORCE
AS 
VARRAY(1048576) OF MDSYS.SDO_ORDINATE_ARRAY;
/

GRANT EXECUTE ON dz_gml_ords_vry TO PUBLIC;

