`timescale 1ns / 1ps

module tb_delay_buffer_2d;

    parameter int NUM_FEATURES = 4;
    parameter int N            = 4;
    parameter int PRECISION    = 4;
    parameter int DELAY        = 0;

    logic                 clk;
    logic [PRECISION-1:0] idata [NUM_FEATURES-1:0][N-1:0];
    logic [PRECISION-1:0] odata [NUM_FEATURES-1:0][N-1:0];

    delay_buffer_2d #(
        .NUM_FEATURES ( NUM_FEATURES ),
        .N            ( N            ),
        .PRECISION    ( PRECISION    ),
        .DELAY        ( DELAY        )
    ) uut (
        .clk          ( clk          ),
        .idata        ( idata        ),
        .odata        ( odata        )
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        @(posedge clk);
        idata = '{'{1, 2, 3, 4}, '{5, 6, 7, 8}, '{9, 10, 11, 12}, '{13, 14, 15, 0}};
        @(posedge clk);
        idata = '{'{2, 3, 4, 5}, '{6, 7, 8, 9}, '{10, 11, 12, 13}, '{14, 15, 0, 1}};
        @(posedge clk);
        idata = '{'{3, 4, 5, 6}, '{7, 8, 9, 10}, '{11, 12, 13, 14}, '{15, 0, 1, 2}};
        @(posedge clk);
        idata = '{'{4, 5, 6, 7}, '{8, 9, 10, 11}, '{12, 13, 14, 15}, '{0, 1, 2, 3}};
        @(posedge clk);

        $finish;
    end


endmodule