`timescale 1ns / 1ps

module serial_memory_fetcher #(
    parameter int BRAM_WIDTH     = 3,
    parameter int TEMP           = 2,
    parameter int M              = 5,
    parameter int N              = 5,
    parameter int BIAS_PRECISION = 32,
    parameter int PRECISION      = 5
) (
    input  logic                      clk,
    input  logic                      clr,
    input  logic                      ce,
    output logic [PRECISION-1:0]      data_out [N/(TEMP)-1:0],
    output logic [BIAS_PRECISION-1:0] bias
);
    
     memory_weights #(
        .DATA_WIDTH ( BRAM_WIDTH  ),
        .ADDR_DEPTH ( M*(TEMP) )
    ) u_memory_weights (
        .clk  ( clk          ),
        .ce   ( ce           ),
        .addr ( line_counter ),
        .dout ( mem_data_out )
    );
    
   logic [$clog2(M*(-TEMP)):0]  line_counter;
   logic [BRAM_WIDTH-1:0] mem_data_out;
   
   logic [PRECISION-1:0]      r_data_out [N/(TEMP)-1:0];
   logic [BIAS_PRECISION-1:0] r_bias;
   
   logic [PRECISION-1:0]      n_data_out [N/(TEMP)-1:0];
   logic [BIAS_PRECISION-1:0] n_bias;
    
    always_ff @ (posedge clk) begin
        if (clr) begin
            line_counter <= 0;
        end else begin
            if (ce) begin
                if (line_counter < M*(TEMP)-1) begin
                    line_counter <= line_counter + 1;                       
                end else begin
                    line_counter <= 0;
                end               
            end
        end
    end
    
    always_ff @ (posedge clk) begin
        if (clr) begin
            r_data_out     <= '{default:0};
            r_bias         <= 0;
        end else begin
            if (ce) begin
               r_data_out <= n_data_out;
               r_bias     <= n_bias;
            end
        end
    end
    
    always_comb begin
        if (clr) begin
            n_data_out     = '{default:0};
            n_bias         = 0;
        end else begin
            if (ce) begin         
                for(int i=N/(TEMP)-1; i>=0; i--) begin
                    n_data_out[i] = mem_data_out[i<<(3)+:PRECISION]; 
                end              
                n_bias = mem_data_out[(N/(TEMP))<<(3)+:BIAS_PRECISION];
            end
        end
    end
    
    assign data_out = r_data_out;
    assign bias     = r_bias;
                         
    
endmodule
