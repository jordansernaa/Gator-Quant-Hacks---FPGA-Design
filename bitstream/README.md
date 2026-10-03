# Bitstream Artifact

`final.fs` in this repository is a clearly labeled placeholder, not a real FPGA bitstream.

To generate a real bitstream:
1. Open/create the Gowin project using files under `src/`, `constraints/`, and `gowin/`.
2. Verify pin assignments for your exact Tang Nano 20K board revision.
3. Run synthesis/place/route and export the final `.fs` file.
