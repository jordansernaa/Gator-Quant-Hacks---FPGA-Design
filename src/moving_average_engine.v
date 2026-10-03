`timescale 1ns/1ps

module moving_average_engine #(
    parameter integer DATA_WIDTH = 8,
    parameter integer WINDOW_SIZE = 8,
    parameter integer SUM_WIDTH = DATA_WIDTH + 4
) (
    input  wire                      clk_i,
    input  wire                      rst_n_i,
    input  wire [DATA_WIDTH-1:0]     s_data_i,
    input  wire                      s_valid_i,
    output wire                      s_ready_o,
    output reg  [DATA_WIDTH-1:0]     m_data_o,
    output reg                       m_valid_o,
    input  wire                      m_ready_i,
    output reg  [DATA_WIDTH-1:0]     avg_current_o,
    output reg                       avg_available_o,
    output reg                       overflow_o,
    output reg  [7:0]                sample_count_o
);
    localparam integer PTR_W = (WINDOW_SIZE <= 2) ? 1 : $clog2(WINDOW_SIZE);
    reg [DATA_WIDTH-1:0] window_mem [0:WINDOW_SIZE-1];
    reg [SUM_WIDTH-1:0] sum_r;
    reg [PTR_W-1:0] wr_ptr_r;

    integer i;
    reg [DATA_WIDTH-1:0] evicted_sample;
    reg [SUM_WIDTH:0] sum_next_wide;
    reg [SUM_WIDTH-1:0] sum_next;
    reg [7:0] count_next;
    reg [7:0] divisor;

    assign s_ready_o = 1'b1;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            sum_r <= {SUM_WIDTH{1'b0}};
            wr_ptr_r <= {PTR_W{1'b0}};
            sample_count_o <= 8'd0;
            m_data_o <= {DATA_WIDTH{1'b0}};
            m_valid_o <= 1'b0;
            avg_current_o <= {DATA_WIDTH{1'b0}};
            avg_available_o <= 1'b0;
            overflow_o <= 1'b0;
            for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
                window_mem[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            if (m_valid_o && m_ready_i) begin
                m_valid_o <= 1'b0;
            end

            if (s_valid_i && s_ready_o) begin
                evicted_sample = (sample_count_o >= WINDOW_SIZE[7:0]) ? window_mem[wr_ptr_r] : {DATA_WIDTH{1'b0}};
                sum_next_wide = {1'b0, sum_r} + {{(SUM_WIDTH-DATA_WIDTH+1){1'b0}}, s_data_i} - {{(SUM_WIDTH-DATA_WIDTH+1){1'b0}}, evicted_sample};

                if (sum_next_wide[SUM_WIDTH]) begin
                    sum_next = {SUM_WIDTH{1'b0}};
                end else begin
                    sum_next = sum_next_wide[SUM_WIDTH-1:0];
                end

                sum_r <= sum_next;
                window_mem[wr_ptr_r] <= s_data_i;
                if (wr_ptr_r == (WINDOW_SIZE - 1)) begin
                    wr_ptr_r <= {PTR_W{1'b0}};
                end else begin
                    wr_ptr_r <= wr_ptr_r + 1'b1;
                end

                if (sample_count_o < WINDOW_SIZE[7:0]) begin
                    count_next = sample_count_o + 8'd1;
                    sample_count_o <= sample_count_o + 8'd1;
                end else begin
                    count_next = WINDOW_SIZE[7:0];
                    sample_count_o <= WINDOW_SIZE[7:0];
                end

                divisor = (count_next == 8'd0) ? 8'd1 : count_next;
                avg_current_o <= sum_next / divisor;
                avg_available_o <= 1'b1;
                m_data_o <= sum_next / divisor;
                m_valid_o <= 1'b1;
            end
        end
    end
endmodule
