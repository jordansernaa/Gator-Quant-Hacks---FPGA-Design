REPO_ROOT := .
SRC := src/uart_rx.v src/uart_tx.v src/packet_rx.v src/moving_average_engine.v src/protocol_controller.v src/top.v

IVERILOG ?= iverilog
VVP ?= vvp

.PHONY: sim sim-mavg sim-packet sim-uart lint clean

sim: sim-mavg sim-packet sim-uart

sim-mavg:
	$(IVERILOG) -g2005-sv -o /tmp/tb_mavg.out $(SRC) testbench/tb_moving_average_engine.v
	$(VVP) /tmp/tb_mavg.out

sim-packet:
	$(IVERILOG) -g2005-sv -o /tmp/tb_packet.out $(SRC) testbench/tb_packet_logic.v
	$(VVP) /tmp/tb_packet.out

sim-uart:
	$(IVERILOG) -g2005-sv -o /tmp/tb_uart.out $(SRC) testbench/tb_uart_loopback.v
	$(VVP) /tmp/tb_uart.out

lint:
	$(IVERILOG) -g2005-sv -t null $(SRC)

clean:
	rm -f /tmp/tb_mavg.out /tmp/tb_packet.out /tmp/tb_uart.out
