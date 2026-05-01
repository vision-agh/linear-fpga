`timescale 1ns / 1ps

module tb_output_stage;
    localparam int INPUT_PRECISION = 8;
    localparam int OUTPUT_PRECISION = 8;
    localparam int ACC_PRECISION = 32;
    localparam int OUTPUT_STAGE_PRECISION = 64;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic signed [ACC_PRECISION-1:0] weight_sum;
    logic signed [ACC_PRECISION-1:0] feature_sum;
    logic signed [ACC_PRECISION-1:0] mac_acc;
    logic signed [ACC_PRECISION-1:0] bias;
    logic signed [OUTPUT_STAGE_PRECISION-1:0] corrected_acc_in;
    logic signed [OUTPUT_STAGE_PRECISION-1:0] corrected_acc_out;
    logic [OUTPUT_PRECISION-1:0] out;

    output_stage #(
        .INPUT_PRECISION(INPUT_PRECISION),
        .OUTPUT_PRECISION(OUTPUT_PRECISION),
        .ACC_PRECISION(ACC_PRECISION),
        .OUTPUT_STAGE_PRECISION(OUTPUT_STAGE_PRECISION),
        .IN_ZP(8),
        .W_ZP(0),
        .N(4),
        .OUT_ZP(10),
        .M_MUL(16),
        .M_SHIFT(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .ce(ce),
        .weight_sum(weight_sum),
        .feature_sum(feature_sum),
        .mac_acc(mac_acc),
        .bias(bias),
        .corrected_acc_in(corrected_acc_in),
        .corrected_acc_out(corrected_acc_out),
        .out(out)
    );

    always #5 clk = ~clk;

    initial begin
        weight_sum = 32'sd2;
        feature_sum = 32'sd0;
        mac_acc = 32'sd20;
        bias = 32'sd6;
        corrected_acc_in = '0;

        @(posedge clk);
        rst <= 1'b0;
        ce <= 1'b1;

        @(posedge clk);
        #1;
        if (out !== 8'd20) begin
            $fatal(1, "output_stage case1 mismatch: out=%0d", out);
        end

        mac_acc = -32'sd200;
        bias = 32'sd0;
        weight_sum = 32'sd1;
        feature_sum = 32'sd0;

        @(posedge clk);
        #1;
        if (out !== 8'd0) begin
            $fatal(1, "output_stage case2 mismatch: out=%0d", out);
        end

        $display("PASS tb_output_stage");
        $finish;
    end
endmodule
