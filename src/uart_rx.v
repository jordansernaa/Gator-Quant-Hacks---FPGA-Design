`timescale 1ns/1ps

module uart_rx #(
    parameter integer CLOCK_HZ = 27_000_000,
    parameter integer BAUD_RATE = 115_200
) (
    input  wire       clk_i,
    input  wire       rst_n_i,
    input  wire       rx_i,
    output reg  [7:0] data_o,
    output reg        data_valid_o,
    input  wire       data_ready_i,
    output reg        framing_error_o,
    output wire       rx_busy_o
);
    localparam integer CLKS_PER_BIT = (CLOCK_HZ / BAUD_RATE);
    localparam integer HALF_BIT_CLKS = (CLKS_PER_BIT / 2);

    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_START = 3'd1;
    localparam [2:0] ST_DATA  = 3'd2;
    localparam [2:0] ST_STOP  = 3'd3;

    reg [2:0] state_r;
    reg [15:0] clk_count_r;
    reg [2:0] bit_index_r;
    reg [7:0] shift_r;

    assign rx_busy_o = (state_r != ST_IDLE);

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state_r <= ST_IDLE;
            clk_count_r <= 16'd0;
            bit_index_r <= 3'd0;
            shift_r <= 8'd0;
            data_o <= 8'd0;
            data_valid_o <= 1'b0;
            framing_error_o <= 1'b0;
        end else begin
            framing_error_o <= 1'b0;
            if (data_valid_o && data_ready_i) begin
                data_valid_o <= 1'b0;
            end

            case (state_r)
                ST_IDLE: begin
                    clk_count_r <= 16'd0;
                    bit_index_r <= 3'd0;
                    if (!rx_i) begin
                        state_r <= ST_START;
                    end
                end

                ST_START: begin
                    if (clk_count_r == HALF_BIT_CLKS[15:0]) begin
                        if (!rx_i) begin
                            clk_count_r <= 16'd0;
                            state_r <= ST_DATA;
                        end else begin
                            state_r <= ST_IDLE;
                        end
                    end else begin
                        clk_count_r <= clk_count_r + 16'd1;
                    end
                end

                ST_DATA: begin
                    if (clk_count_r == (CLKS_PER_BIT - 1)[15:0]) begin
                        clk_count_r <= 16'd0;
                        shift_r[bit_index_r] <= rx_i;
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
                    if (clk_count_r == (CLKS_PER_BIT - 1)[15:0]) begin
                        clk_count_r <= 16'd0;
                        state_r <= ST_IDLE;
                        if (rx_i) begin
                            if (!data_valid_o || data_ready_i) begin
                                data_o <= shift_r;
                                data_valid_o <= 1'b1;
                            end
                        end else begin
                            framing_error_o <= 1'b1;
                        end
                    end else begin
                        clk_count_r <= clk_count_r + 16'd1;
                    end
                end

                default: state_r <= ST_IDLE;
            endcase
        end
    end
endmodule
