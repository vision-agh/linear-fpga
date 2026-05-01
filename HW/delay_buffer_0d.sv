`timescale 1ns / 1ps

module delay_buffer_0d #(
    parameter PRECISION = 4,
    parameter DELAY     = 2
)(
    input          clk,
    input  [PRECISION-1:0] idata,
    output [PRECISION-1:0] odata
);
    parameter int I_DELAY = DELAY + 1;
    logic [PRECISION-1:0] r_idata [I_DELAY-1:0];

    always_ff @(posedge clk) begin
        r_idata[0] <= idata;
        for (int i = 1; i < I_DELAY; i++) begin
            r_idata[i] <= r_idata[i-1];
        end
    end 
    
    assign odata = r_idata[I_DELAY-1];
    
endmodule
