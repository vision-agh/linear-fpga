`timescale 1ns / 1ps

module tb_delay_buffer_2d;
    logic clk = 1'b0;
    logic [7:0] idata [1:0][2:0];
    logic [7:0] odata [1:0][2:0];

    delay_buffer_2d #(
        .NUM_FEATURES(2),
        .N(3),
        .PRECISION(8),
        .DELAY(1)
    ) dut (
        .clk(clk),
        .idata(idata),
        .odata(odata)
    );

    always #5 clk = ~clk;

    initial begin
        idata[0][0] = 8'd1;
        idata[0][1] = 8'd2;
        idata[0][2] = 8'd3;
        idata[1][0] = 8'd4;
        idata[1][1] = 8'd5;
        idata[1][2] = 8'd6;
        @(posedge clk);
        idata[0][0] <= 8'd7;
        idata[0][1] <= 8'd8;
        idata[0][2] <= 8'd9;
        idata[1][0] <= 8'd10;
        idata[1][1] <= 8'd11;
        idata[1][2] <= 8'd12;
        @(posedge clk);
        #1;
        if (odata[0][0] !== 8'd1 || odata[0][2] !== 8'd3 || odata[1][1] !== 8'd5) begin
            $fatal(1, "delay_buffer_2d mismatch: got %0d %0d %0d", odata[0][0], odata[0][2], odata[1][1]);
        end

        $display("PASS tb_delay_buffer_2d");
        $finish;
    end
endmodule
