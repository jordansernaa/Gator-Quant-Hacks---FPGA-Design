`timescale 1ns/1ps

module uart_tx #(
    parameter integer CLOCK_HZ = 27_000_000,
    parameter integer BAUD_RATE = 115_200
) (
    input  wire       clk_i,
    input  wire       rst_n_i,
    input  wire [7:0] data_i,
    input  wire       data_valid_i,
    output wire       data_ready_o,
    output reg        tx_o,
    output wire       busy_o
);
    localparam integer CLKS_PER_BIT = (CLOCK_HZ / BAUD_RATE);

    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_START = 2'd1;
    localparam [1:0] ST_DATA  = 2'd2;
    localparam [1:0] ST_STOP  = 2'd3;

    reg [1:0] state_r;
    reg [15:0] clk_count_r;
    reg [2:0] bit_index_r;
    reg [7:0] shift_r;

    assign busy_o = (state_r != ST_IDLE);
    assign data_ready_o = (state_r == ST_IDLE);

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state_r <= ST_IDLE;
            clk_count_r <= 16'd0;
            bit_index_r <= 3'd0;
            shift_r <= 8'd0;
            tx_o <= 1'b1;
        end else begin
            case (state_r)
                ST_IDLE: begin
                    tx_o <= 1'b1;
                    clk_count_r <= 16'd0;
                    bit_index_r <= 3'd0;
                    if (data_valid_i) begin
                        shift_r <= data_i;
                        state_r <= ST_START;
                    end
                end

                ST_START: begin
                    tx_o <= 1'b0;
                    if (clk_count_r == (CLKS_PER_BIT - 1)[15:0]) begin
                        clk_count_r <= 16'd0;
                        state_r <= ST_DATA;
                    end else begin
                        clk_count_r <= clk_count_r + 16'd1;
                    end
                end

                ST_DATA: begin
                    tx_o <= shift_r[bit_index_r];
                    if (clk_count_r == (CLKS_PER_BIT - 1)[15:0]) begin
                        clk_count_r <= 16'd0;
                        if (bit_index_r == 3'd7) begin
                            bit_index_r <= 3'd0;
                            state_r <= ST_STOP;
                        end else begin
                            bit_index_r <= bit_index_r + 3'd1;
                        end
                    end else begin
                        clk_count_r <= clk_count_r + 16'd1;
                    end
                end

                ST_STOP: begin
                    tx_o <= 1'b1;
                    if (clk_count_r == (CLKS_PER_BIT - 1)[15:0]) begin
                        clk_count_r <= 16'd0;
                        state_r <= ST_IDLE;
                    end else begin
                        clk_count_r <= clk_count_r + 16'd1;
                    end
                end

                default: state_r <= ST_IDLE;
            endcase
        end
    end
endmodule
