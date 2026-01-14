`timescale 1ns / 1ps
    

module output_stage #(
    parameter int PRECISION      = 8,
    parameter int Z_WEIGHTS      = 5,
    parameter int M_MUL          = 2094967296,
    parameter int BIAS_PRECISION = 32,  
    parameter int OUTPUT_STAGE_PRECISION  = 64   
) (
    input  logic clk,
    input  logic rst,
    input  logic ce,
    input  logic [BIAS_PRECISION-1:0] ai, 
    input  logic [BIAS_PRECISION-1:0] acc,
    input  logic [BIAS_PRECISION-1:0] bias,  
    output logic [PRECISION-1:0]      out
);

    logic signed [OUTPUT_STAGE_PRECISION-1 : 0] n_out;

    always_ff @(posedge clk) begin 
        if (rst) begin
            out      <= 0; 
        end else begin
            if(n_out < 0) begin
                out      <= 0;
            end else if(n_out > 255) begin
                out      <= 255;
            end else begin
                out      <= n_out[7:0];
            end
        end
    end
    
    always_comb begin
        if(ce) begin
            n_out = ($signed(acc) - $signed(Z_WEIGHTS)*$signed(ai))*$signed(M_MUL);
            n_out = (n_out>>>32);
            n_out = n_out + $signed(bias);
        end
        else begin
            n_out <= n_out;
        end
    end

endmodule
