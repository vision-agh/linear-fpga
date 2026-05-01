`timescale 1ns / 1ps

module tb_multiplier_top;
    localparam int INPUT_PRECISION = 8;
    localparam int WEIGHT_PRECISION = 8;
    localparam int OUTPUT_PRECISION = 8;
    localparam int ACC_PRECISION = 32;
    localparam int OUTPUT_STAGE_PRECISION = 64;
    localparam int NUM_FEATURES = 2;
    localparam int MUL_PER_FEATURE = 2;
    localparam int N = 4;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic signed [ACC_PRECISION-1:0] bias;
    logic [WEIGHT_PRECISION-1:0] weights_in [N-1:0];
    logic [INPUT_PRECISION-1:0] features [NUM_FEATURES-1:0][N-1:0];
    logic [OUTPUT_PRECISION-1:0] out [NUM_FEATURES-1:0];

    multiplier_top #(
        .INPUT_PRECISION(INPUT_PRECISION),
        .WEIGHT_PRECISION(WEIGHT_PRECISION),
        .OUTPUT_PRECISION(OUTPUT_PRECISION),
        .ACC_PRECISION(ACC_PRECISION),
        .OUTPUT_STAGE_PRECISION(OUTPUT_STAGE_PRECISION),
        .NUM_FEATURES(NUM_FEATURES),
        .MUL_PER_FEATURE(MUL_PER_FEATURE),
        .N(N),
        .IN_ZP(1),
        .W_ZP(128),
        .OUT_ZP(0),
        .M_MUL(16),
        .M_SHIFT(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .ce(ce),
        .bias(bias),
        .weights_in(weights_in),
        .features(features),
        .out(out),
        .corrected_acc_out()
    );

    always #5 clk = ~clk;

    initial begin
        bias = 32'sd9;
        weights_in[0] = 8'd129;
        weights_in[1] = 8'd126;
        weights_in[2] = 8'd131;
        weights_in[3] = 8'd124;
        features[0][0] = 8'd2;
        features[0][1] = 8'd3;
        features[0][2] = 8'd4;
        features[0][3] = 8'd5;
        features[1][0] = 8'd6;
        features[1][1] = 8'd1;
        features[1][2] = 8'd2;
        features[1][3] = 8'd3;

        @(posedge clk);
        rst <= 1'b0;
        ce <= 1'b1;

        repeat (5) @(posedge clk);
        #1;
        if (out[0] !== 8'd0 || out[1] !== 8'd9) begin
            $display(
                "debug delayed_features f0={%0d,%0d,%0d,%0d} f1={%0d,%0d,%0d,%0d}",
                dut.delayed_features[0][0], dut.delayed_features[0][1], dut.delayed_features[0][2], dut.delayed_features[0][3],
                dut.delayed_features[1][0], dut.delayed_features[1][1], dut.delayed_features[1][2], dut.delayed_features[1][3]
            );
            $display(
                "debug mac_acc={%0d,%0d} weight_sum={%0d,%0d} delayed_bias=%0d",
                dut.mac_acc[0], dut.mac_acc[1], dut.weight_sum[0], dut.weight_sum[1], dut.delayed_bias
            );
            $display(
                "debug slices f0 mac={%0d,%0d} ws={%0d,%0d} | f1 mac={%0d,%0d} ws={%0d,%0d}",
                dut.gen_features[0].local_mac_acc_sliced[0],
                dut.gen_features[0].local_mac_acc_sliced[1],
                dut.gen_features[0].local_weight_sum_sliced[0],
                dut.gen_features[0].local_weight_sum_sliced[1],
                dut.gen_features[1].local_mac_acc_sliced[0],
                dut.gen_features[1].local_mac_acc_sliced[1],
                dut.gen_features[1].local_weight_sum_sliced[0],
                dut.gen_features[1].local_weight_sum_sliced[1]
            );
            $fatal(1, "multiplier_top mismatch: out0=%0d out1=%0d", out[0], out[1]);
        end

        $display("PASS tb_multiplier_top");
        $finish;
    end
endmodule
