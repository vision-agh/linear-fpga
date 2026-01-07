`timescale 1ns / 1ps

module parallel_memory_fetcher #(
    parameter int BRAM_WIDTH     = 64,
    parameter int TEMP           = 2,
    parameter int M              = 5,
    parameter int N              = 4,
    parameter int BIAS_PRECISION = 32,
    parameter int PRECISION      = 5
) (
    input  logic                      clk,
    input  logic                      clr,
    input  logic                      ce,
    output logic [PRECISION-1:0]      data_out [TEMP-1:0][N-1:0],
    output logic [BIAS_PRECISION-1:0] bias [TEMP-1:0]
);
    logic [BRAM_WIDTH-1:0] mem_data_out [TEMP-1:0];
    logic [BRAM_WIDTH-1:0] addr         [TEMP-1:0] = '{default:0};
    
    localparam logic unsigned [$clog2(M/TEMP)+1:0] SECTION_LENGTH = M/TEMP; 
    
    genvar i;
    for(i=0; i<TEMP; i++) begin
     memory_weights #(
        .DATA_WIDTH ( BRAM_WIDTH ),
        .ADDR_DEPTH ( M          )
    ) u_memory_weights (
        .clk  ( clk             ),
        .ce   ( ce              ),
        .addr ( addr[i]         ),
        .dout ( mem_data_out[i] )
    );
    end
   
   logic [$clog2(M)-1:0]      line_counter;
   
   logic [PRECISION-1:0]      r_data_out [TEMP-1:0][N-1:0];
   logic [BIAS_PRECISION-1:0] r_bias     [TEMP-1:0];
   
   logic [PRECISION-1:0]      n_data_out [TEMP-1:0][N-1:0];
   logic [BIAS_PRECISION-1:0] n_bias     [TEMP-1:0];
    
   always_ff @ (posedge clk) begin
        if (clr) begin
            line_counter <= 0;
        end else begin
            if (ce) begin
                if (line_counter < M/TEMP - 1) begin
                    line_counter <= line_counter + 1;                       
                end else begin
                    line_counter <= 0;
                end               
            end
        end
   end
    
    always_comb begin
        if (clr) begin
            for(int i=0; i<TEMP; i++) begin
                addr[i] = 0 + SECTION_LENGTH*i;
            end 
        end else begin
            for(int i=0; i<TEMP; i++) begin
                addr[i] = line_counter + SECTION_LENGTH*i;
            end
        end
    end
    
    always_ff @ (posedge clk) begin
        if (clr) begin
            r_data_out     <= '{default:0};
            r_bias         <= '{default:0};
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
            n_bias         = '{default:0};
        end else begin
            if (ce) begin
                for(int j=0; j<TEMP; j++) begin   
                    for(int i=N-1; i>=0; i--) begin
                        n_data_out[j][i] = mem_data_out[j][i<<(3)+:PRECISION]; 
                    end              
                    n_bias[j] = mem_data_out[j][(N)<<(3)+:BIAS_PRECISION];
                end
            end
        end
    end
    
    assign data_out = r_data_out;
    assign bias     = r_bias;
                         
    
endmodule
