`timescale 1ns / 1ps

module tb_accumulator;
    localparam int ACC_PRECISION = 32;
    localparam int MUL_PER_FEATURE = 3;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic signed [ACC_PRECISION-1:0] data_in_A [MUL_PER_FEATURE-1:0];
    logic signed [ACC_PRECISION-1:0] data_in_B [MUL_PER_FEATURE-1:0];
    logic signed [ACC_PRECISION-1:0] data_out_A;
    logic signed [ACC_PRECISION-1:0] data_out_B;

    accumulator #(
        .ACC_PRECISION(ACC_PRECISION),
        .MUL_PER_FEATURE(MUL_PER_FEATURE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .ce(ce),
        .data_in_A(data_in_A),
        .data_in_B(data_in_B),
        .data_out_A(data_out_A),
        .data_out_B(data_out_B)
    );

    always #5 clk = ~clk;

    initial begin
        data_in_A = '{32'sd100, -32'sd20, 32'sd5};
        data_in_B = '{32'sd1, 32'sd2, 32'sd3};

        @(posedge clk);
        rst <= 1'b0;
        ce <= 1'b1;

        @(posedge clk);
        #1;
        if (data_out_A !== 32'sd85 || data_out_B !== 32'sd6) begin
            $fatal(1, "accumulator mismatch: A=%0d B=%0d", data_out_A, data_out_B);
        end

        $display("PASS tb_accumulator");
        $finish;
    end
endmodule
