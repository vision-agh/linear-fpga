`timescale 1ns / 1ps

module tb_vector_multiplier;
    localparam int INPUT_PRECISION = 8;
    localparam int WEIGHT_PRECISION = 8;
    localparam int ACC_PRECISION = 32;
    localparam int NUM_VALUES = 4;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic [INPUT_PRECISION-1:0] features_in [NUM_VALUES-1:0];
    logic [WEIGHT_PRECISION-1:0] weights_in [NUM_VALUES-1:0];
    logic signed [ACC_PRECISION-1:0] mac_acc;
    logic signed [ACC_PRECISION-1:0] weight_sum;
    logic signed [ACC_PRECISION-1:0] feature_sum;

    vector_multiplier #(
        .INPUT_PRECISION(INPUT_PRECISION),
        .WEIGHT_PRECISION(WEIGHT_PRECISION),
        .ACC_PRECISION(ACC_PRECISION),
        .NUM_VALUES(NUM_VALUES)
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
        features_in = '{8'd10, 8'd20, 8'd30, 8'd40};
        weights_in = '{8'd129, 8'd126, 8'd131, 8'd124};

        @(posedge clk);
        rst <= 1'b0;
        ce <= 1'b1;

        @(posedge clk);
        #1;
        if (mac_acc !== 32'sd12700 || weight_sum !== 32'sd510 || feature_sum !== 32'sd100) begin
            $fatal(1, "vector_multiplier mismatch: mac=%0d weight_sum=%0d feature_sum=%0d", mac_acc, weight_sum, feature_sum);
        end

        $display("PASS tb_vector_multiplier");
        $finish;
    end
endmodule
