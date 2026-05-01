`timescale 1ns / 1ps

module output_stage #(
    parameter int INPUT_PRECISION        = 8,
    parameter int OUTPUT_PRECISION       = 8,
    parameter int ACC_PRECISION          = 32,
    parameter int OUTPUT_STAGE_PRECISION = 64,
    parameter int IN_ZP                  = 128,
    parameter int W_ZP                   = 0,
    parameter int N                      = 1,
    parameter int OUT_ZP                 = 128,
    parameter int M_MUL                  = 1073741824,
    parameter int M_SHIFT                = 30,
    parameter bit USE_DIRECT_CORRECTED_ACC = 1'b0
) (
    input  logic                                clk,
    input  logic                                rst,
    input  logic                                ce,
    input  logic signed [ACC_PRECISION-1:0]     weight_sum,
    input  logic signed [ACC_PRECISION-1:0]     feature_sum,
    input  logic signed [ACC_PRECISION-1:0]     mac_acc,
    input  logic signed [ACC_PRECISION-1:0]     bias,
    input  logic signed [OUTPUT_STAGE_PRECISION-1:0] corrected_acc_in,
    output logic signed [OUTPUT_STAGE_PRECISION-1:0] corrected_acc_out,
    output logic [OUTPUT_PRECISION-1:0]         out
);

    localparam int OUTPUT_MIN = 0;
    localparam int OUTPUT_MAX = (1 << OUTPUT_PRECISION) - 1;

    logic signed [OUTPUT_STAGE_PRECISION-1:0] corrected_acc;
    logic signed [OUTPUT_STAGE_PRECISION-1:0] scaled_acc;
    logic signed [OUTPUT_STAGE_PRECISION-1:0] requantized_acc;
    logic signed [OUTPUT_STAGE_PRECISION-1:0] next_out_value;

    always_ff @(posedge clk) begin
        if (rst) begin
            out <= '0;
        end else if (ce) begin
            if (next_out_value < OUTPUT_MIN) begin
                out <= OUTPUT_MIN[OUTPUT_PRECISION-1:0];
            end else if (next_out_value > OUTPUT_MAX) begin
                out <= OUTPUT_MAX[OUTPUT_PRECISION-1:0];
            end else begin
                out <= next_out_value[OUTPUT_PRECISION-1:0];
            end
        end
    end

    always_comb begin
        if (USE_DIRECT_CORRECTED_ACC) begin
            corrected_acc = corrected_acc_in;
        end else begin
            corrected_acc =
                mac_acc
                - ($signed(IN_ZP) * weight_sum)
                - ($signed(W_ZP) * feature_sum)
                + $signed(N * IN_ZP * W_ZP)
                + bias;
        end
        scaled_acc     = corrected_acc * $signed(M_MUL);
        requantized_acc = scaled_acc >>> M_SHIFT;
        next_out_value = requantized_acc + $signed(OUT_ZP);
        corrected_acc_out = corrected_acc;
    end

endmodule
