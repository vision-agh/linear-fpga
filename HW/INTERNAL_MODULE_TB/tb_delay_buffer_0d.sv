`timescale 1ns / 1ps

module tb_delay_buffer_0d;

    localparam int PRECISION = 8;
    localparam int DELAY     = 0;

    logic                 clk = 0;
    logic [PRECISION-1:0] idata;
    logic [PRECISION-1:0] odata;

    delay_buffer_0d #(
        .PRECISION ( PRECISION ),
        .DELAY     ( DELAY     )
    ) dut (
        .clk       ( clk       ),
        .idata     ( idata     ),
        .odata     ( odata     )
    );

    always #5 clk = ~clk;

    initial begin
        @(posedge clk);
        idata <= 8'd10; @(posedge clk);
        idata <= 8'd20; @(posedge clk);
        idata <= 8'd30; @(posedge clk);
        idata <= 8'd40; @(posedge clk);
        idata <= 8'd50; @(posedge clk);

        repeat (DELAY + 2) @(posedge clk);

        $finish;
    end

endmodule