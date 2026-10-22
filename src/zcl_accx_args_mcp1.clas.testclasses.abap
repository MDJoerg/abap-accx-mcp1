CLASS ltc_args_mcp1 DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS args
      IMPORTING !json         TYPE string
      RETURNING VALUE(result) TYPE REF TO zif_accx_args
      RAISING   zcx_mcp_ajson_error.

    METHODS reads_scalars       FOR TESTING RAISING zcx_mcp_ajson_error.
    METHODS defaults_when_absent FOR TESTING RAISING zcx_mcp_ajson_error.
    METHODS tolerates_strings   FOR TESTING RAISING zcx_mcp_ajson_error.
    METHODS reads_lists         FOR TESTING RAISING zcx_mcp_ajson_error.
    METHODS names_of_arguments  FOR TESTING RAISING zcx_mcp_ajson_error.
    METHODS no_arguments        FOR TESTING.
ENDCLASS.

CLASS ltc_args_mcp1 IMPLEMENTATION.

  METHOD args.
    result = NEW zcl_accx_args_mcp1( zcl_mcp_ajson=>parse( json ) ).
  ENDMETHOD.

  METHOD reads_scalars.
    DATA(cut) = args( `{"user":"JDOE","max_rows":25,"valid_users_only":true}` ).
    cl_abap_unit_assert=>assert_true( cut->has( `user` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `JDOE` act = cut->get_string( `user` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 25 act = cut->get_integer( `max_rows` ) ).
    cl_abap_unit_assert=>assert_true( cut->get_boolean( `valid_users_only` ) ).
  ENDMETHOD.

  METHOD defaults_when_absent.
    DATA(cut) = args( `{"user":"JDOE"}` ).
    cl_abap_unit_assert=>assert_false( cut->has( `role` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `fallback` act = cut->get_string( name = `role` default = `fallback` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 7 act = cut->get_integer( name = `max_rows` default = 7 ) ).
    cl_abap_unit_assert=>assert_true( cut->get_boolean( name = `valid_users_only` default = abap_true ) ).
    cl_abap_unit_assert=>assert_initial( cut->get_string( `role` ) ).
  ENDMETHOD.

  METHOD tolerates_strings.
    DATA(cut) = args( `{"confirm":"true","other":"false","count":"12"}` ).
    cl_abap_unit_assert=>assert_true( cut->get_boolean( `confirm` ) ).
    cl_abap_unit_assert=>assert_false( cut->get_boolean( `other` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 12 act = cut->get_integer( `count` ) ).
  ENDMETHOD.

  METHOD reads_lists.
    DATA(cut) = args( `{"checks":["inactive","expired"],"one":"direct_profile","none":[]}` ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `inactive` ) ( `expired` ) ) act = cut->get_strings( `checks` ) ).
    " a single string where a list is expected
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `direct_profile` ) ) act = cut->get_strings( `one` ) ).
    cl_abap_unit_assert=>assert_initial( cut->get_strings( `none` ) ).
    cl_abap_unit_assert=>assert_initial( cut->get_strings( `missing` ) ).
  ENDMETHOD.

  METHOD names_of_arguments.
    DATA(names) = args( `{"user":"JDOE","max_rows":5}` )->get_names( ).
    SORT names.
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `max_rows` ) ( `user` ) ) act = names ).
  ENDMETHOD.

  METHOD no_arguments.
    DATA(cut) = CAST zif_accx_args( NEW zcl_accx_args_mcp1( ) ).
    cl_abap_unit_assert=>assert_false( cut->has( `user` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `x` act = cut->get_string( name = `user` default = `x` ) ).
    cl_abap_unit_assert=>assert_initial( cut->get_names( ) ).
    cl_abap_unit_assert=>assert_initial( cut->get_strings( `user` ) ).
  ENDMETHOD.

ENDCLASS.
