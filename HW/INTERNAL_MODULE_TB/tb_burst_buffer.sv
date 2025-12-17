`timescale 1ns / 1ps

module tb_burst_buffer;

    localparam int INITIAL_LATENCY = 3;
    localparam int M               = 5;
    localparam int PRECISION       = 5;

    logic                 clk;
    logic                 clr;
    logic                 ce;
    logic [PRECISION-1:0] data_in;
    logic [PRECISION-1:0] data_out [M-1:0];
    logic                 out_valid;

    burst_buffer #(
        .INITIAL_LATENCY ( INITIAL_LATENCY ),
        .M               ( M               ),
        .PRECISION       ( PRECISION       )
    ) dut (
        .clk             ( clk             ),
        .clr             ( clr             ),
        .ce              ( ce              ),
        .data_in         ( data_in         ),
        .data_out        ( data_out        ),
        .out_valid       ( out_valid       )
    );

    always #5 clk = ~clk;

    initial begin
        repeat (1) @(posedge clk);
        @(posedge clk); data_in <= 5'd1;
        @(posedge clk); data_in <= 5'd2;
        @(posedge clk); data_in <= 5'd3;
        @(posedge clk); data_in <= 5'd10;
        @(posedge clk); data_in <= 5'd11;
        @(posedge clk); data_in <= 5'd12;
        @(posedge clk); data_in <= 5'd13;
        @(posedge clk); data_in <= 5'd14;
        @(posedge clk); data_in <= 5'd20;
        @(posedge clk); data_in <= 5'd21;
        @(posedge clk); data_in <= 5'd22;
        @(posedge clk); data_in <= 5'd23;
        @(posedge clk); data_in <= 5'd24;
        @(posedge clk); data_in <= 5'd20;
        @(posedge clk); data_in <= 5'd21;
        @(posedge clk); data_in <= 5'd22;
        @(posedge clk); data_in <= 5'd23;
        @(posedge clk); data_in <= 5'd24;
        @(posedge clk); data_in <= 5'd14;
        @(posedge clk); data_in <= 5'd12;
        @(posedge clk); data_in <= 5'd25;
        @(posedge clk); data_in <= 5'd23;
        @(posedge clk); data_in <= 5'd14;
        @(posedge clk); data_in <= 5'd20;
        @(posedge clk); data_in <= 5'd3;
        @(posedge clk); data_in <= 5'd10;
        @(posedge clk); data_in <= 5'd12;
        @(posedge clk); data_in <= 5'd13;
        @(posedge clk); data_in <= 5'd22;
        @(posedge clk); data_in <= 5'd23;
        @(posedge clk); data_in <= 5'd24;
        @(posedge clk); data_in <= 5'd20;
        @(posedge clk); data_in <= 5'd21;
        @(posedge clk); data_in <= 5'd3;
        @(posedge clk); data_in <= 5'd10;
    end

    initial begin
        clk     = 0;
        clr     = 1;
        ce      = 1;
        data_in = 0;

        repeat (2) @(posedge clk);
        clr = 0;
        
        repeat (12) @(posedge clk);
        clr = 1;
        @(posedge clk);
        clr = 0;

        repeat (15) @(posedge clk);
        clr = 1;
        @(posedge clk);
        clr = 0;
        
        repeat (11) @(posedge clk);
        clr = 1;
        @(posedge clk);
        clr = 0;
       
        #20;
        $finish;
    end

endmodule