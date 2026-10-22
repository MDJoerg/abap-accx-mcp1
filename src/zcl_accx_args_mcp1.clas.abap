"! <p class="shorttext synchronized">Access Explorer: tool arguments from mcp (v1) request</p>
"! Thin wrapper over the arguments object of the request - no copying.
CLASS zcl_accx_args_mcp1 DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_accx_args.

    "! arguments is unbound when the client sent none
    METHODS constructor
      IMPORTING !arguments TYPE REF TO zif_mcp_ajson OPTIONAL.

  PRIVATE SECTION.
    DATA arguments TYPE REF TO zif_mcp_ajson.

    METHODS path_of
      IMPORTING !name         TYPE string
      RETURNING VALUE(result) TYPE string.

ENDCLASS.

CLASS zcl_accx_args_mcp1 IMPLEMENTATION.

  METHOD constructor.
    me->arguments = arguments.
  ENDMETHOD.

  METHOD path_of.
    result = |/{ name }|.
  ENDMETHOD.

  METHOD zif_accx_args~has.
    result = xsdbool( arguments IS BOUND AND arguments->exists( path_of( name ) ) = abap_true ).
  ENDMETHOD.

  METHOD zif_accx_args~get_string.
    IF zif_accx_args~has( name ) = abap_false.
      result = default.
      RETURN.
    ENDIF.
    result = arguments->get_string( path_of( name ) ).
  ENDMETHOD.

  METHOD zif_accx_args~get_integer.
    IF zif_accx_args~has( name ) = abap_false.
      result = default.
      RETURN.
    ENDIF.
    TRY.
        " tolerate a number sent as a string
        IF arguments->get_node_type( path_of( name ) ) = zif_mcp_ajson_types=>node_type-string.
          result = condense( arguments->get_string( path_of( name ) ) ).
        ELSE.
          result = arguments->get_integer( path_of( name ) ).
        ENDIF.
      CATCH cx_root.
        result = default.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_accx_args~get_boolean.
    IF zif_accx_args~has( name ) = abap_false.
      result = default.
      RETURN.
    ENDIF.
    " tolerate the strings true and false where a boolean is expected
    IF arguments->get_node_type( path_of( name ) ) = zif_mcp_ajson_types=>node_type-string.
      result = xsdbool( to_lower( arguments->get_string( path_of( name ) ) ) = `true` ).
    ELSE.
      result = arguments->get_boolean( path_of( name ) ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_accx_args~get_strings.
    IF zif_accx_args~has( name ) = abap_false.
      RETURN.
    ENDIF.
    DATA(path) = path_of( name ).
    " tolerate a single string where a list is expected
    IF arguments->get_node_type( path ) <> zif_mcp_ajson_types=>node_type-array.
      DATA(single) = arguments->get_string( path ).
      IF single IS NOT INITIAL.
        APPEND single TO result.
      ENDIF.
      RETURN.
    ENDIF.
    LOOP AT arguments->members( path ) INTO DATA(member).
      APPEND arguments->get_string( |{ path }/{ member }| ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_accx_args~get_names.
    IF arguments IS BOUND.
      result = arguments->members( `/` ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.

