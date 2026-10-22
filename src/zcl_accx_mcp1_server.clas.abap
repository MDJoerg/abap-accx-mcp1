"! <p class="shorttext synchronized">Access Explorer: MCP server (mcp v1 adapter)</p>
"! The only class that knows the mcp (v1) SDK, ZAGP_MCP_*. It maps neutral tool,
"! prompt and resource descriptors and results to the SDK and contains no
"! business logic. The server profile is the lower case 'area/server' of
"! the ZMCP_SERVERS registration, so the class can be registered several times
"! with different profiles (see ZACCX_PROFILE). The SDK of this version has no
"! elicitation: a write tool returns its plan as text and is called again with
"! plan_id and confirm = true after the user approved exactly this plan.
"! Run with F9 in ADT to register the profiles in ZMCP_SERVERS.
CLASS zcl_accx_mcp1_server DEFINITION PUBLIC CREATE PUBLIC
  INHERITING FROM zcl_mcp_server_base.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    CONSTANTS co_default_area   TYPE string VALUE `bc`.
    CONSTANTS co_default_server TYPE string VALUE `access-support`.

  PROTECTED SECTION.
    METHODS handle_initialize     REDEFINITION.
    METHODS handle_list_prompts   REDEFINITION.
    METHODS handle_get_prompt     REDEFINITION.
    METHODS handle_list_resources REDEFINITION.
    METHODS handle_resources_read REDEFINITION.
    METHODS handle_list_tools     REDEFINITION.
    METHODS handle_call_tool      REDEFINITION.
    METHODS get_session_mode      REDEFINITION.

  PRIVATE SECTION.
    METHODS get_profile
      RETURNING VALUE(result) TYPE string.

    "! Endpoint check of the authorizer (fails closed). Initial = allowed; otherwise
    "! the error to answer with, and the HTTP status is set to 403
    METHODS endpoint_error
      RETURNING VALUE(result) TYPE zcl_mcp_jsonrpc=>error.

    METHODS build_input_schema
      IMPORTING !descriptor   TYPE zif_accx_types=>ty_tool_descriptor
      RETURNING VALUE(result) TYPE REF TO zif_mcp_ajson
      RAISING   zcx_mcp_ajson_error.

    METHODS fill_tool_response
      IMPORTING !tool_result TYPE zif_accx_types=>ty_result
      CHANGING  !response    TYPE zif_mcp_server=>call_tool_response
      RAISING   zcx_mcp_ajson_error.

ENDCLASS.

CLASS zcl_accx_mcp1_server IMPLEMENTATION.

  METHOD get_session_mode.
    result = zcl_mcp_session=>session_mode_stateless.
  ENDMETHOD.

  METHOD get_profile.
    result = COND #( WHEN server-area IS NOT INITIAL AND server-server IS NOT INITIAL
                     THEN to_lower( |{ server-area }/{ server-server }| )
                     ELSE |{ co_default_area }/{ co_default_server }| ).
  ENDMETHOD.

  METHOD endpoint_error.
    DATA(profile) = get_profile( ).
    DATA(allowed) = abap_false.
    TRY.
        allowed = zcl_accx_factory=>authorizer( profile )->check_endpoint( profile ).
      CATCH cx_root.
        allowed = abap_false.
    ENDTRY.
    IF allowed = abap_true.
      RETURN.
    ENDIF.
    server-http_response->set_status( code   = 403
                                      reason = 'Forbidden' ) ##NO_TEXT.
    result-code    = zcl_mcp_jsonrpc=>error_codes-invalid_request.
    result-message = |You are not authorized to use this endpoint.| ##NO_TEXT.
  ENDMETHOD.

  METHOD handle_initialize.
    response-error = endpoint_error( ).
    IF response-error-code IS NOT INITIAL.
      RETURN.
    ENDIF.
    response-result->set_capabilities( VALUE #( prompts   = VALUE #( enabled = abap_true )
                                                resources = VALUE #( enabled = abap_true )
                                                tools     = VALUE #( enabled = abap_true ) ) ).
    response-result->set_implementation( VALUE #( name        = zcl_accx_server_info=>co_name
                                                  version     = zif_accx_types=>co_release
                                                  title       = zcl_accx_server_info=>co_title
                                                  description = zcl_accx_server_info=>description( ) ) ).
    response-result->set_instructions( zcl_accx_server_info=>instructions( ) ).
  ENDMETHOD.

  METHOD handle_list_tools.
    response-error = endpoint_error( ).
    IF response-error-code IS NOT INITIAL.
      RETURN.
    ENDIF.
    DATA tools TYPE zcl_mcp_resp_list_tools=>tools.
    DATA(ctx) = zcl_accx_factory=>context( profile = get_profile( ) ).
    TRY.
        LOOP AT zcl_accx_factory=>runtime( )->get_catalog( ctx ) INTO DATA(descriptor).
          APPEND VALUE #( name         = descriptor-name
                          title        = descriptor-title
                          description  = descriptor-description
                          input_schema = build_input_schema( descriptor )
                          annotations  = VALUE #( title               = descriptor-title
                                                  readonlyhint        = descriptor-read_only
                                                  destructivehint     = descriptor-destructive
                                                  destructivehint_set = abap_true
                                                  idempotenthint      = descriptor-idempotent
                                                  openworldhint       = abap_false
                                                  openworldhint_set   = abap_true ) ) TO tools.
        ENDLOOP.
      CATCH zcx_mcp_ajson_error INTO DATA(error).
        response-error-code    = zcl_mcp_jsonrpc=>error_codes-internal_error.
        response-error-message = error->get_text( ).
        RETURN.
    ENDTRY.
    response-result->set_tools( tools ).
  ENDMETHOD.

  METHOD handle_call_tool.
    response-error = endpoint_error( ).
    IF response-error-code IS NOT INITIAL.
      RETURN.
    ENDIF.
    DATA(args) = NEW zcl_accx_args_mcp1( request->get_arguments( ) ).
    DATA(ctx) = zcl_accx_factory=>context( profile = get_profile( ) args = args ).
    DATA(tool_result) = zcl_accx_factory=>runtime( )->execute( tool_name = request->get_name( )
                                                                args      = args
                                                                ctx       = ctx ).
    TRY.
        fill_tool_response( EXPORTING tool_result = tool_result
                            CHANGING  response    = response ).
      CATCH zcx_mcp_ajson_error INTO DATA(error).
        response-error-code    = zcl_mcp_jsonrpc=>error_codes-internal_error.
        response-error-message = error->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD fill_tool_response.
    FIELD-SYMBOLS <data> TYPE any.

    DATA(text) = zcl_accx_result_text=>compose( tool_result ).
    IF zcl_accx_result_text=>is_failure( tool_result ) = abap_true.
      response-result->set_error( ).
      response-result->add_text_content( text ).
      RETURN.
    ENDIF.
    IF tool_result-data IS NOT BOUND.
      response-result->add_text_content( text ).
      RETURN.
    ENDIF.

    DATA(json) = zcl_mcp_ajson=>create_empty( ).
    ASSIGN tool_result-data->* TO <data>.
    IF cl_abap_typedescr=>describe_by_data( <data> )->kind = cl_abap_typedescr=>kind_table.
      " structuredContent must be a JSON object
      json->set( iv_path = `/rows` iv_val = <data> ).
    ELSE.
      json->set( iv_path = `/` iv_val = <data> ).
    ENDIF.
    response-result->set_structured_content( structured_content = json
                                             add_text_content   = abap_false ).
    response-result->add_text_content( text ).
  ENDMETHOD.

  METHOD handle_list_prompts.
    response-error = endpoint_error( ).
    IF response-error-code IS NOT INITIAL.
      RETURN.
    ENDIF.
    DATA prompts TYPE zcl_mcp_resp_list_prompts=>prompts.
    DATA(ctx) = zcl_accx_factory=>context( profile = get_profile( ) ).
    LOOP AT zcl_accx_factory=>runtime( )->get_prompts( ctx ) INTO DATA(prompt).
      DATA(entry) = VALUE zcl_mcp_resp_list_prompts=>prompt( name        = prompt-name
                                                             title       = prompt-title
                                                             description = prompt-description ).
      LOOP AT prompt-arguments INTO DATA(argument).
        APPEND VALUE #( name        = argument-name
                        description = argument-description
                        required    = argument-required ) TO entry-arguments.
      ENDLOOP.
      APPEND entry TO prompts.
    ENDLOOP.
    response-result->set_prompts( prompts ).
  ENDMETHOD.

  METHOD handle_get_prompt.
    response-error = endpoint_error( ).
    IF response-error-code IS NOT INITIAL.
      RETURN.
    ENDIF.
    DATA(args) = NEW zcl_accx_args_map( ).
    LOOP AT request->get_arguments( ) INTO DATA(argument).
      args->set( name = argument-key value = argument-value ).
    ENDLOOP.
    DATA(ctx) = zcl_accx_factory=>context( profile = get_profile( ) ).
    DATA(prompt) = zcl_accx_factory=>runtime( )->get_prompt( name = request->get_name( ) args = args ctx = ctx ).
    IF prompt-status <> zif_accx_types=>co_status-ok.
      response-error-code    = zcl_mcp_jsonrpc=>error_codes-invalid_params.
      response-error-message = prompt-message.
      RETURN.
    ENDIF.
    response-result->set_description( prompt-description ).
    LOOP AT prompt-messages INTO DATA(message).
      response-result->add_text_message( role = COND #( WHEN message-role = zif_accx_prompt=>co_role-assistant
                                                        THEN zif_mcp_types=>role_assistant
                                                        ELSE zif_mcp_types=>role_user )
                                         text = message-text ).
    ENDLOOP.
  ENDMETHOD.

  METHOD handle_list_resources.
    response-error = endpoint_error( ).
    IF response-error-code IS NOT INITIAL.
      RETURN.
    ENDIF.
    DATA resources TYPE zcl_mcp_resp_list_resources=>resources.
    DATA(ctx) = zcl_accx_factory=>context( profile = get_profile( ) ).
    LOOP AT zcl_accx_factory=>runtime( )->get_resources( ctx ) INTO DATA(resource).
      APPEND VALUE #( uri         = resource-uri
                      name        = resource-name
                      title       = resource-title
                      description = resource-description
                      mime_type   = resource-mime_type ) TO resources.
    ENDLOOP.
    response-result->set_resources( resources ).
  ENDMETHOD.

  METHOD handle_resources_read.
    response-error = endpoint_error( ).
    IF response-error-code IS NOT INITIAL.
      RETURN.
    ENDIF.
    DATA(ctx) = zcl_accx_factory=>context( profile = get_profile( ) ).
    DATA(content) = zcl_accx_factory=>runtime( )->read_resource( uri = request->get_uri( ) ctx = ctx ).
    CASE content-status.
      WHEN zif_accx_types=>co_status-ok.
        response-result->add_text_resource( uri       = content-uri
                                            text      = content-text
                                            mime_type = content-mime_type ).
      WHEN zif_accx_types=>co_status-not_found.
        response-error-code    = zcl_mcp_jsonrpc=>error_codes-resource_not_found.
        response-error-message = content-message.
      WHEN OTHERS.
        response-error-code    = zcl_mcp_jsonrpc=>error_codes-internal_error.
        response-error-message = content-message.
    ENDCASE.
  ENDMETHOD.

  METHOD build_input_schema.
    DATA(builder) = NEW zcl_mcp_schema_builder( ).
    LOOP AT descriptor-params INTO DATA(param) WHERE kind <> zif_accx_types=>co_kind-string_list.
      CASE param-kind.
        WHEN zif_accx_types=>co_kind-integer.
          IF param-minimum <> 0 OR param-maximum <> 0.
            builder->add_integer( name        = param-name
                                  description = param-description
                                  required    = param-required
                                  minimum     = param-minimum
                                  maximum     = param-maximum ).
          ELSE.
            builder->add_integer( name = param-name description = param-description required = param-required ).
          ENDIF.
        WHEN zif_accx_types=>co_kind-number.
          builder->add_number( name = param-name description = param-description required = param-required ).
        WHEN zif_accx_types=>co_kind-boolean.
          builder->add_boolean( name = param-name description = param-description required = param-required ).
        WHEN OTHERS.
          IF param-enum IS NOT INITIAL.
            builder->add_string( name        = param-name
                                 description = param-description
                                 required    = param-required
                                 enum        = CONV #( param-enum ) ).
          ELSEIF param-maximum > 0.
            builder->add_string( name        = param-name
                                 description = param-description
                                 required    = param-required
                                 max_length  = param-maximum ).
          ELSE.
            builder->add_string( name = param-name description = param-description required = param-required ).
          ENDIF.
      ENDCASE.
    ENDLOOP.
    result = builder->to_json( ).

    " the schema builder of this SDK has no array of strings: add them to the JSON
    LOOP AT descriptor-params INTO param WHERE kind = zif_accx_types=>co_kind-string_list.
      result->set_string( iv_path = |/properties/{ param-name }/type| iv_val = `array` ).
      result->set_string( iv_path = |/properties/{ param-name }/items/type| iv_val = `string` ).
      IF param-description IS NOT INITIAL.
        result->set_string( iv_path = |/properties/{ param-name }/description| iv_val = param-description ).
      ENDIF.
      IF param-required = abap_true.
        result->set_string( iv_path = |/required/{ lines( result->members( `/required` ) ) + 1 }| iv_val = param-name ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    " the default profile and every profile maintained in ZACCX_PROFILE (area/server)
    DATA(profiles) = VALUE string_table( ( |{ co_default_area }/{ co_default_server }| ) ).
    SELECT profile FROM zaccx_profile INTO TABLE @DATA(configured).
    LOOP AT configured INTO DATA(entry).
      DATA(name) = to_lower( condense( CONV string( entry-profile ) ) ).
      IF name CA '/' AND NOT line_exists( profiles[ table_line = name ] ).
        APPEND name TO profiles.
      ENDIF.
    ENDLOOP.

    LOOP AT profiles INTO DATA(profile_name).
      SPLIT profile_name AT '/' INTO DATA(area_name) DATA(server_name).
      DATA(row) = VALUE zmcp_servers( area = area_name server = server_name class = 'ZCL_ACCX_MCP1_SERVER' ).
      MODIFY zmcp_servers FROM @row.
      out->write( |Access Explorer { zif_accx_types=>co_release }: registered { profile_name } for the mcp v1 SDK - | &&
                  |endpoint POST /zmcp/{ area_name }/{ server_name }?sap-client={ sy-mandt }| ).
      DATA(ctx) = zcl_accx_factory=>context( profile = profile_name ).
      out->write( |  Tools visible for { sy-uname }:| ).
      LOOP AT zcl_accx_factory=>runtime( )->get_catalog( ctx ) INTO DATA(descriptor).
        out->write( |  - { descriptor-name } ({ descriptor-group }{ COND #( WHEN descriptor-read_only = abap_false THEN `, WRITES` ) })| ).
      ENDLOOP.
      IF ctx->write_problem( ) IS NOT INITIAL.
        out->write( |  No write tools: { ctx->write_problem( ) }| ).
      ENDIF.
    ENDLOOP.
    COMMIT WORK.

    LOOP AT zcl_accx_factory=>registry( )->get_issues( ) INTO DATA(issue).
      out->write( |Plugin issue { issue-plugin_id }: { issue-message }| ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

