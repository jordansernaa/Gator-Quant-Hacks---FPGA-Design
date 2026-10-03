# Gator-Quant-Hacks---FPGA-Design

Tang Nano 20K UART packet-processing reference design with a moving-average engine.

## Repository layout

- `src/`: synthesizable RTL (`top.v`, UART blocks, packet parsing, protocol control, moving average engine)
- `constraints/19_tang_nano_20k.cst`: Tang Nano 20K constraint template with clearly marked pin placeholders
- `testbench/`: self-checking simulation testbenches
- `gowin/`: Gowin project setup artifact
- `bitstream/final.fs`: placeholder (real bitstream must be generated locally)
- `results/`: representative/sample CSV outputs and provenance notes

## Packet protocol

### Host to FPGA packet (4 bytes)
1. `SOF` = `0xA5`
2. `CMD`
3. `DATA`
4. `CHK` = `SOF ^ CMD ^ DATA`

### FPGA to host response (4 bytes)
1. `SOF` = `0x5A`
2. `STATUS`
3. `DATA`
4. `CHK` = `SOF ^ STATUS ^ DATA`

### Commands
- `0x01` (`CMD_PUSH_SAMPLE`): push one 8-bit sample into moving-average window
- `0x02` (`CMD_READ_AVG`): read current average (`DATA=0` if no samples yet)
- `0x03` (`CMD_READ_STATUS`): status bits in `DATA`:
  - bit0: sample buffer non-empty
  - bit1: average available
  - bit2: overflow flag

### Error status codes
- `0xE0`: unknown command
- `0xE1`: start-of-frame mismatch
- `0xE2`: checksum mismatch
- `0xE4`: UART framing error

## Simulation

Requires `iverilog` + `vvp`.

```bash
make sim
```

Or run targeted checks:

```bash
make sim-mavg
make sim-packet
make sim-uart
```

## Synthesis preparation

1. Open Gowin EDA locally.
2. Use `gowin/project_setup.tcl` as a reference to configure the project.
3. Replace placeholder pin names in `constraints/19_tang_nano_20k.cst` with verified board pins.
4. Run synthesis/place/route and generate a real `final.fs`.
