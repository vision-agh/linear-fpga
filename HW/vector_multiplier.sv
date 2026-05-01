`timescale 1ns / 1ps

module vector_multiplier #(
    parameter int INPUT_PRECISION  = 8,
    parameter int WEIGHT_PRECISION = 8,
    parameter int ACC_PRECISION    = 32,
    parameter int NUM_VALUES       = 1
) (
    input  logic                              clk,
    input  logic                              rst,
    input  logic                              ce,
    input  logic [INPUT_PRECISION-1:0]        features_in [NUM_VALUES-1:0],
    input  logic [WEIGHT_PRECISION-1:0]       weights_in [NUM_VALUES-1:0],
    output logic signed [ACC_PRECISION-1:0]   mac_acc,
    output logic signed [ACC_PRECISION-1:0]   weight_sum,
    output logic signed [ACC_PRECISION-1:0]   feature_sum
);

    logic signed [ACC_PRECISION-1:0] next_mac_acc;
    logic signed [ACC_PRECISION-1:0] next_weight_sum;
    logic signed [ACC_PRECISION-1:0] next_feature_sum;

    always_ff @(posedge clk) begin
        if (rst) begin
            mac_acc     <= '0;
            weight_sum  <= '0;
            feature_sum <= '0;
        end else if (ce) begin
            mac_acc     <= next_mac_acc;
            weight_sum  <= next_weight_sum;
            feature_sum <= next_feature_sum;
        end
    end

    always_comb begin
        next_mac_acc = '0;
        next_weight_sum = '0;
        next_feature_sum = '0;

        for (int i = 0; i < NUM_VALUES; i++) begin
            logic signed [ACC_PRECISION-1:0] feature_value;
            logic signed [ACC_PRECISION-1:0] weight_value;

            feature_value = $signed({1'b0, features_in[i]});
            weight_value = $signed({1'b0, weights_in[i]});

            next_mac_acc    += feature_value * weight_value;
            next_weight_sum += weight_value;
            next_feature_sum += feature_value;
        end
    end

endmodule
