`timescale 1ns / 1ps

module parallel_memory_fetcher #(
    parameter int BRAM_WIDTH       = 64,
    parameter int TEMP             = 2,
    parameter int M                = 5,
    parameter int N                = 4,
    parameter int BIAS_PRECISION   = 32,
    parameter int WEIGHT_PRECISION = 8,
    parameter MEMORY_FILE          = "generated/fc1_weights.mem"
) (
    input  logic                                           clk,
    input  logic                                           clr,
    input  logic                                           ce,
    output logic signed [WEIGHT_PRECISION-1:0]             data_out [TEMP-1:0][N-1:0],
    output logic signed [BIAS_PRECISION-1:0]               bias [TEMP-1:0]
);

    localparam int SECTION_LENGTH = M / TEMP;

    logic [BRAM_WIDTH-1:0] mem_data_out [TEMP-1:0];
    logic [$clog2(M)-1:0]  line_counter;
    logic [$clog2(M)-1:0]  addr [TEMP-1:0];

    logic signed [WEIGHT_PRECISION-1:0] next_data_out [TEMP-1:0][N-1:0];
    logic signed [BIAS_PRECISION-1:0]   next_bias [TEMP-1:0];

    genvar i;
    for (i = 0; i < TEMP; i++) begin : gen_parallel_bram
        memory_weights #(
            .DATA_WIDTH  ( BRAM_WIDTH  ),
            .ADDR_DEPTH  ( M           ),
            .MEMORY_FILE ( MEMORY_FILE )
        ) u_memory_weights (
            .clk  ( clk             ),
            .ce   ( ce              ),
            .addr ( addr[i]         ),
            .dout ( mem_data_out[i] )
        );
    end

    always_ff @(posedge clk) begin
        if (clr) begin
            line_counter <= '0;
            for (int reset_branch = 0; reset_branch < TEMP; reset_branch++) begin
                bias[reset_branch] <= '0;
                for (int reset_col = 0; reset_col < N; reset_col++) begin
                    data_out[reset_branch][reset_col] <= '0;
                end
            end
        end else if (ce) begin
            if (line_counter < SECTION_LENGTH - 1) begin
                line_counter <= line_counter + 1'b1;
            end else begin
                line_counter <= '0;
            end

            for (int write_branch = 0; write_branch < TEMP; write_branch++) begin
                bias[write_branch] <= next_bias[write_branch];
                for (int write_col = 0; write_col < N; write_col++) begin
                    data_out[write_branch][write_col] <= next_data_out[write_branch][write_col];
                end
            end
        end
    end

    always_comb begin
        for (int branch = 0; branch < TEMP; branch++) begin
            addr[branch] = clr ? branch * SECTION_LENGTH : line_counter + branch * SECTION_LENGTH;
            next_bias[branch] = $signed(mem_data_out[branch][N * WEIGHT_PRECISION +: BIAS_PRECISION]);

            for (int col = 0; col < N; col++) begin
                next_data_out[branch][col] =
                    $signed(mem_data_out[branch][(N - 1 - col) * WEIGHT_PRECISION +: WEIGHT_PRECISION]);
            end
        end
    end

endmodule
