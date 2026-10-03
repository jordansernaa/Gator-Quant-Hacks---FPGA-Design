`timescale 1ns/1ps

module tb_packet_logic;
    reg clk;
    reg rst_n;

    reg [7:0] byte_in;
    reg byte_valid;
    wire byte_ready;

    wire [7:0] pkt_cmd;
    wire [7:0] pkt_data;
    wire pkt_valid;
    wire pkt_ready;
    wire pkt_error;
    wire [7:0] pkt_error_code;

    wire [7:0] tx_data;
    wire tx_valid;
    reg tx_ready;

    wire [7:0] avg;
    wire avg_valid;
    wire overflow;
    wire [7:0] sample_count;

    reg [7:0] resp [0:3];
    integer resp_idx;

    packet_rx u_pkt (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .byte_i(byte_in),
        .byte_valid_i(byte_valid),
        .byte_ready_o(byte_ready),
        .pkt_cmd_o(pkt_cmd),
        .pkt_data_o(pkt_data),
        .pkt_valid_o(pkt_valid),
        .pkt_ready_i(pkt_ready),
        .pkt_error_o(pkt_error),
        .pkt_error_code_o(pkt_error_code)
    );

    protocol_controller #(
        .SAMPLE_WIDTH(8),
        .WINDOW_SIZE(4)
    ) u_ctrl (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .pkt_cmd_i(pkt_cmd),
        .pkt_data_i(pkt_data),
        .pkt_valid_i(pkt_valid),
        .pkt_ready_o(pkt_ready),
        .pkt_error_i(pkt_error),
        .pkt_error_code_i(pkt_error_code),
        .tx_data_o(tx_data),
        .tx_valid_o(tx_valid),
        .tx_ready_i(tx_ready),
        .current_average_o(avg),
        .average_valid_o(avg_valid),
        .overflow_o(overflow),
        .sample_count_o(sample_count)
    );

    always #5 clk = ~clk;

    task send_byte;
        input [7:0] b;
        begin
            @(posedge clk);
            byte_in <= b;
            byte_valid <= 1'b1;
            @(posedge clk);
            byte_valid <= 1'b0;
        end
    endtask

    task send_packet;
        input [7:0] cmd;
        input [7:0] data;
        begin
            send_byte(8'hA5);
            send_byte(cmd);
            send_byte(data);
            send_byte(8'hA5 ^ cmd ^ data);
        end
    endtask

    task collect_response;
        integer timeout;
        begin
            resp_idx = 0;
            timeout = 0;
            while (resp_idx < 4 && timeout < 200) begin
                @(posedge clk);
                if (tx_valid && tx_ready) begin
                    resp[resp_idx] = tx_data;
                    resp_idx = resp_idx + 1;
                end
                timeout = timeout + 1;
            end
            if (resp_idx != 4) begin
                $display("FAIL: timeout collecting response bytes");
                $finish(1);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        byte_in = 8'd0;
        byte_valid = 1'b0;
        tx_ready = 1'b1;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        send_packet(8'h01, 8'd16);
        collect_response();
        if (resp[1] !== 8'h00 || resp[2] !== 8'd16) begin
            $display("FAIL: push sample response invalid");
            $finish(1);
        end

        send_packet(8'h02, 8'd0);
        collect_response();
        if (resp[1] !== 8'h00 || resp[2] !== 8'd16) begin
            $display("FAIL: read avg response invalid: %0h %0h", resp[1], resp[2]);
            $finish(1);
        end

        send_packet(8'h7F, 8'd1);
        collect_response();
        if (resp[1] !== 8'hE0 || resp[2] !== 8'h7F) begin
            $display("FAIL: bad cmd response invalid");
            $finish(1);
        end

        // malformed packet (bad checksum) should produce E2
        send_byte(8'hA5);
        send_byte(8'h01);
        send_byte(8'h05);
        send_byte(8'h00);
        collect_response();
        if (resp[1] !== 8'hE2) begin
            $display("FAIL: expected checksum error E2 got %0h", resp[1]);
            $finish(1);
        end

        $display("PASS: tb_packet_logic");
        $finish(0);
    end
endmodule
