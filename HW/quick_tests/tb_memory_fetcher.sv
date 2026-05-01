`timescale 1ns / 1ps

module tb_memory_fetcher;
    localparam int BRAM_WIDTH = 64;
    localparam int M = 2;
    localparam int N = 4;
    localparam int BIAS_PRECISION = 32;
    localparam int WEIGHT_PRECISION = 8;

    logic clk = 1'b0;
    logic clr = 1'b1;
    logic ce = 1'b0;
    logic [WEIGHT_PRECISION-1:0] data_out [N-1:0];
    logic signed [BIAS_PRECISION-1:0] bias;

    memory_fetcher #(
        .BRAM_WIDTH(BRAM_WIDTH),
        .M(M),
        .N(N),
        .BIAS_PRECISION(BIAS_PRECISION),
        .WEIGHT_PRECISION(WEIGHT_PRECISION),
        .MEMORY_FILE("quick_tests/weights_small.mem")
    ) dut (
        .clk(clk),
        .clr(clr),
        .ce(ce),
        .data_out(data_out),
        .bias(bias)
    );

    always #5 clk = ~clk;

    task check_row(
        input integer expected_bias,
        input integer w0,
        input integer w1,
        input integer w2,
        input integer w3
    );
        begin
            #1;
            if (bias !== expected_bias ||
                data_out[0] !== w0 || data_out[1] !== w1 ||
                data_out[2] !== w2 || data_out[3] !== w3) begin
                $fatal(
                    1,
                    "memory_fetcher mismatch: bias=%0d weights={%0d,%0d,%0d,%0d}",
                    bias, data_out[0], data_out[1], data_out[2], data_out[3]
                );
            end
        end
    endtask

    initial begin
        @(posedge clk);
        clr <= 1'b0;
        ce <= 1'b1;

        @(posedge clk);
        @(posedge clk);
        check_row(7, 129, 126, 131, 124);

        @(posedge clk);
        check_row(-8, 132, 133, 134, 135);

        $display("PASS tb_memory_fetcher");
        $finish;
    end
endmodule
