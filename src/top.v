`timescale 1ns/1ps

module top #(
    parameter integer CLOCK_HZ = 27_000_000,
    parameter integer BAUD_RATE = 115_200,
    parameter integer WINDOW_SIZE = 8
) (
    input  wire       clk_27m_i,
    input  wire       rst_n_i,
    input  wire       uart_rx_i,
    output wire       uart_tx_o,
    output wire [3:0] led_status_o
);
    wire [7:0] rx_data_w;
    wire       rx_valid_w;
    wire       rx_ready_w;
    wire       rx_frame_err_w;

    wire [7:0] pkt_cmd_w;
    wire [7:0] pkt_data_w;
    wire       pkt_valid_w;
    wire       pkt_ready_w;
    wire       pkt_error_w;
    wire [7:0] pkt_error_code_w;

    wire [7:0] tx_data_w;
    wire       tx_valid_w;
    wire       tx_ready_w;

    wire [7:0] avg_w;
    wire       avg_valid_w;
    wire       overflow_w;
    wire [7:0] sample_count_w;

    uart_rx #(
        .CLOCK_HZ(CLOCK_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_rx (
        .clk_i(clk_27m_i),
        .rst_n_i(rst_n_i),
        .rx_i(uart_rx_i),
        .data_o(rx_data_w),
        .data_valid_o(rx_valid_w),
        .data_ready_i(rx_ready_w),
        .framing_error_o(rx_frame_err_w),
        .rx_busy_o()
    );

    packet_rx u_packet_rx (
        .clk_i(clk_27m_i),
        .rst_n_i(rst_n_i),
        .byte_i(rx_data_w),
        .byte_valid_i(rx_valid_w),
        .byte_ready_o(rx_ready_w),
        .pkt_cmd_o(pkt_cmd_w),
        .pkt_data_o(pkt_data_w),
        .pkt_valid_o(pkt_valid_w),
        .pkt_ready_i(pkt_ready_w),
        .pkt_error_o(pkt_error_w),
        .pkt_error_code_o(pkt_error_code_w)
    );

    protocol_controller #(
        .SAMPLE_WIDTH(8),
        .WINDOW_SIZE(WINDOW_SIZE)
    ) u_protocol (
        .clk_i(clk_27m_i),
        .rst_n_i(rst_n_i),
        .pkt_cmd_i(pkt_cmd_w),
        .pkt_data_i(pkt_data_w),
        .pkt_valid_i(pkt_valid_w),
        .pkt_ready_o(pkt_ready_w),
        .pkt_error_i(pkt_error_w | rx_frame_err_w),
        .pkt_error_code_i(rx_frame_err_w ? 8'hE4 : pkt_error_code_w),
        .tx_data_o(tx_data_w),
        .tx_valid_o(tx_valid_w),
        .tx_ready_i(tx_ready_w),
        .current_average_o(avg_w),
        .average_valid_o(avg_valid_w),
        .overflow_o(overflow_w),
        .sample_count_o(sample_count_w)
    );

    uart_tx #(
        .CLOCK_HZ(CLOCK_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk_i(clk_27m_i),
        .rst_n_i(rst_n_i),
        .data_i(tx_data_w),
        .data_valid_i(tx_valid_w),
        .data_ready_o(tx_ready_w),
        .tx_o(uart_tx_o),
        .busy_o()
    );

    assign led_status_o[0] = avg_valid_w;
    assign led_status_o[1] = overflow_w;
    assign led_status_o[2] = (sample_count_w != 8'd0);
    assign led_status_o[3] = rx_frame_err_w;
endmodule
