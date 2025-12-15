`timescale 1ns / 1ps

module tb_memory_fetcher;

    localparam int BRAM_WIDTH     = 64;
    localparam int M              = 6;
    localparam int N              = 4;
    localparam int BIAS_PRECISION = 32;
    localparam int PRECISION      = 8;

    logic                        clk;
    logic                        rst;
    logic                        ce;
    logic [N-1:0][PRECISION-1:0] data_out;
    logic [BIAS_PRECISION-1:0]   bias;
    logic                        in_ready;

    memory_fetcher #(
        .BRAM_WIDTH     ( BRAM_WIDTH ),
        .M              ( M ),
        .N              ( N ),
        .BIAS_PRECISION ( BIAS_PRECISION ),
        .PRECISION      ( PRECISION )
    ) dut (
        .clk      ( clk ),
        .rst      ( rst ),
        .ce       ( ce ),
        .data_out ( data_out ),
        .bias     ( bias ),
        .in_ready ( in_ready )
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        ce  = 0;
        #20;
        rst = 0;
        ce  = 1;
        repeat (20) @(posedge clk);
        $finish;
    end

endmodule
