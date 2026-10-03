`timescale 1ns/1ps

module tb_moving_average_engine;
    reg clk;
    reg rst_n;
    reg [7:0] s_data;
    reg s_valid;
    wire s_ready;
    wire [7:0] m_data;
    wire m_valid;
    reg m_ready;
    wire [7:0] avg_current;
    wire avg_available;
    wire overflow;
    wire [7:0] sample_count;

    moving_average_engine #(
        .DATA_WIDTH(8),
        .WINDOW_SIZE(4),
        .SUM_WIDTH(12)
    ) dut (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .s_data_i(s_data),
        .s_valid_i(s_valid),
        .s_ready_o(s_ready),
        .m_data_o(m_data),
        .m_valid_o(m_valid),
        .m_ready_i(m_ready),
        .avg_current_o(avg_current),
        .avg_available_o(avg_available),
        .overflow_o(overflow),
        .sample_count_o(sample_count)
    );

    always #5 clk = ~clk;

    task push_sample;
        input [7:0] sample;
        begin
            @(posedge clk);
            s_data <= sample;
            s_valid <= 1'b1;
            @(posedge clk);
            s_valid <= 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        s_data = 8'd0;
        s_valid = 1'b0;
        m_ready = 1'b1;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        push_sample(8'd10);
        if (avg_current !== 8'd10) begin
            $display("FAIL: avg after 10 expected 10 got %0d", avg_current);
            $finish(1);
        end

        push_sample(8'd20);
        if (avg_current !== 8'd15) begin
            $display("FAIL: avg after 10,20 expected 15 got %0d", avg_current);
            $finish(1);
        end

        push_sample(8'd30);
        if (avg_current !== 8'd20) begin
            $display("FAIL: avg after 10,20,30 expected 20 got %0d", avg_current);
            $finish(1);
        end

        push_sample(8'd40);
        if (avg_current !== 8'd25) begin
            $display("FAIL: avg after 4 samples expected 25 got %0d", avg_current);
            $finish(1);
        end

        push_sample(8'd50); // windowed avg of 20,30,40,50 => 35
        if (avg_current !== 8'd35) begin
            $display("FAIL: rolling avg expected 35 got %0d", avg_current);
            $finish(1);
        end

        if (!avg_available || overflow) begin
            $display("FAIL: status bits unexpected avg_available=%0d overflow=%0d", avg_available, overflow);
            $finish(1);
        end

        $display("PASS: tb_moving_average_engine");
        $finish(0);
    end
endmodule
