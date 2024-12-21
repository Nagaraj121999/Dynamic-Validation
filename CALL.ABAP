"Declaring Value Table
it_value_table        TYPE zcl_validation_int=>tt_validate_table
" Filling Value Table with necessary values
it_value_table = VALUE #( ( field_name = 'SOLD_TO_PARTY' tab_name = 'KNA1' tab_field_name = 'KUNNR' d_elem_name = 'KUNNR' msg_field_name = 'Sold To Party'
                                conv_exit_name = 'CONVERSION_EXIT_ALPHA_INPUT' conv_exit_code = 'STP')
                              ( field_name = 'SHIP_TO_PARTY' tab_name = 'KNA1' tab_field_name = 'KUNNR' d_elem_name = 'KUNNR' msg_field_name = 'Ship To Party'
                                conv_exit_name = 'CONVERSION_EXIT_ALPHA_INPUT' conv_exit_code = 'SHP') ).
"Calling Method
" Here it_input refers to internal table that needs validation
 CREATE OBJECT lo_validation EXPORTING validate_table = it_value_table.
 lo_validation->validate_fields( EXPORTING input = it_input ).
 IF lo_validation->err_message IS NOT INITIAL.
       " Do your error handling here.
 ENDIF.
 " To Access the unconverted Value
" In CONV_VALUE we need to pass value to get the converted value
 lo_validation->converted_out[ conv_exit_code = 'STP' conv_value = headers-sold_to_party ]-unconv_value )
