`timescale 1ns / 1ps

module tb_top_module;

    localparam int INPUT_PRECISION  = 8;
    localparam int WEIGHT_PRECISION = 8;
    localparam int OUTPUT_PRECISION = 8;
    localparam int ACC_PRECISION    = 32;
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

    logic [INPUT_PRECISION-1:0] features [NUM_FEATURES-1:0][N-1:0];
    logic [OUTPUT_PRECISION-1:0] out [NUM_FEATURES-1:0][M-1:0];

    top_module #(
        .TEMP             ( 1                ),
        .INPUT_PRECISION  ( INPUT_PRECISION  ),
        .WEIGHT_PRECISION ( WEIGHT_PRECISION ),
        .OUTPUT_PRECISION ( OUTPUT_PRECISION ),
        .ACC_PRECISION    ( ACC_PRECISION    ),
        .NUM_FEATURES     ( NUM_FEATURES     ),
        .MUL_PER_FEATURE  ( MUL_PER_FEATURE  ),
        .N                ( N                ),
        .M                ( M                ),
        .IN_ZP            ( 128              ),
        .OUT_ZP           ( 131              ),
        .M_MUL            ( 1616892571       ),
        .M_SHIFT          ( 43               )
    ) dut (
        .clk       ( clk       ),
        .rst       ( rst       ),
        .ce        ( ce        ),
        .in_valid  ( in_valid  ),
        .in_ready  ( in_ready  ),
        .out_valid ( out_valid ),
        .out_ready ( out_ready ),
        .features  ( features  ),
        .out       ( out       )
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        ce = 0;
        in_valid = 0;
        out_ready = 0;

        repeat (3) @(posedge clk);
        rst <= 0;
        ce <= 1;

        features[0] = '{8'd4, 8'd1, 8'd5, 8'd6};
        features[1] = '{8'd6, 8'd1, 8'd2, 8'd3};

        @(posedge clk);
        in_valid <= 1;
        while (!in_ready) @(posedge clk);
        @(posedge clk);
        in_valid <= 0;

        out_ready <= 1;
        while (!out_valid) @(posedge clk);
        @(posedge clk);
        out_ready <= 0;

        features[0] = '{8'd4, 8'd3, 8'd2, 8'd1};
        features[1] = '{8'd1, 8'd2, 8'd3, 8'd4};

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
