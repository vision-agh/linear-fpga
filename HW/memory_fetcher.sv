`timescale 1ns / 1ps

module memory_fetcher #(
    parameter int BRAM_WIDTH       = 3,
    parameter int M                = 5,
    parameter int N                = 5,
    parameter int BIAS_PRECISION   = 32,
    parameter int WEIGHT_PRECISION = 8,
    parameter MEMORY_FILE          = "generated/fc1_weights.mem"
) (
    input  logic                                   clk,
    input  logic                                   clr,
    input  logic                                   ce,
    output logic [WEIGHT_PRECISION-1:0]            data_out [N-1:0],
    output logic signed [BIAS_PRECISION-1:0]       bias
);

    logic [$clog2(M)-1:0] line_counter;
    logic [BRAM_WIDTH-1:0] mem_data_out;

    logic [WEIGHT_PRECISION-1:0] next_data_out [N-1:0];
    logic signed [BIAS_PRECISION-1:0]   next_bias;

    memory_weights #(
        .DATA_WIDTH  ( BRAM_WIDTH  ),
        .ADDR_DEPTH  ( M           ),
        .MEMORY_FILE ( MEMORY_FILE )
    ) u_memory_weights (
        .clk  ( clk          ),
        .ce   ( ce           ),
        .addr ( line_counter ),
        .dout ( mem_data_out )
    );

    always_ff @(posedge clk) begin
        if (clr) begin
            line_counter <= '0;
            for (int reset_idx = 0; reset_idx < N; reset_idx++) begin
                data_out[reset_idx] <= '0;
            end
            bias         <= '0;
        end else if (ce) begin
            if (line_counter < M - 1) begin
                line_counter <= line_counter + 1'b1;
            end else begin
                line_counter <= '0;
            end

            for (int write_idx = 0; write_idx < N; write_idx++) begin
                data_out[write_idx] <= next_data_out[write_idx];
            end
            bias     <= next_bias;
        end
    end

    always_comb begin
        for (int init_idx = 0; init_idx < N; init_idx++) begin
            next_data_out[init_idx] = '0;
        end
        next_bias = '0;

        for (int i = 0; i < N; i++) begin
            next_data_out[i] = mem_data_out[(N - 1 - i) * WEIGHT_PRECISION +: WEIGHT_PRECISION];
        end
        next_bias = $signed(mem_data_out[N * WEIGHT_PRECISION +: BIAS_PRECISION]);
    end

endmodule
