`timescale 1ns / 1ps

module multiplier_top #(
    parameter int PRECISION              = 8,
    parameter int BIAS_PRECISION         = 32,
    parameter int OUTPUT_STAGE_PRECISION = 64,
    parameter int NUM_FEATURES           = 2, // number of parallel features
    parameter int MUL_PER_FEATURE        = 4,
    parameter int N                      = 8,
    parameter int M_MUL                  = 2294967296,
    parameter int Z_WEIGHTS              = 5
) (
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      ce,
    input  logic [BIAS_PRECISION-1:0] bias,     
    input  logic [NUM_FEATURES-1:0][N-1:0][PRECISION-1:0] weights_in,
    input  logic [NUM_FEATURES-1:0][N-1:0][PRECISION-1:0] features,
    output logic [NUM_FEATURES-1:0][PRECISION-1:0] out
);

    logic [NUM_FEATURES-1:0][MUL_PER_FEATURE-1:0][BIAS_PRECISION-1:0] acc_sliced;
    logic [NUM_FEATURES-1:0][MUL_PER_FEATURE-1:0][BIAS_PRECISION-1:0] ai_sliced;

    logic [NUM_FEATURES-1:0][BIAS_PRECISION-1:0] acc;
    logic [NUM_FEATURES-1:0][BIAS_PRECISION-1:0] ai;
    
    genvar i;

    for(i=0; i<NUM_FEATURES; i++) begin
        vector_multiplier_generator #(
            .NUM_FEATURES    ( N ),
            .PRECISION       ( PRECISION ),
            .BIAS_PRECISION  ( BIAS_PRECISION ),
            .MUL_PER_FEATURE ( MUL_PER_FEATURE )
        ) u_vector_multiplier_generator (
            .clk         ( clk ),
            .rst         ( rst ),
            .ce          ( ce ),
            .features_in ( features[i] ),
            .weights_in  ( weights_in[i] ),
            .acc         ( acc_sliced[i] ),
            .ai          ( ai_sliced[i] )
        );
    end

    for(i=0; i<NUM_FEATURES; i++) begin
        accumulator #(
            .BIAS_PRECISION  ( BIAS_PRECISION ),
            .MUL_PER_FEATURE ( MUL_PER_FEATURE )
        ) u_accumulator (
            .clk        ( clk ),
            .rst        ( rst ),
            .ce         ( ce ),
            .data_in_A  ( acc_sliced[i] ),
            .data_in_B  ( ai_sliced[i] ),
            .data_out_A ( acc[i] ),
            .data_out_B ( ai[i] )
        );
    end

    for(i=0; i<NUM_FEATURES; i++) begin
        output_stage #(
            .PRECISION        ( PRECISION ),
            .Z_WEIGHTS        ( Z_WEIGHTS ),
            .M_MUL            ( M_MUL ),
            .BIAS_PRECISION   ( BIAS_PRECISION ),
            .OUTPUT_PRECISION ( OUTPUT_STAGE_PRECISION )
        ) u_output_stage (
            .clk   ( clk ),
            .rst   ( rst ),
            .ce    ( ce ),
            .ai    ( ai[i] ),
            .acc   ( acc[i] ),
            .bias  ( bias ),
            .out   ( out[i] )
        );
    end

endmodule
