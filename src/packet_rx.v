`timescale 1ns/1ps

module packet_rx (
    input  wire       clk_i,
    input  wire       rst_n_i,
    input  wire [7:0] byte_i,
    input  wire       byte_valid_i,
    output wire       byte_ready_o,
    output reg  [7:0] pkt_cmd_o,
    output reg  [7:0] pkt_data_o,
    output reg        pkt_valid_o,
    input  wire       pkt_ready_i,
    output reg        pkt_error_o,
    output reg  [7:0] pkt_error_code_o
);
    localparam [7:0] PKT_SOF = 8'hA5;
    localparam [7:0] ERR_SOF = 8'hE1;
    localparam [7:0] ERR_CRC = 8'hE2;

    reg [1:0] index_r;
    reg [7:0] cmd_r;
    reg [7:0] data_r;
    reg [7:0] csum_r;

    assign byte_ready_o = !pkt_valid_o;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            index_r <= 2'd0;
            cmd_r <= 8'd0;
            data_r <= 8'd0;
            csum_r <= 8'd0;
            pkt_cmd_o <= 8'd0;
            pkt_data_o <= 8'd0;
            pkt_valid_o <= 1'b0;
            pkt_error_o <= 1'b0;
            pkt_error_code_o <= 8'd0;
        end else begin
            pkt_error_o <= 1'b0;
            if (pkt_valid_o && pkt_ready_i) begin
                pkt_valid_o <= 1'b0;
            end

            if (byte_valid_i && byte_ready_o) begin
                case (index_r)
                    2'd0: begin
                        if (byte_i == PKT_SOF) begin
                            csum_r <= byte_i;
                            index_r <= 2'd1;
                        end else begin
                            pkt_error_o <= 1'b1;
                            pkt_error_code_o <= ERR_SOF;
                        end
                    end
                    2'd1: begin
                        cmd_r <= byte_i;
                        csum_r <= csum_r ^ byte_i;
                        index_r <= 2'd2;
                    end
                    2'd2: begin
                        data_r <= byte_i;
                        csum_r <= csum_r ^ byte_i;
                        index_r <= 2'd3;
                    end
                    2'd3: begin
                        if (csum_r == byte_i) begin
                            pkt_cmd_o <= cmd_r;
                            pkt_data_o <= data_r;
                            pkt_valid_o <= 1'b1;
                        end else begin
                            pkt_error_o <= 1'b1;
                            pkt_error_code_o <= ERR_CRC;
                        end
                        index_r <= 2'd0;
                        csum_r <= 8'd0;
                    end
                    default: begin
                        index_r <= 2'd0;
                        csum_r <= 8'd0;
                    end
                endcase
            end
        end
    end
endmodule
