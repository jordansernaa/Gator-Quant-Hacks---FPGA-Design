`timescale 1ns/1ps

module protocol_controller #(
    parameter integer SAMPLE_WIDTH = 8,
    parameter integer WINDOW_SIZE = 8
) (
    input  wire                    clk_i,
    input  wire                    rst_n_i,
    input  wire [7:0]              pkt_cmd_i,
    input  wire [7:0]              pkt_data_i,
    input  wire                    pkt_valid_i,
    output wire                    pkt_ready_o,
    input  wire                    pkt_error_i,
    input  wire [7:0]              pkt_error_code_i,
    output reg  [7:0]              tx_data_o,
    output reg                     tx_valid_o,
    input  wire                    tx_ready_i,
    output wire [7:0]              current_average_o,
    output wire                    average_valid_o,
    output wire                    overflow_o,
    output wire [7:0]              sample_count_o
);
    localparam [7:0] RESP_SOF      = 8'h5A;
    localparam [7:0] STATUS_OK     = 8'h00;
    localparam [7:0] STATUS_BADCMD = 8'hE0;

    localparam [7:0] CMD_PUSH_SAMPLE = 8'h01;
    localparam [7:0] CMD_READ_AVG    = 8'h02;
    localparam [7:0] CMD_READ_STATUS = 8'h03;

    reg [7:0] resp_bytes [0:3];
    reg [1:0] resp_index_r;
    reg       resp_active_r;

    reg sample_valid_r;
    wire sample_ready_w;
    wire [SAMPLE_WIDTH-1:0] avg_current_w;
    wire avg_available_w;
    wire engine_overflow_w;
    wire [7:0] sample_count_w;

    assign pkt_ready_o = !resp_active_r;
    assign current_average_o = avg_current_w;
    assign average_valid_o = avg_available_w;
    assign overflow_o = engine_overflow_w;
    assign sample_count_o = sample_count_w;

    moving_average_engine #(
        .DATA_WIDTH(SAMPLE_WIDTH),
        .WINDOW_SIZE(WINDOW_SIZE),
        .SUM_WIDTH(SAMPLE_WIDTH + 4)
    ) u_mavg (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .s_data_i(pkt_data_i[SAMPLE_WIDTH-1:0]),
        .s_valid_i(sample_valid_r),
        .s_ready_o(sample_ready_w),
        .m_data_o(),
        .m_valid_o(),
        .m_ready_i(1'b1),
        .avg_current_o(avg_current_w),
        .avg_available_o(avg_available_w),
        .overflow_o(engine_overflow_w),
        .sample_count_o(sample_count_w)
    );

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            tx_data_o <= 8'd0;
            tx_valid_o <= 1'b0;
            resp_active_r <= 1'b0;
            resp_index_r <= 2'd0;
            sample_valid_r <= 1'b0;
            resp_bytes[0] <= 8'd0;
            resp_bytes[1] <= 8'd0;
            resp_bytes[2] <= 8'd0;
            resp_bytes[3] <= 8'd0;
        end else begin
            sample_valid_r <= 1'b0;

            if (resp_active_r) begin
                if (tx_ready_i) begin
                    tx_data_o <= resp_bytes[resp_index_r];
                    tx_valid_o <= 1'b1;
                    if (resp_index_r == 2'd3) begin
                        resp_index_r <= 2'd0;
                        resp_active_r <= 1'b0;
                    end else begin
                        resp_index_r <= resp_index_r + 2'd1;
                    end
                end else begin
                    tx_valid_o <= 1'b0;
                end
            end else begin
                tx_valid_o <= 1'b0;

                if (pkt_error_i) begin
                    resp_bytes[0] <= RESP_SOF;
                    resp_bytes[1] <= pkt_error_code_i;
                    resp_bytes[2] <= 8'h00;
                    resp_bytes[3] <= RESP_SOF ^ pkt_error_code_i ^ 8'h00;
                    resp_active_r <= 1'b1;
                    resp_index_r <= 2'd0;
                end else if (pkt_valid_i && pkt_ready_o) begin
                    case (pkt_cmd_i)
                        CMD_PUSH_SAMPLE: begin
                            if (sample_ready_w) begin
                                sample_valid_r <= 1'b1;
                                resp_bytes[0] <= RESP_SOF;
                                resp_bytes[1] <= STATUS_OK;
                                resp_bytes[2] <= pkt_data_i;
                                resp_bytes[3] <= RESP_SOF ^ STATUS_OK ^ pkt_data_i;
                            end else begin
                                resp_bytes[0] <= RESP_SOF;
                                resp_bytes[1] <= 8'hE3;
                                resp_bytes[2] <= 8'h00;
                                resp_bytes[3] <= RESP_SOF ^ 8'hE3 ^ 8'h00;
                            end
                            resp_active_r <= 1'b1;
                            resp_index_r <= 2'd0;
                        end

                        CMD_READ_AVG: begin
                            resp_bytes[0] <= RESP_SOF;
                            resp_bytes[1] <= STATUS_OK;
                            resp_bytes[2] <= avg_available_w ? avg_current_w : 8'h00;
                            resp_bytes[3] <= RESP_SOF ^ STATUS_OK ^ (avg_available_w ? avg_current_w : 8'h00);
                            resp_active_r <= 1'b1;
                            resp_index_r <= 2'd0;
                        end

                        CMD_READ_STATUS: begin
                            resp_bytes[0] <= RESP_SOF;
                            resp_bytes[1] <= STATUS_OK;
                            resp_bytes[2] <= {5'd0, engine_overflow_w, avg_available_w, (sample_count_w != 8'd0)};
                            resp_bytes[3] <= RESP_SOF ^ STATUS_OK ^ {5'd0, engine_overflow_w, avg_available_w, (sample_count_w != 8'd0)};
                            resp_active_r <= 1'b1;
                            resp_index_r <= 2'd0;
                        end

                        default: begin
                            resp_bytes[0] <= RESP_SOF;
                            resp_bytes[1] <= STATUS_BADCMD;
                            resp_bytes[2] <= pkt_cmd_i;
                            resp_bytes[3] <= RESP_SOF ^ STATUS_BADCMD ^ pkt_cmd_i;
                            resp_active_r <= 1'b1;
                            resp_index_r <= 2'd0;
                        end
                    endcase
                end
            end
        end
    end
endmodule
