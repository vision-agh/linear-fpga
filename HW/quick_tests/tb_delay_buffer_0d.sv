`timescale 1ns / 1ps

module tb_delay_buffer_0d;
    logic clk = 1'b0;
    logic [7:0] idata;
    logic [7:0] odata;

    delay_buffer_0d #(
        .PRECISION(8),
        .DELAY(2)
    ) dut (
        .clk(clk),
        .idata(idata),
        .odata(odata)
    );

    always #5 clk = ~clk;

    initial begin
        idata = 8'd11;
        @(posedge clk);
        idata <= 8'd22;
        @(posedge clk);
        idata <= 8'd33;
        @(posedge clk);
        #1;
        if (odata !== 8'd11) begin
            $fatal(1, "delay_buffer_0d mismatch after 3 clocks: out=%0d", odata);
        end
        @(posedge clk);
        #1;
        if (odata !== 8'd22) begin
            $fatal(1, "delay_buffer_0d mismatch after 4 clocks: out=%0d", odata);
        end

        $display("PASS tb_delay_buffer_0d");
        $finish;
    end
endmodule
