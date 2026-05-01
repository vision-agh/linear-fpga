`timescale 1ns / 1ps

module tb_multiplier_top;

    localparam int INPUT_PRECISION  = 8;
    localparam int WEIGHT_PRECISION = 8;
    localparam int OUTPUT_PRECISION = 8;
    localparam int ACC_PRECISION    = 32;
    localparam int NUM_FEATURES     = 2;
    localparam int MUL_PER_FEATURE  = 8;
    localparam int N                = 16;

    logic                                   clk;
    logic                                   rst;
    logic                                   ce;
    logic signed [ACC_PRECISION-1:0]        bias;
    logic [WEIGHT_PRECISION-1:0]            weights_in [N-1:0];
    logic [INPUT_PRECISION-1:0]             features [NUM_FEATURES-1:0][N-1:0];
    logic [OUTPUT_PRECISION-1:0]            out [NUM_FEATURES-1:0];

    multiplier_top #(
        .INPUT_PRECISION        ( INPUT_PRECISION  ),
        .WEIGHT_PRECISION       ( WEIGHT_PRECISION ),
        .OUTPUT_PRECISION       ( OUTPUT_PRECISION ),
        .ACC_PRECISION          ( ACC_PRECISION    ),
        .OUTPUT_STAGE_PRECISION ( 64               ),
        .NUM_FEATURES           ( NUM_FEATURES     ),
        .MUL_PER_FEATURE        ( MUL_PER_FEATURE  ),
        .N                      ( N                ),
        .IN_ZP                  ( 128              ),
        .W_ZP                   ( 128              ),
        .OUT_ZP                 ( 131              ),
        .M_MUL                  ( 1616892571       ),
        .M_SHIFT                ( 43               )
    ) dut (
        .clk        ( clk        ),
        .rst        ( rst        ),
        .ce         ( ce         ),
        .bias       ( bias       ),
        .weights_in ( weights_in ),
        .features   ( features   ),
        .out        ( out        ),
        .corrected_acc_out ( )
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        ce = 0;
        bias = 32'sd10;
        weights_in = '{default:'0};
        features = '{default:'0};

        @(posedge clk);
        rst <= 0;
        ce <= 1;

        @(posedge clk);

        weights_in <= '{8'sd1, 8'sd2, 8'sd3, 8'sd4, 8'sd5, 8'sd6, 8'sd7, 8'sd8,
                        8'sd1, 8'sd2, 8'sd3, 8'sd4, 8'sd5, 8'sd6, 8'sd7, 8'sd8};

        features <= '{
            '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1},
            '{8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2, 8'd2}
        };

        @(posedge clk);

        weights_in <= '{8'sd16, 8'sd32, 8'sd48, 8'sd64, 8'sd80, 8'sd96, 8'sd112, 8'sd127,
                        -8'sd112, -8'sd96, -8'sd80, -8'sd64, -8'sd48, -8'sd32, -8'sd16, 8'sd1};

        features <= '{
            '{8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5},
            '{8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10}
        };

        @(posedge clk);
    end

endmodule
