`timescale 1ns/1ps

module tb_uart_loopback;
    reg clk;
    reg rst_n;

    reg [7:0] tx_data;
    reg tx_valid;
    wire tx_ready;
    wire serial_line;

    wire [7:0] rx_data;
    wire rx_valid;
    reg rx_ready;
    wire rx_frame_err;

    reg [7:0] captured;

    uart_tx #(
        .CLOCK_HZ(1_000_000),
        .BAUD_RATE(100_000)
    ) u_tx (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .data_i(tx_data),
        .data_valid_i(tx_valid),
        .data_ready_o(tx_ready),
        .tx_o(serial_line),
        .busy_o()
    );

    uart_rx #(
        .CLOCK_HZ(1_000_000),
        .BAUD_RATE(100_000)
    ) u_rx (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .rx_i(serial_line),
        .data_o(rx_data),
        .data_valid_o(rx_valid),
        .data_ready_i(rx_ready),
        .framing_error_o(rx_frame_err),
        .rx_busy_o()
    );

    always #5 clk = ~clk;

    task send_uart_byte;
        input [7:0] b;
        begin
            @(posedge clk);
            while (!tx_ready) @(posedge clk);
            tx_data <= b;
            tx_valid <= 1'b1;
            @(posedge clk);
            tx_valid <= 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        tx_data = 8'd0;
        tx_valid = 1'b0;
        rx_ready = 1'b1;
        captured = 8'd0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        send_uart_byte(8'h3C);
        wait (rx_valid === 1'b1);
        captured = rx_data;
        if (captured !== 8'h3C) begin
            $display("FAIL: loopback mismatch expected 0x3C got 0x%0h", captured);
            $finish(1);
        end

        if (rx_frame_err) begin
            $display("FAIL: unexpected framing error");
            $finish(1);
        end

        $display("PASS: tb_uart_loopback");
        $finish(0);
    end
endmodule
