`timescale 1ns / 1ps

module tb_burst_buffer;
    logic clk = 1'b0;
    logic clr = 1'b1;
    logic ce = 1'b0;
    logic [7:0] data_in;
    logic [7:0] data_out [3:0];
    logic burst_complete;

    burst_buffer #(
        .INITIAL_LATENCY(2),
        .M(4),
        .PRECISION(8)
    ) dut (
        .clk(clk),
        .clr(clr),
        .ce(ce),
        .data_in(data_in),
        .data_out(data_out),
        .burst_complete(burst_complete)
    );

    always #5 clk = ~clk;

    initial begin
        data_in = 8'd0;
        @(posedge clk);
        clr <= 1'b0;
        ce <= 1'b1;

        repeat (2) @(posedge clk);
        data_in <= 8'd11;
        @(posedge clk);
        data_in <= 8'd22;
        @(posedge clk);
        data_in <= 8'd33;
        @(posedge clk);
        data_in <= 8'd44;
        @(posedge clk);
        @(posedge clk);
        #1;

        if (!burst_complete ||
            data_out[0] !== 8'd11 || data_out[1] !== 8'd22 ||
            data_out[2] !== 8'd33 || data_out[3] !== 8'd44) begin
            $fatal(
                1,
                "burst_buffer mismatch: done=%0d out={%0d,%0d,%0d,%0d}",
                burst_complete, data_out[0], data_out[1], data_out[2], data_out[3]
            );
        end

        $display("PASS tb_burst_buffer");
        $finish;
    end
endmodule
