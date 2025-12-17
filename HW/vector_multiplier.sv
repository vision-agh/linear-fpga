`timescale 1ns / 1ps

module vector_multiplier #(
    parameter int PRECISION      = 8,
    parameter int NUM_FEATURES   = 1,
    parameter int BIAS_PRECISION = 32    
) (
    input  logic                 clk,
    input  logic                 rst,
    input  logic                 ce,
    input  logic [PRECISION-1:0] features_in [NUM_FEATURES-1:0],  
    input  logic [PRECISION-1:0] weights_in  [NUM_FEATURES-1:0],    
    output logic [BIAS_PRECISION-1:0]                acc,
    output logic [BIAS_PRECISION-1:0]                ai
);

    logic [BIAS_PRECISION-1:0] r_acc;
    logic [BIAS_PRECISION-1:0] r_ai; 
    
    logic [BIAS_PRECISION-1:0] n_acc;
    logic [BIAS_PRECISION-1:0] n_ai;
    
    always_ff @ (posedge clk) begin
        if(rst) begin
            acc  <= 0;
            ai   <= 0;
        end
        else begin
            acc  <= n_acc;
            ai   <= n_ai;
        end
    end
        
    always_comb begin
        if(ce) begin
            n_acc = 0;
            n_ai  = 0;
            for(int i=0; i<NUM_FEATURES; i++) begin
                n_acc += features_in[i] * weights_in[i];
                n_ai  += features_in[i];
            end
        end
        else begin
            n_acc = n_acc;
            n_ai  = n_ai;
        end
    end


endmodule
