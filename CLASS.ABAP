class ZCL_VALIDATION_INT definition
  public
  final
  create public .

public section.

  types:
    BEGIN OF ty_error_message ,
        err TYPE char220,
      END OF ty_error_message .
  types:
    BEGIN OF ty_validate_table ,
        field_name     TYPE fieldname,
        tab_name       TYPE tabname,
        tab_field_name TYPE fieldname,
        d_elem_name    TYPE rollname,
        msg_field_name TYPE char30,
        conv_exit_name TYPE rs38l_fnam,
        conv_exit_code TYPE char3,
      END OF ty_validate_table .
  types:
    BEGIN OF ty_converted_out,
             conv_exit_code TYPE char3,
             unconv_value   TYPE string,
             conv_value     TYPE string,
           END OF ty_converted_out .
  types:
    tt_error_message TYPE TABLE OF ty_error_message .
  types:
    tt_validate_table TYPE TABLE OF ty_validate_table .
  types:
    tt_converted_out TYPE HASHED TABLE OF ty_converted_out WITH UNIQUE KEY conv_exit_code unconv_value .

  data ERR_MESSAGE type TT_ERROR_MESSAGE read-only .
  data:
    CONVERTED_OUT type HASHED TABLE OF Ty_CONVERTED_OUT WITH UNIQUE KEY conv_exit_code unconv_value read-only .

  methods VALIDATE_FIELDS
    importing
      !INPUT type ANY .
  methods CONSTRUCTOR
    importing
      !VALIDATE_TABLE type TT_VALIDATE_TABLE .
protected section.
private section.

  data VALIDATION_TABLE type TT_VALIDATE_TABLE .

  methods GET_COMP_FROM_TABLE
    importing
      !INPUT type ANY
    exporting
      !COMPONENTS type ABAP_COMPONENT_TAB
      !INP_TAB_CAT type ABAP_TYPECATEGORY .
  methods DO_VALIDATION
    importing
      !INPUT type ANY .
  methods GET_CONVERTED_VALUES
    importing
      !CONV_CODE type CHAR3
      !CONV_EXIT_NAME type RS38L_FNAM
      !FIELD_NAME type FIELDNAME
    changing
      !INPUT_TABLE type ANY TABLE .
ENDCLASS.



CLASS ZCL_VALIDATION_INT IMPLEMENTATION.


   METHOD validate_fields.
        do_validation( EXPORTING input = input ).
   ENDMETHOD.


  method CONSTRUCTOR.
    validation_table[] = validate_table[].
  endmethod.


  METHOD do_validation.
    " Data Declaration
    DATA:
      lit_comp_inp     TYPE  abap_component_tab,
      lwa_comp_inp     TYPE abap_componentdescr,
      lwa_struc        TYPE abap_componentdescr,
      lit_struc        TYPE abap_component_tab,
      wa_value         TYPE ty_validate_table,
      lo_struc         TYPE REF TO  cl_abap_structdescr,
      lo_struc_allowed TYPE REF TO cl_abap_structdescr,
      lo_ttype_allowed TYPE REF TO cl_abap_tabledescr,
      lo_ttype_input   TYPE REF TO cl_abap_tabledescr,
      lo_allowed       TYPE REF TO data,
      lo_input         TYPE REF TO data,
      lo_table_deep    TYPE REF TO data,
      input_cat        TYPE abap_typecategory,
      lit_components   TYPE abap_component_tab,
      lo_struc_deep    TYPE REF TO cl_abap_structdescr,
      lv_cond TYPE string.


    FIELD-SYMBOLS: <lfs_allowed>        TYPE HASHED TABLE,
                   <lfs_input>          TYPE ANY  TABLE,
                   <lfs_wa_input>       TYPE any,
                   <lfs_wa_input_value> TYPE any,
                   <lfs_deep>           TYPE any,
                   <lfs_deep_1>         TYPE any,
                   <lfs_deep_2>         TYPE any,
                   <lfs_deep_3>         TYPE any,
                   <lfs_deep_table>     TYPE ANY TABLE.
    "--------------------- Get Components -------------------------------
    get_comp_from_table( EXPORTING input = input IMPORTING components = lit_comp_inp inp_tab_cat = input_cat ). " input_cat denotes parent type
    "--------------------Loop at components
    LOOP AT lit_comp_inp INTO lwa_comp_inp.
      IF ( cl_abap_classdescr=>get_class_name( lwa_comp_inp-type ) EQ '\CLASS=CL_ABAP_TABLEDESCR' )." If table as child component "
        " If parent also table then extract the records and prepare new internal table ( 2 loops )
        " One loop for parent and one loop for child
        IF input_cat = 'T'.
*
          " Create table type for new internal table
          CREATE DATA lo_table_deep TYPE HANDLE lwa_comp_inp-type.
          ASSIGN lo_table_deep->* TO <lfs_deep_table>.
*
          " Loop and extract the deep table into one table
          LOOP AT input ASSIGNING <lfs_deep>." Loop at each row parent internal table
            ASSIGN COMPONENT lwa_comp_inp-name OF STRUCTURE <lfs_deep> TO <lfs_deep_1>. " Assign intenral table
            LOOP AT <lfs_deep_1> ASSIGNING <lfs_deep_3>." Loop at each row child internal table
              INSERT <lfs_deep_3> INTO TABLE <lfs_deep_table>."Final Internal table
            ENDLOOP.
          ENDLOOP.
*
          " Call again validate fields
          validate_fields( EXPORTING input = <lfs_deep_table> ).
*
          " reset used values
          UNASSIGN: <lfs_deep_table>,<lfs_deep_3>,<lfs_deep_1>,<lfs_deep>.
          CLEAR: lo_table_deep.
*
          " If parent structure ( straightly get the components )
        ELSEIF input_cat = 'S'.
          " Call recursive validate
          ASSIGN COMPONENT lwa_comp_inp-name OF STRUCTURE input TO <lfs_deep_table>.
          validate_fields( EXPORTING input = <lfs_deep_table> ).
*
          " Reset use values
          UNASSIGN <lfs_deep_table>.
*
        ENDIF.
      ELSEIF ( cl_abap_classdescr=>get_class_name( lwa_comp_inp-type ) EQ '\CLASS=CL_ABAP_STRUCTDESCR' )." If structure as components
        "Check if it is include then extract components and append
        IF lwa_comp_inp-as_include = 'X' AND ( input_cat = 'S'  OR input_cat = 'T').
          lo_struc_deep ?= lwa_comp_inp-type.
          lit_components = lo_struc_deep->get_components( ).
          APPEND LINES OF lit_components TO lit_comp_inp.
          CLEAR: lit_components,lo_struc_deep.
*
        ELSEIF lwa_comp_inp-as_include = '' AND input_cat = 'S'. " If not include and parent was structure
*
          ASSIGN COMPONENT lwa_comp_inp-name OF STRUCTURE input TO <lfs_deep_table>." Get components and append
          validate_fields( EXPORTING input = <lfs_deep_table> ).
          UNASSIGN <lfs_deep_table>.
*
        ELSEIF lwa_comp_inp-as_include = '' AND input_cat = 'T'. " If not include and parent was table
*
          " Create table type
          lo_ttype_input = cl_abap_tabledescr=>create(
                                  p_line_type   = lwa_comp_inp-type
                                  p_table_kind  = cl_abap_tabledescr=>tablekind_std
                                  p_unique      = abap_false
                                   ).
          CREATE DATA lo_table_deep TYPE HANDLE lo_ttype_input.
          ASSIGN lo_table_deep->* TO <lfs_deep_table>.
          LOOP AT input ASSIGNING <lfs_deep>.
            ASSIGN COMPONENT lwa_comp_inp-name OF STRUCTURE <lfs_deep> TO <lfs_deep_1>.
            INSERT <lfs_deep_1> INTO TABLE <lfs_deep_table>.
            UNASSIGN <lfs_deep_1>.
          ENDLOOP.
          validate_fields( EXPORTING input = <lfs_deep_table> ).
          "Reset fields
          CLEAR: lo_table_deep,lo_ttype_input.
          UNASSIGN:<lfs_deep_table>,<lfs_deep_1>,<lfs_deep>.
        ENDIF.
        " else call validate_fields with required comp
      ELSEIF ( cl_abap_classdescr=>get_class_name( lwa_comp_inp-type ) EQ '\CLASS=CL_ABAP_ELEMDESCR' )." If elementarty type
        TRY.
            wa_value = validation_table[ field_name = lwa_comp_inp-name  ] .
          CATCH cx_sy_itab_line_not_found.
            CONTINUE.
        ENDTRY.
*
        "Create Structure Based on the field for input
        lwa_struc-name = wa_value-field_name.
        lwa_struc-type ?= cl_abap_datadescr=>describe_by_name( wa_value-d_elem_name ) .
        APPEND lwa_struc TO lit_struc.
        lo_struc ?= cl_abap_structdescr=>get( lit_struc ).
        " Create table type with sorted
        lo_ttype_input = cl_abap_tabledescr=>create(
                                p_line_type   = lo_struc
                                p_table_kind  = cl_abap_tabledescr=>tablekind_std
                                p_unique      = abap_false
                                p_key         = VALUE #( ( name =  wa_value-field_name ) )
                                p_key_kind    = cl_abap_tabledescr=>keydefkind_user ).
        " Assign table type to data
        CREATE DATA lo_input TYPE HANDLE lo_ttype_input.
        ASSIGN lo_input->* TO <lfs_input>.
        " Prepare Input table by delete adjacne duplicate
        <lfs_input> = CORRESPONDING #( input ).
        lv_cond = |{ wa_value-field_name } = ''|.
        DELETE <lfs_input> WHERE (lv_cond).
        DELETE ADJACENT DUPLICATES FROM <lfs_input> COMPARING (wa_value-field_name).
        IF wa_value-conv_exit_name <> ''.
            get_converted_values( EXPORTING conv_code = wa_value-conv_exit_code conv_exit_name = wa_value-conv_exit_name
                                            field_name = wa_value-field_name CHANGING input_table = <lfs_input> ).
        ENDIF.

        REFRESH lit_struc.

        IF wa_value-tab_field_name <> ''.
          "create Structure based on this
          lwa_struc-name = wa_value-tab_field_name.
          APPEND lwa_struc TO lit_struc.
          lo_struc_allowed ?= cl_abap_structdescr=>get( lit_struc ).

          " Create Table Type based on above structure ( One with hashed to choose allowed values  )
          lo_ttype_allowed  = cl_abap_tabledescr=>create(
                                  p_line_type   = lo_struc_allowed
                                  p_table_kind  = cl_abap_tabledescr=>tablekind_hashed
                                  p_unique      = abap_true
                                  p_key         = VALUE #( ( name = wa_value-tab_field_name ) )
                                  p_key_kind    = cl_abap_tabledescr=>keydefkind_user ).

          " Create Internal table based on above table type
          CREATE DATA lo_allowed TYPE HANDLE lo_ttype_allowed.
          " Assign created reference to field symbol
          ASSIGN lo_allowed->* TO <lfs_allowed>.
          "Select allowed values form standard tables
          SELECT DISTINCT (wa_value-tab_field_name) FROM (wa_value-tab_name) INTO TABLE <lfs_allowed> .

          " Loop at input and check it was allowed values, if not capture error
          LOOP AT <lfs_input> ASSIGNING <lfs_wa_input>.
            ASSIGN COMPONENT wa_value-field_name OF STRUCTURE <lfs_wa_input> TO <lfs_wa_input_value>.
*            DATA: lv_string TYPE string.
*            lv_string = wa_value-tab_field_name.
*            CONDENSE lv_string.
            READ TABLE <lfs_allowed> TRANSPORTING NO FIELDS WITH TABLE KEY (wa_value-tab_field_name) = <lfs_wa_input_value>.
            ".... Capture Error......"
            IF sy-subrc <> 0.
              err_message = VALUE #( BASE err_message ( err = |Invalid { wa_value-msg_field_name }:{ <lfs_wa_input_value> }.| )  ).
            ENDIF.
            UNASSIGN <lfs_wa_input_value>.
          ENDLOOP.
        ENDIF.


        CLEAR: lwa_struc,lit_struc,lo_struc,lo_ttype_allowed,lo_ttype_input,lo_allowed,lo_input,wa_value,lv_cond.
        UNASSIGN: <lfs_allowed>,<lfs_input>,<lfs_wa_input>,<lfs_wa_input_value>.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_comp_from_table.
    DATA: lo_type_inp   TYPE REF TO cl_abap_typedescr,
          lo_table_inp  TYPE REF TO cl_abap_tabledescr,
          lo_data_inp   TYPE REF TO cl_abap_datadescr,
          lo_struct_inp TYPE REF TO cl_abap_structdescr.

    lo_type_inp  = cl_abap_tabledescr=>describe_by_data( input ). " Get Type Description from input table
    inp_tab_cat = lo_type_inp->kind.
    IF lo_type_inp->kind EQ 'T'. " If Table Type
      lo_table_inp ?= lo_type_inp." Downcast Type description into table description
        lo_data_inp = lo_table_inp->get_table_line_type( )." Get structure from table description and upcast into data description
        IF sy-subrc EQ 0.
          lo_struct_inp ?= lo_data_inp." Downcast data description into structure
          components = lo_struct_inp->get_components( ). " Get components ( Actual Field List ) From Structure
        ENDIF.
    ELSEIF lo_type_inp->kind EQ 'S'." If Structure
      lo_struct_inp ?= lo_type_inp." Downcast type description into structure
      components = lo_struct_inp->get_components( ). " Get components ( Actual Field List ) From Structure
    ENDIF.
  ENDMETHOD.


  METHOD get_converted_values.
    DATA: wa_converted_out TYPE ty_converted_out,
          l_conv           TYPE string.
    FIELD-SYMBOLS: <lfs_any_wa_value> TYPE any,
                   <lfs_any_wa>       TYPE any.
    wa_converted_out-conv_exit_code = conv_code.
    LOOP AT input_table ASSIGNING <lfs_any_wa>.
      ASSIGN COMPONENT field_name OF STRUCTURE <lfs_any_wa> TO  <lfs_any_wa_value>.
      IF <lfs_any_wa_value> IS ASSIGNED.
        CALL FUNCTION conv_exit_name
          EXPORTING
            input  = <lfs_any_wa_value>
          IMPORTING
            output = l_conv
          EXCEPTIONS
            OTHERS = 1.
        IF sy-subrc <> 1.
          wa_converted_out-conv_value = <lfs_any_wa_value>.
          wa_converted_out-unconv_value = l_conv .
          <lfs_any_wa_value> = l_conv.
          INSERT wa_converted_out INTO TABLE converted_out.
        ENDIF.
        CLEAR: wa_converted_out-conv_value,wa_converted_out-unconv_value.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
