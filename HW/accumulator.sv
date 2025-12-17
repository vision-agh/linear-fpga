`timescale 1ns / 1ps

module accumulator #(
    parameter int BIAS_PRECISION  = 32,   
    parameter int MUL_PER_FEATURE = 1   
) (
    input  logic clk,
    input  logic rst,
    input  logic ce,
    input  logic [BIAS_PRECISION-1:0] data_in_A [MUL_PER_FEATURE],  
    input  logic [BIAS_PRECISION-1:0] data_in_B [MUL_PER_FEATURE],     
    output logic [BIAS_PRECISION-1:0] data_out_A,
    output logic [BIAS_PRECISION-1:0] data_out_B
);

    logic [BIAS_PRECISION-1:0] n_data_out_A;
    logic [BIAS_PRECISION-1:0] n_data_out_B;

    always_ff @(posedge clk) begin 
        if (rst) begin
            data_out_A <= 0; 
            data_out_B <= 0; 
        end else begin
            data_out_A <= n_data_out_A;
            data_out_B <= n_data_out_B;
        end
    end
    
    always_comb begin
        if(ce) begin
            n_data_out_A = 0;
            n_data_out_B = 0;
            for(int i=0; i<MUL_PER_FEATURE; i++) begin
                n_data_out_A += data_in_A[i];
                n_data_out_B += data_in_B[i];
            end
        end
        else begin
              n_data_out_A <= n_data_out_A;
              n_data_out_B <= n_data_out_B;
        end
    end
        

endmodule
