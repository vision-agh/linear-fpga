`timescale 1ns / 1ps

module tb_multiplier_top;

    localparam int PRECISION       = 8;
    localparam int BIAS_PRECISION  = 32;
    localparam int NUM_FEATURES    = 2;
    localparam int MUL_PER_FEATURE = 16;
    localparam int N         = 16;
    localparam int M_MUL     = 16;
    localparam int Z_WEIGHTS = 16;


    logic clk;
    logic rst;
    logic ce;

    logic [BIAS_PRECISION-1:0] bias;
    logic [NUM_FEATURES-1:0][N-1:0][PRECISION-1:0] weights_in;
    logic [NUM_FEATURES-1:0][N-1:0][PRECISION-1:0] features;
    logic [NUM_FEATURES-1:0][PRECISION-1:0] out;

    // DUT
    multiplier_top #(
        .PRECISION              ( PRECISION ),
        .BIAS_PRECISION         ( BIAS_PRECISION ),
        .OUTPUT_STAGE_PRECISION ( 64 ),
        .NUM_FEATURES           ( NUM_FEATURES ),
        .MUL_PER_FEATURE        ( 8 ),
        .N                      ( N ),
        .M_MUL                  ( 2094967296 ),
        .Z_WEIGHTS              ( 5 )
    ) dut (
        .clk        ( clk ),
        .rst        ( rst ),
        .ce         ( ce ),
        .bias       ( bias ),
        .weights_in ( weights_in ),
        .features   ( features ),
        .out        ( out )
    );


    // Clock
    always #5 clk = ~clk;

    initial begin
        clk       = 0;
        rst       = 1;
        ce        = 0;
        bias      = 32'd10;
        
        weights_in <= 0;

        features <= 0;

        @(posedge clk);
        rst <= 0;
        ce  <= 1;

        @(posedge clk);
        
        weights_in <= '{
            '{ 8'h01,8'h02,8'h03,8'h04,8'h05,8'h06,8'h07,8'h08,8'h01,8'h02,8'h03,8'h04,8'h05,8'h06,8'h07,8'h08 },
            '{ 8'h08,8'h07,8'h06,8'h05,8'h04,8'h03,8'h02,8'h01,8'h08,8'h07,8'h06,8'h05,8'h04,8'h03,8'h02,8'h01 }
        };
        
        features <= '{
            '{ 8'h01,8'h01,8'h01,8'h01,8'h01,8'h01,8'h01,8'h01, 8'h01,8'h01,8'h01,8'h01,8'h01,8'h01,8'h01,8'h01 },
            '{ 8'h02,8'h02,8'h02,8'h02,8'h02,8'h02,8'h02,8'h02, 8'h02,8'h02,8'h02,8'h02,8'h02,8'h02,8'h02,8'h02 }
        };
        
        @(posedge clk);
        
        weights_in <= '{
            '{ 8'h10, 8'h20, 8'h30, 8'h40, 8'h50, 8'h60, 8'h70, 8'h80, 8'h90, 8'hA0, 8'hB0, 8'hC0, 8'hD0, 8'hE0, 8'hF0, 8'h01 },
            '{ 8'hFF, 8'hEE, 8'hDD, 8'hCC, 8'hBB, 8'hAA, 8'h99, 8'h88, 8'h77, 8'h66, 8'h55, 8'h44, 8'h33, 8'h22, 8'h11, 8'h00 }
        };
        
        features <= '{
            '{ 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05, 8'h05 },
            '{ 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A, 8'h0A }
        };
        
        @(posedge clk);

    end

endmodule
