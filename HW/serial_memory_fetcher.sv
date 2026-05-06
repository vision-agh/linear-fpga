`timescale 1ns / 1ps

module serial_memory_fetcher #(
    parameter int BRAM_WIDTH       = 3,
    parameter int TEMP             = 2,
    parameter int M                = 5,
    parameter int N                = 5,
    parameter int BIAS_PRECISION   = 32,
    parameter int WEIGHT_PRECISION = 8,
    parameter MEMORY_FILE          = "generated/fc1_weights.mem"
) (
    input  logic                                         clk,
    input  logic                                         clr,
    input  logic                                         ce,
    input  logic [$clog2(M)-1:0]                         row_index,
    input  logic [$clog2(TEMP)-1:0]                      slice_index,
    output logic [WEIGHT_PRECISION-1:0]                  data_out [N / TEMP - 1:0],
    output logic signed [BIAS_PRECISION-1:0]             bias
);

    localparam int CHUNK_WIDTH = N / TEMP;
    localparam int ADDR_WIDTH = $clog2(M * TEMP);

    logic [ADDR_WIDTH-1:0] mem_addr;
    logic [BRAM_WIDTH-1:0] mem_data_out;
    logic [WEIGHT_PRECISION-1:0] next_data_out [CHUNK_WIDTH-1:0];
    logic signed [BIAS_PRECISION-1:0] next_bias;

    assign mem_addr = (slice_index * M) + row_index;

    memory_weights #(
        .DATA_WIDTH  ( BRAM_WIDTH  ),
        .ADDR_DEPTH  ( M * TEMP    ),
        .MEMORY_FILE ( MEMORY_FILE )
    ) u_memory_weights (
        .clk  ( clk          ),
        .ce   ( ce           ),
        .addr ( mem_addr     ),
        .dout ( mem_data_out )
    );

    always_ff @(posedge clk) begin
        if (clr) begin
            for (int reset_idx = 0; reset_idx < CHUNK_WIDTH; reset_idx++) begin
                data_out[reset_idx] <= '0;
            end
            bias <= '0;
        end else if (ce) begin
            for (int write_idx = 0; write_idx < CHUNK_WIDTH; write_idx++) begin
                data_out[write_idx] <= next_data_out[write_idx];
            end
            bias <= next_bias;
        end
    end

    always_comb begin
        for (int init_idx = 0; init_idx < CHUNK_WIDTH; init_idx++) begin
            next_data_out[init_idx] = '0;
        end
        next_bias = '0;

        for (int i = 0; i < CHUNK_WIDTH; i++) begin
            next_data_out[i] = mem_data_out[(CHUNK_WIDTH - 1 - i) * WEIGHT_PRECISION +: WEIGHT_PRECISION];
        end
        next_bias = $signed(mem_data_out[CHUNK_WIDTH * WEIGHT_PRECISION +: BIAS_PRECISION]);
    end

endmodule
