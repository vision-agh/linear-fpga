`timescale 1ns / 1ps

module vector_multiplier_generator #(
    parameter int NP = 4,
    parameter int REG_DEPTH = 8,
    parameter int Q = 4
) (
    input  logic clk,
    input  logic rst,
    input  logic ce,
    input  logic [Q-1:0][NP-1:0][REG_DEPTH-1:0] features_in,
    input  logic [Q-1:0][NP-1:0][REG_DEPTH-1:0] weights_in,
    output logic [Q-1:0][31:0] acc,
    output logic [Q-1:0][31:0] ai
);
    
    genvar i;
    
    for(i=0; i<Q; i++) begin
        vector_multiplier #(
            .REG_DEPTH(REG_DEPTH),
            .NP(NP)
        ) u_vector_multiplier (
            .clk         ( clk ),
            .rst         ( rst ),
            .ce          ( ce  ),
            .features_in ( features_in[i] ),
            .weights_in  ( weights_in[i]  ),
            .acc         ( acc[i] ),
            .ai          ( ai[i]  )
        );
    end
    
endmodule
