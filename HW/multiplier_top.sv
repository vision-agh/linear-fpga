`timescale 1ns / 1ps

module multiplier_top #(
    parameter int TEMP                   = 6,
    parameter int PRECISION              = 8,
    parameter int BIAS_PRECISION         = 32,
    parameter int OUTPUT_STAGE_PRECISION = 64,
    parameter int NUM_FEATURES           = 2, // number of parallel features
    parameter int MUL_PER_FEATURE        = 8,
    parameter int N                      = 16,
    parameter int M_MUL                  = 2094967296,
    parameter int Z_WEIGHTS              = 5
) (
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      ce,
    input  logic [BIAS_PRECISION-1:0] bias,     
    input  logic [PRECISION-1:0]      weights_in [N-1:0],
    input  logic [PRECISION-1:0]      features   [NUM_FEATURES-1:0][N-1:0],
    output logic [PRECISION-1:0]      out        [NUM_FEATURES-1:0]
);

    localparam int DELAY_FEATURES = (TEMP < 0) ? 1 : (TEMP == 1) ? 1 : 1; //when temp < 0 == 2,  temp > 1 == 1
    localparam int DELAY_BIAS     = (TEMP < 0) ? 2 : (TEMP == 1) ? 2 : 2; //when temp < 0 == 1 ;; temp > 1 == 2 ;; temp == 1 == 2
    localparam int DELAY_WEIGHT   = (TEMP < 0) ? 0 : (TEMP == 1) ? 0 : 0; // when temp > 1 == 0 ;; temp = 1 == 0
    
    logic [BIAS_PRECISION-1:0] acc_sliced [NUM_FEATURES-1:0][MUL_PER_FEATURE-1:0];
    logic [BIAS_PRECISION-1:0] ai_sliced  [NUM_FEATURES-1:0][MUL_PER_FEATURE-1:0];

    logic [BIAS_PRECISION-1:0] acc [NUM_FEATURES-1:0];
    logic [BIAS_PRECISION-1:0] ai  [NUM_FEATURES-1:0];
    
    logic [PRECISION-1:0]      d_features [NUM_FEATURES-1:0][N-1:0];
    logic [BIAS_PRECISION-1:0] d_bias;
    logic [PRECISION-1:0]      d_weights_in [N-1:0];
    
    
    genvar i;
    
    delay_buffer_2d #(
        .NUM_FEATURES( NUM_FEATURES   ),
        .N           ( N              ),
        .PRECISION   ( PRECISION      ),
        .DELAY       ( DELAY_FEATURES )
    ) u_delay_buffer_2d (
        .clk   ( clk        ),
        .idata ( features   ),
        .odata ( d_features )
    );
    
    delay_buffer_0d #(
        .PRECISION ( BIAS_PRECISION ),
        .DELAY     ( DELAY_BIAS     ),
        .N         ( N              )
    ) u_delay_buffer_0d (
        .clk   ( clk    ),
        .idata ( bias   ),
        .odata ( d_bias )
    );
    
    delay_buffer_1d #(
        .PRECISION ( PRECISION    ),
        .DELAY     ( DELAY_WEIGHT ),
        .N         ( N           )
    ) u_delay_buffer_1d (
        .clk   ( clk    ),
        .idata ( weights_in   ),
        .odata ( d_weights_in )
    );

    for(i=0; i<NUM_FEATURES; i++) begin
        vector_multiplier_generator #(
            .NUM_FEATURES    ( N               ),
            .PRECISION       ( PRECISION       ),
            .BIAS_PRECISION  ( BIAS_PRECISION  ),
            .MUL_PER_FEATURE ( MUL_PER_FEATURE )
        ) u_vector_multiplier_generator (
            .clk         ( clk           ),
            .rst         ( rst           ),
            .ce          ( ce            ),
            .features_in ( d_features[i] ),
            .weights_in  ( d_weights_in    ),
            .acc         ( acc_sliced[i] ),
            .ai          ( ai_sliced[i]  )
        );
    end

    for(i=0; i<NUM_FEATURES; i++) begin
        accumulator #(
            .BIAS_PRECISION  ( BIAS_PRECISION  ),
            .MUL_PER_FEATURE ( MUL_PER_FEATURE )
        ) u_accumulator (
            .clk        ( clk           ),
            .rst        ( rst           ),
            .ce         ( ce            ),
            .data_in_A  ( acc_sliced[i] ),
            .data_in_B  ( ai_sliced[i]  ),
            .data_out_A ( acc[i]        ),
            .data_out_B ( ai[i]         )
        );
    end

    for(i=0; i<NUM_FEATURES; i++) begin
        output_stage #(
            .PRECISION              ( PRECISION              ),
            .Z_WEIGHTS              ( Z_WEIGHTS              ),
            .M_MUL                  ( M_MUL                  ),
            .BIAS_PRECISION         ( BIAS_PRECISION         ),
            .OUTPUT_STAGE_PRECISION ( OUTPUT_STAGE_PRECISION )
        ) u_output_stage (
            .clk      ( clk    ),
            .rst      ( rst    ),
            .ce       ( ce     ),
            .ai       ( ai[i]  ),
            .acc      ( acc[i] ),
            .bias     ( d_bias ),
            .out      ( out[i] )
        );
    end

endmodule
