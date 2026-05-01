`timescale 1ns / 1ps

module delay_buffer_1d #(
    parameter N            = 4,
    parameter PRECISION    = 4,
    parameter DELAY        = 1
)(
    input          clk,
    input  [PRECISION-1:0] idata [N-1:0],
    output [PRECISION-1:0] odata [N-1:0]
);
    parameter int I_DELAY = DELAY + 1;
    logic [PRECISION-1:0] r_idata [I_DELAY-1:0][N-1:0];
    
    always_ff @(posedge clk) begin
        for (int col = 0; col < N; col++) begin
            r_idata[0][col] <= idata[col];
        end
        for (int delay_idx = 1; delay_idx < I_DELAY; delay_idx++) begin
            for (int col = 0; col < N; col++) begin
                r_idata[delay_idx][col] <= r_idata[delay_idx-1][col];
            end
        end
    end 
    
    generate
        genvar out_idx;
        for (out_idx = 0; out_idx < N; out_idx++) begin : gen_odata_assign
            assign odata[out_idx] = r_idata[I_DELAY-1][out_idx];
        end
    endgenerate
    
endmodule
