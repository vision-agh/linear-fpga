`timescale 1ns / 1ps

module vector_multiplier #(
    parameter int REG_DEPTH = 8,
    parameter int NP        = 1      
) (
    input  logic                         clk,
    input  logic                         rst,
    input  logic                         ce, //Przemyśleć
    input  logic [NP-1:0][REG_DEPTH-1:0] features_in,  
    input  logic [NP-1:0][REG_DEPTH-1:0] weights_in,    
    output logic [31:0]                  acc,
    output logic [31:0]                  ai
);
    
    logic [NP-1:0][REG_DEPTH-1:0] r_features_in;
    logic [NP-1:0][REG_DEPTH-1:0] r_weights_in;

    logic [31:0] r_acc;
    logic [31:0] r_ai; 
    
    logic [31:0] n_acc;
    logic [31:0] n_ai;
    
    always_ff @ (posedge clk) begin
        if(rst) begin
            r_features_in  <= 0;
            r_weights_in   <= 0;
        end
        else begin
            r_features_in  <= features_in;
            r_weights_in   <= weights_in;
        end
    end
        
    always_comb begin
        if(ce) begin
            n_acc = 0;
            n_ai  = 0;
            for(int i=0; i<NP; i++) begin
                n_acc += r_features_in[i] * r_weights_in[i];
                n_ai  += r_features_in[i];
            end
        end
        else begin
            n_acc <= n_acc;
            n_ai  <= n_ai;
        end
    end
    
    assign acc = n_ai;
    assign ai  = n_acc;

endmodule
