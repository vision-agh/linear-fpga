`timescale 1ns / 1ps

module vector_multiplier_generator #(
    parameter int NUM_FEATURES = 4,
    parameter int PRECISION = 8,
    parameter int BIAS_PRECISION = 32,
    parameter int MUL_PER_FEATURE = 4
) (
    input  logic clk,
    input  logic rst,
    input  logic ce,
    input  logic [NUM_FEATURES-1:0][PRECISION-1:0] features_in,
    input  logic [NUM_FEATURES-1:0][PRECISION-1:0] weights_in,
    output logic [MUL_PER_FEATURE-1:0][BIAS_PRECISION-1:0] acc,
    output logic [MUL_PER_FEATURE-1:0][BIAS_PRECISION-1:0] ai
);
    
    genvar i;
    
    for(i=0; i < MUL_PER_FEATURE; i++) begin
        vector_multiplier #(
            .PRECISION    ( PRECISION ),
            .NUM_FEATURES ( NUM_FEATURES/MUL_PER_FEATURE )
        ) u_vector_multiplier (
            .clk         ( clk ),
            .rst         ( rst ),
            .ce          ( ce  ),
            .features_in ( features_in[i*(NUM_FEATURES/MUL_PER_FEATURE)  +: (NUM_FEATURES/MUL_PER_FEATURE)] ),
            .weights_in  ( weights_in[i*(NUM_FEATURES/MUL_PER_FEATURE)  +: (NUM_FEATURES/MUL_PER_FEATURE)]  ),
            .acc         ( acc[i] ),
            .ai          ( ai[i]  )
        );
    end
    

    
endmodule
