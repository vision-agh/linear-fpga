`timescale 1ns / 1ps

module tb_top_module;

    localparam int PRECISION        = 8;
    localparam int BIAS_PRECISION   = 32;
    localparam int NUM_FEATURES     = 2;
    localparam int MUL_PER_FEATURE  = 4;
    localparam int N                = 4;
    localparam int M                = 4;

    logic clk;
    logic rst;
    logic ce;

    logic in_valid;
    logic in_ready;
    logic out_valid;
    logic out_ready;

    logic [PRECISION-1:0] features [NUM_FEATURES-1:0][N-1:0];
    logic [PRECISION-1:0] out      [NUM_FEATURES-1:0][N-1:0];

    top_module #(
        .PRECISION       ( PRECISION       ),
        .BIAS_PRECISION  ( BIAS_PRECISION  ),
        .NUM_FEATURES    ( NUM_FEATURES    ),
        .MUL_PER_FEATURE ( MUL_PER_FEATURE ),
        .N               ( N               ),
        .M               ( M               )
    ) dut (
        .clk             ( clk             ),
        .rst             ( rst             ),
        .ce              ( ce              ),
        .in_valid        ( in_valid        ),
        .in_ready        ( in_ready        ),
        .out_valid       ( out_valid       ),
        .out_ready       ( out_ready       ),
        .features        ( features        ),
        .out             ( out             )
    );

    always #5 clk = ~clk;

    initial begin
        clk       = 0;
        rst       = 1;
        ce        = 0;
        in_valid  = 0;
        out_ready = 0;

        repeat (3) @(posedge clk);
        rst <= 0;
        ce  <= 1;

        features[0] = '{4, 1, 5, 6};
        features[1] = '{6, 1, 2, 3};

        @(posedge clk);
        in_valid <= 1;
        while (!in_ready) @(posedge clk);
        @(posedge clk);
        in_valid <= 0;

        out_ready <= 1;
        while (!out_valid) @(posedge clk);
        @(posedge clk);
        out_ready <= 0;

        features[0] = '{4, 3, 2, 1};
        features[1] = '{1, 2, 3, 4};

        @(posedge clk);
        in_valid <= 1;
        while (!in_ready) @(posedge clk);
        @(posedge clk);
        in_valid <= 0;

        out_ready <= 1;
        while (!out_valid) @(posedge clk);
        @(posedge clk);
        out_ready <= 0;

        features[0] = '{2, 3, 1, 2};
        features[1] = '{7, 5, 2, 3};

        @(posedge clk);
        in_valid <= 1;
        while (!in_ready) @(posedge clk);
        @(posedge clk);
        in_valid <= 0;

        out_ready <= 1;
        while (!out_valid) @(posedge clk);
        @(posedge clk);
        out_ready <= 0;

        repeat (5) @(posedge clk);
        $finish;
    end

endmodule