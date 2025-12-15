`timescale 1ns / 1ps
    

module output_stage #(
    parameter int PRECISION = 8,
    parameter int Z_WEIGHTS = 5,
    parameter int M_MUL = 2094967296,
    parameter int BIAS_PRECISION    = 32,  
    parameter int OUTPUT_STAGE_PRECISION  = 64   
) (
    input  logic clk,
    input  logic rst,
    input  logic ce,
    input  logic [BIAS_PRECISION   - 1 : 0] ai, 
    input  logic [BIAS_PRECISION   - 1 : 0] acc,
    input  logic [BIAS_PRECISION   - 1 : 0] bias,  
    output logic [8 - 1 : 0] out
);

    logic signed [OUTPUT_STAGE_PRECISION - 1 : 0] n_out;

    always_ff @(posedge clk) begin 
        if (rst) begin
            out <= 0; 
        end else begin
            out <= n_out[7:0];
        end
    end
    
    always_comb begin
        if(ce) begin
            n_out = (acc - Z_WEIGHTS*ai)*M_MUL;
            n_out = (n_out>>>32);
            n_out = n_out + bias;
        end
        else begin
            n_out <= n_out;
        end
    end

endmodule
