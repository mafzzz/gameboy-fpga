set_global_assignment -entity "clock" -library "lib_clock" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "clock" -library "lib_clock" -name IP_TOOL_VERSION "13.1"
set_global_assignment -entity "clock" -library "lib_clock" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_clock" -name SPD_FILE [file join $::quartus(sip_path) "clock.spd"]
