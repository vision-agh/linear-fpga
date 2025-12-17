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

    logic [PRECISION-1:0] r_idata [I_DELAY-1:0] = '{default:0};
    

    always_ff @(posedge clk) begin
        if(DELAY == 0)
            r_idata[I_DELAY-1] = idata;
        else
            r_idata <= {r_idata[I_DELAY-2:0], idata};
    end 
    
    assign odata = r_idata[I_DELAY-1];
    
endmodule
