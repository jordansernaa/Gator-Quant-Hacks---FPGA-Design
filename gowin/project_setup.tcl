# Gowin EDA setup script (reference) for Tang Nano 20K.
# Run inside Gowin EDA TCL console and verify family/device/package against your board revision.

set_device GW2AR-LV18QN88C8/I7
add_file ../src/top.v
add_file ../src/uart_rx.v
add_file ../src/uart_tx.v
add_file ../src/packet_rx.v
add_file ../src/moving_average_engine.v
add_file ../src/protocol_controller.v
set_option -include_path ../src
set_option -top_module top
set_option -cst_file ../constraints/19_tang_nano_20k.cst
run all
