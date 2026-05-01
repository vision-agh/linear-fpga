`timescale 1ns / 1ps

module accumulator #(
    parameter int ACC_PRECISION    = 32,
    parameter int MUL_PER_FEATURE  = 1
) (
    input  logic                              clk,
    input  logic                              rst,
    input  logic                              ce,
    input  logic signed [ACC_PRECISION-1:0]   data_in_A [MUL_PER_FEATURE-1:0],
    input  logic signed [ACC_PRECISION-1:0]   data_in_B [MUL_PER_FEATURE-1:0],
    output logic signed [ACC_PRECISION-1:0]   data_out_A,
    output logic signed [ACC_PRECISION-1:0]   data_out_B
);

    logic signed [ACC_PRECISION-1:0] next_data_out_A;
    logic signed [ACC_PRECISION-1:0] next_data_out_B;

    always_ff @(posedge clk) begin
        if (rst) begin
            data_out_A <= '0;
            data_out_B <= '0;
        end else if (ce) begin
            data_out_A <= next_data_out_A;
            data_out_B <= next_data_out_B;
        end
    end

    always_comb begin
        next_data_out_A = '0;
        next_data_out_B = '0;

        for (int i = 0; i < MUL_PER_FEATURE; i++) begin
            next_data_out_A += data_in_A[i];
            next_data_out_B += data_in_B[i];
        end
    end

endmodule
