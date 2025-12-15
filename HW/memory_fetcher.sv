`timescale 1ns / 1ps

module memory_fetcher #(
    parameter int BRAM_WIDTH = 3,
    parameter int M = 5,
    parameter int N = 5,
    parameter int BIAS_PRECISION = 32,
    parameter int PRECISION = 5
) (
    input  logic                        clk,
    input  logic                        rst,
    input  logic                        ce,
    output logic [N-1:0][PRECISION-1:0] data_out,
    output logic [BIAS_PRECISION-1:0]   bias,
    output logic                        in_ready // temporary signal
);
    
     memory_weights #(
        .DATA_WIDTH ( BRAM_WIDTH ),
        .ADDR_DEPTH ( M )
    ) u_memory_weights (
        .clk        ( clk ),
        .ce         ( ce ),
        .addr       ( line_counter ),
        .dout       ( mem_data_out )
    );
    
   logic [$clog2(M)-1 : 0]  line_counter;
   logic [BRAM_WIDTH-1 : 0] mem_data_out;
    
    always_ff @ (posedge clk) begin
        if (rst) begin
            line_counter <= 0;
        end else begin
            if (ce) begin
                if (line_counter < M-1) begin
                    line_counter <= line_counter + 1;                       
                end else begin
                    line_counter <= 0;
                end  
                
                in_ready <= (line_counter == 0) ? 1 : 0;
                             
                for(int i=N-1; i>=0; i--) begin
                    data_out[i] = mem_data_out[i<<(3)+:PRECISION]; //to do -> parallel memory interface to read multiple weights lines 
                end
                
                bias = mem_data_out[N<<(3)+:BIAS_PRECISION];
            end
        end
    end
                         
    
endmodule
