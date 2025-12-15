`timescale 1ns / 1ps

module tb_burst_buffer;
    localparam int INITIAL_LATENCY = 3;
    localparam int M               = 5;
    localparam int PRECISION       = 5;

    logic                        clk;
    logic                        rst;
    logic                        ce;
    logic [PRECISION-1:0]        data_in;
    logic [M-1:0][PRECISION-1:0] data_out;
    logic                        out_ready;

    burst_buffer #(
        .INITIAL_LATENCY ( INITIAL_LATENCY ),
        .M               ( M ),
        .PRECISION       ( PRECISION )
    ) dut (
        .clk       ( clk ),
        .rst       ( rst ),
        .ce        ( ce ),
        .data_in   ( data_in ),
        .data_out  ( data_out ),
        .out_ready ( out_ready )
    );


    always #5 clk = ~clk;

    initial begin
        clk     = 0;
        rst     = 1;
        ce      = 1;
        data_in = 0;

        repeat (2) @(posedge clk);
        rst = 0;

        // ===============================
        // LATENCY phase (3 cykle)
        // ===============================
        @(posedge clk); data_in <= 5'd1;
        @(posedge clk); data_in <= 5'd2;
        @(posedge clk); data_in <= 5'd3;

        // ===============================
        // BUFFERING phase (M = 5 próbek)
        // ===============================
        @(posedge clk); data_in <= 5'd10;
        @(posedge clk); data_in <= 5'd11;
        @(posedge clk); data_in <= 5'd12;
        @(posedge clk); data_in <= 5'd13;
        @(posedge clk); data_in <= 5'd14;
        // ===============================
        // BUFFERING phase (M = 5 próbek)
        // ===============================
        @(posedge clk); data_in <= 5'd20;
        @(posedge clk); data_in <= 5'd21;
        @(posedge clk); data_in <= 5'd22;
        @(posedge clk); data_in <= 5'd23;
        @(posedge clk); data_in <= 5'd24;
        // ===============================
        // BUFFERING phase (M = 5 próbek)
        // ===============================
        @(posedge clk); data_in <= 5'd14;
        @(posedge clk); data_in <= 5'd12;
        @(posedge clk); data_in <= 5'd25;
        @(posedge clk); data_in <= 5'd23;
        @(posedge clk); data_in <= 5'd14;
        // ===============================
        // BUFFERING phase (M = 5 próbek)
        // ===============================      
        @(posedge clk); data_in <= 5'd4;
        @(posedge clk); data_in <= 5'd1;
        @(posedge clk); data_in <= 5'd7;
        @(posedge clk); data_in <= 5'd3;
        @(posedge clk); data_in <= 5'd2;

       
        #20;
        $finish;
    end

endmodule
