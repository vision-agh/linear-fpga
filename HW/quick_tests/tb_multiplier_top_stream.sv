`timescale 1ns / 1ps

module tb_multiplier_top_stream;
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

    always @(posedge clk) begin
        if (!rst && ce) begin
            $display(
                "streamdbg t=%0t in_bias=%0d delayed_bias=%0d w={%0d,%0d,%0d,%0d} dw={%0d,%0d,%0d,%0d} mac={%0d,%0d} wsum={%0d,%0d} out={%0d,%0d}",
                $time,
                bias,
                dut.delayed_bias,
                weights_in[0], weights_in[1], weights_in[2], weights_in[3],
                dut.delayed_weights[0], dut.delayed_weights[1], dut.delayed_weights[2], dut.delayed_weights[3],
                dut.mac_acc[0], dut.mac_acc[1],
                dut.weight_sum[0], dut.weight_sum[1],
                out[0], out[1]
            );
        end
    end

    initial begin
        features[0][0] = 8'd2;
        features[0][1] = 8'd3;
        features[0][2] = 8'd4;
        features[0][3] = 8'd5;
        features[1][0] = 8'd6;
        features[1][1] = 8'd1;
        features[1][2] = 8'd2;
        features[1][3] = 8'd3;

        bias = 32'sd7;
        weights_in[0] = 8'd129;
        weights_in[1] = 8'd126;
        weights_in[2] = 8'd131;
        weights_in[3] = 8'd124;

        @(posedge clk);
        rst <= 1'b0;
        ce <= 1'b1;

        @(posedge clk);
        bias <= -32'sd8;
        weights_in[0] <= 8'd132;
        weights_in[1] <= 8'd133;
        weights_in[2] <= 8'd134;
        weights_in[3] <= 8'd135;

        repeat (6) begin
            @(posedge clk);
            $display("stream t=%0t out={%0d,%0d}", $time, out[0], out[1]);
        end

        if (out[0] !== 8'd52 || out[1] !== 8'd32) begin
            $fatal(1, "multiplier_top stream final mismatch: out0=%0d out1=%0d", out[0], out[1]);
        end

        $display("PASS tb_multiplier_top_stream");
        $finish;
    end
endmodule
