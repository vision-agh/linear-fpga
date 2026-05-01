`timescale 1ns / 1ps

module multiplier_top #(
    parameter int INPUT_PRECISION        = 8,
    parameter int WEIGHT_PRECISION       = 8,
    parameter int OUTPUT_PRECISION       = 8,
    parameter int ACC_PRECISION          = 32,
    parameter int OUTPUT_STAGE_PRECISION = 64,
    parameter int NUM_FEATURES           = 2,
    parameter int MUL_PER_FEATURE        = 8,
    parameter int N                      = 16,
    parameter int IN_ZP                  = 128,
    parameter int W_ZP                   = 0,
    parameter int OUT_ZP                 = 128,
    parameter int M_MUL                  = 1073741824,
    parameter int M_SHIFT                = 30
) (
    input  logic                                  clk,
    input  logic                                  rst,
    input  logic                                  ce,
    input  logic signed [ACC_PRECISION-1:0]       bias,
    input  logic [WEIGHT_PRECISION-1:0]           weights_in [N-1:0],
    input  logic [INPUT_PRECISION-1:0]            features [NUM_FEATURES-1:0][N-1:0],
    output logic [OUTPUT_PRECISION-1:0]           out [NUM_FEATURES-1:0],
    output logic signed [OUTPUT_STAGE_PRECISION-1:0] corrected_acc_out [NUM_FEATURES-1:0]
);

    localparam int DELAY_FEATURES = 0;
    localparam int DELAY_BIAS     = 1;
    localparam int DELAY_WEIGHTS  = 0;

    logic signed [ACC_PRECISION-1:0] mac_acc_sliced    [NUM_FEATURES-1:0][MUL_PER_FEATURE-1:0];
    logic signed [ACC_PRECISION-1:0] weight_sum_sliced [NUM_FEATURES-1:0][MUL_PER_FEATURE-1:0];
    logic signed [ACC_PRECISION-1:0] feature_sum_sliced [NUM_FEATURES-1:0][MUL_PER_FEATURE-1:0];

    logic signed [ACC_PRECISION-1:0] mac_acc     [NUM_FEATURES-1:0];
    logic signed [ACC_PRECISION-1:0] weight_sum  [NUM_FEATURES-1:0];
    logic signed [ACC_PRECISION-1:0] feature_sum [NUM_FEATURES-1:0];

    logic [INPUT_PRECISION-1:0]         delayed_features [NUM_FEATURES-1:0][N-1:0];
    logic signed [ACC_PRECISION-1:0]    delayed_bias;
    logic [WEIGHT_PRECISION-1:0]        delayed_weights [N-1:0];

    delay_buffer_2d #(
        .NUM_FEATURES ( NUM_FEATURES   ),
        .N            ( N              ),
        .PRECISION    ( INPUT_PRECISION ),
        .DELAY        ( DELAY_FEATURES )
    ) u_delay_buffer_2d (
        .clk   ( clk              ),
        .idata ( features         ),
        .odata ( delayed_features )
    );

    delay_buffer_0d #(
        .PRECISION ( ACC_PRECISION ),
        .DELAY     ( DELAY_BIAS    )
    ) u_delay_buffer_0d (
        .clk   ( clk          ),
        .idata ( bias         ),
        .odata ( delayed_bias )
    );

    always_comb begin
        for (int weight_idx = 0; weight_idx < N; weight_idx++) begin
            delayed_weights[weight_idx] = weights_in[weight_idx];
        end
    end

    genvar i;
    for (i = 0; i < NUM_FEATURES; i++) begin : gen_features
        logic [INPUT_PRECISION-1:0] local_features [N-1:0];
        logic signed [ACC_PRECISION-1:0] local_mac_acc_sliced [MUL_PER_FEATURE-1:0];
        logic signed [ACC_PRECISION-1:0] local_weight_sum_sliced [MUL_PER_FEATURE-1:0];
        logic signed [ACC_PRECISION-1:0] local_feature_sum_sliced [MUL_PER_FEATURE-1:0];

        genvar j;
        for (j = 0; j < N; j++) begin : gen_local_feature_values
            assign local_features[j] = delayed_features[i][j];
        end

        vector_multiplier_generator #(
            .INPUT_PRECISION  ( INPUT_PRECISION  ),
            .WEIGHT_PRECISION ( WEIGHT_PRECISION ),
            .ACC_PRECISION    ( ACC_PRECISION    ),
            .NUM_VALUES       ( N                ),
            .MUL_PER_FEATURE  ( MUL_PER_FEATURE  )
        ) u_vector_multiplier_generator (
            .clk        ( clk                    ),
            .rst        ( rst                    ),
            .ce         ( ce                     ),
            .features_in( local_features         ),
            .weights_in ( delayed_weights        ),
            .mac_acc    ( local_mac_acc_sliced   ),
            .weight_sum ( local_weight_sum_sliced ),
            .feature_sum( local_feature_sum_sliced )
        );

        for (j = 0; j < MUL_PER_FEATURE; j++) begin : gen_local_acc_values
            assign mac_acc_sliced[i][j] = local_mac_acc_sliced[j];
            assign weight_sum_sliced[i][j] = local_weight_sum_sliced[j];
            assign feature_sum_sliced[i][j] = local_feature_sum_sliced[j];
        end

        accumulator #(
            .ACC_PRECISION   ( ACC_PRECISION   ),
            .MUL_PER_FEATURE ( MUL_PER_FEATURE )
        ) u_accumulator (
            .clk        ( clk                  ),
            .rst        ( rst                  ),
            .ce         ( ce                   ),
            .data_in_A  ( local_mac_acc_sliced    ),
            .data_in_B  ( local_weight_sum_sliced ),
            .data_out_A ( mac_acc[i]           ),
            .data_out_B ( weight_sum[i]        )
        );

        accumulator #(
            .ACC_PRECISION   ( ACC_PRECISION   ),
            .MUL_PER_FEATURE ( MUL_PER_FEATURE )
        ) u_feature_accumulator (
            .clk        ( clk                   ),
            .rst        ( rst                   ),
            .ce         ( ce                    ),
            .data_in_A  ( local_feature_sum_sliced ),
            .data_in_B  ( local_feature_sum_sliced ),
            .data_out_A ( feature_sum[i]        ),
            .data_out_B (                       )
        );

        output_stage #(
            .INPUT_PRECISION        ( INPUT_PRECISION        ),
            .OUTPUT_PRECISION       ( OUTPUT_PRECISION       ),
            .ACC_PRECISION          ( ACC_PRECISION          ),
            .OUTPUT_STAGE_PRECISION ( OUTPUT_STAGE_PRECISION ),
            .IN_ZP                  ( IN_ZP                  ),
            .W_ZP                   ( W_ZP                   ),
            .N                      ( N                      ),
            .OUT_ZP                 ( OUT_ZP                 ),
            .M_MUL                  ( M_MUL                  ),
            .M_SHIFT                ( M_SHIFT                )
        ) u_output_stage (
            .clk        ( clk           ),
            .rst        ( rst           ),
            .ce         ( ce            ),
            .weight_sum ( weight_sum[i] ),
            .feature_sum( feature_sum[i]),
            .mac_acc    ( mac_acc[i]    ),
            .bias       ( delayed_bias  ),
            .corrected_acc_in('0),
            .corrected_acc_out(corrected_acc_out[i]),
            .out        ( out[i]        )
        );
    end

endmodule
