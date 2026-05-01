`timescale 1ns / 1ps

module tb_vector_multiplier_generator;
    localparam int INPUT_PRECISION = 8;
    localparam int WEIGHT_PRECISION = 8;
    localparam int ACC_PRECISION = 32;
    localparam int NUM_VALUES = 4;
    localparam int MUL_PER_FEATURE = 2;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic [INPUT_PRECISION-1:0] features_in [NUM_VALUES-1:0];
    logic [WEIGHT_PRECISION-1:0] weights_in [NUM_VALUES-1:0];
    logic signed [ACC_PRECISION-1:0] mac_acc [MUL_PER_FEATURE-1:0];
    logic signed [ACC_PRECISION-1:0] weight_sum [MUL_PER_FEATURE-1:0];
    logic signed [ACC_PRECISION-1:0] feature_sum [MUL_PER_FEATURE-1:0];

    vector_multiplier_generator #(
        .INPUT_PRECISION(INPUT_PRECISION),
        .WEIGHT_PRECISION(WEIGHT_PRECISION),
        .ACC_PRECISION(ACC_PRECISION),
        .NUM_VALUES(NUM_VALUES),
        .MUL_PER_FEATURE(MUL_PER_FEATURE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .ce(ce),
        .features_in(features_in),
        .weights_in(weights_in),
        .mac_acc(mac_acc),
        .weight_sum(weight_sum),
        .feature_sum(feature_sum)
    );

    always #5 clk = ~clk;

    initial begin
        features_in[0] = 8'd2;
        features_in[1] = 8'd3;
        features_in[2] = 8'd4;
        features_in[3] = 8'd5;
        weights_in[0] = 8'd129;
        weights_in[1] = 8'd126;
        weights_in[2] = 8'd131;
        weights_in[3] = 8'd124;

        @(posedge clk);
        rst <= 1'b0;
        ce <= 1'b1;

        @(posedge clk);
        #1;
        if (mac_acc[0] !== 32'sd636 || mac_acc[1] !== 32'sd1144 ||
            weight_sum[0] !== 32'sd255 || weight_sum[1] !== 32'sd255 ||
            feature_sum[0] !== 32'sd5 || feature_sum[1] !== 32'sd9) begin
            $fatal(
                1,
                "vector_multiplier_generator mismatch: mac={%0d,%0d} weight_sum={%0d,%0d} feature_sum={%0d,%0d}",
                mac_acc[0], mac_acc[1], weight_sum[0], weight_sum[1], feature_sum[0], feature_sum[1]
            );
        end

        $display("PASS tb_vector_multiplier_generator");
        $finish;
    end
endmodule
