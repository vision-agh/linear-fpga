`timescale 1ns / 1ps

module vector_multiplier_generator #(
    parameter int INPUT_PRECISION  = 8,
    parameter int WEIGHT_PRECISION = 8,
    parameter int ACC_PRECISION    = 32,
    parameter int NUM_VALUES       = 4,
    parameter int MUL_PER_FEATURE  = 4
) (
    input  logic                                clk,
    input  logic                                rst,
    input  logic                                ce,
    input  logic [INPUT_PRECISION-1:0]          features_in [NUM_VALUES-1:0],
    input  logic [WEIGHT_PRECISION-1:0]         weights_in  [NUM_VALUES-1:0],
    output logic signed [ACC_PRECISION-1:0]     mac_acc     [MUL_PER_FEATURE-1:0],
    output logic signed [ACC_PRECISION-1:0]     weight_sum  [MUL_PER_FEATURE-1:0],
    output logic signed [ACC_PRECISION-1:0]     feature_sum [MUL_PER_FEATURE-1:0]
);

    localparam int VALUES_PER_MULTIPLIER = NUM_VALUES / MUL_PER_FEATURE;
    genvar i;
    for (i = 0; i < MUL_PER_FEATURE; i++) begin : gen_vector_multiplier
        logic [INPUT_PRECISION-1:0] local_features [VALUES_PER_MULTIPLIER-1:0];
        logic [WEIGHT_PRECISION-1:0] local_weights [VALUES_PER_MULTIPLIER-1:0];

        always_comb begin
            for (int j = 0; j < VALUES_PER_MULTIPLIER; j++) begin
                local_features[j] = features_in[i * VALUES_PER_MULTIPLIER + j];
                local_weights[j] = weights_in[i * VALUES_PER_MULTIPLIER + j];
            end
        end

        vector_multiplier #(
            .INPUT_PRECISION  ( INPUT_PRECISION       ),
            .WEIGHT_PRECISION ( WEIGHT_PRECISION      ),
            .ACC_PRECISION    ( ACC_PRECISION         ),
            .NUM_VALUES       ( VALUES_PER_MULTIPLIER )
        ) u_vector_multiplier (
            .clk        ( clk            ),
            .rst        ( rst            ),
            .ce         ( ce             ),
            .features_in( local_features ),
            .weights_in ( local_weights  ),
            .mac_acc    ( mac_acc[i]     ),
            .weight_sum ( weight_sum[i]  ),
            .feature_sum( feature_sum[i] )
        );
    end

endmodule
