`timescale 1ns / 1ps

`include "../generated/mlp_params.svh"

module tb_mlp_cycle_breakdown;
    localparam int NUM_FEATURES = 2;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic in_valid = 1'b0;
    logic out_ready = 1'b0;
    logic out_valid;
    logic in_ready;
    integer cycle_count;

    logic [FC1_INPUT_PRECISION-1:0] raw_examples [FC1_N * NUM_FEATURES];
    logic [FC1_INPUT_PRECISION-1:0] features [NUM_FEATURES-1:0][FC1_N-1:0];
    logic [FC3_OUTPUT_PRECISION-1:0] out [NUM_FEATURES-1:0][FC3_M-1:0];

    mlp_top #(
        .NUM_FEATURES(NUM_FEATURES),
        .FC1_TEMP(1),
        .FC1_MUL_PER_FEATURE(8),
        .FC1_INPUT_PRECISION(FC1_INPUT_PRECISION),
        .FC1_WEIGHT_PRECISION(FC1_WEIGHT_PRECISION),
        .FC1_OUTPUT_PRECISION(FC1_OUTPUT_PRECISION),
        .FC1_BIAS_PRECISION(FC1_BIAS_PRECISION),
        .FC1_N(FC1_N),
        .FC1_M(FC1_M),
        .FC1_IN_ZP(FC1_IN_ZP),
        .FC1_W_ZP(FC1_W_ZP),
        .FC1_OUT_ZP(FC1_OUT_ZP),
        .FC1_M_MUL(FC1_M_MUL),
        .FC1_M_SHIFT(FC1_M_SHIFT),
        .FC1_MEMORY_FILE("generated/runtime/fc1_weights.mem"),
        .FC2_TEMP(1),
        .FC2_MUL_PER_FEATURE(4),
        .FC2_INPUT_PRECISION(FC2_INPUT_PRECISION),
        .FC2_WEIGHT_PRECISION(FC2_WEIGHT_PRECISION),
        .FC2_OUTPUT_PRECISION(FC2_OUTPUT_PRECISION),
        .FC2_BIAS_PRECISION(FC2_BIAS_PRECISION),
        .FC2_N(FC2_N),
        .FC2_M(FC2_M),
        .FC2_IN_ZP(FC2_IN_ZP),
        .FC2_W_ZP(FC2_W_ZP),
        .FC2_OUT_ZP(FC2_OUT_ZP),
        .FC2_M_MUL(FC2_M_MUL),
        .FC2_M_SHIFT(FC2_M_SHIFT),
        .FC2_MEMORY_FILE("generated/runtime/fc2_weights.mem"),
        .FC3_TEMP(1),
        .FC3_MUL_PER_FEATURE(4),
        .FC3_INPUT_PRECISION(FC3_INPUT_PRECISION),
        .FC3_WEIGHT_PRECISION(FC3_WEIGHT_PRECISION),
        .FC3_OUTPUT_PRECISION(FC3_OUTPUT_PRECISION),
        .FC3_BIAS_PRECISION(FC3_BIAS_PRECISION),
        .FC3_N(FC3_N),
        .FC3_M(FC3_M),
        .FC3_IN_ZP(FC3_IN_ZP),
        .FC3_W_ZP(FC3_W_ZP),
        .FC3_OUT_ZP(FC3_OUT_ZP),
        .FC3_M_MUL(FC3_M_MUL),
        .FC3_M_SHIFT(FC3_M_SHIFT),
        .FC3_MEMORY_FILE("generated/runtime/fc3_weights.mem")
    ) dut (
        .out_valid(out_valid),
        .in_ready(in_ready),
        .in_valid(in_valid),
        .out_ready(out_ready),
        .clk(clk),
        .rst(rst),
        .ce(ce),
        .features(features),
        .out(out)
    );

    always #1 clk = ~clk;

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
        end else if (ce) begin
            cycle_count <= cycle_count + 1;
            if (dut.fc1_in_valid && dut.fc1_in_ready) $display("cycle %0d : fc1 accept", cycle_count);
            if (dut.fc1_out_valid && dut.fc1_out_ready) $display("cycle %0d : fc1 done", cycle_count);
            if (dut.fc2_in_valid && dut.fc2_in_ready) $display("cycle %0d : fc2 accept", cycle_count);
            if (dut.fc2_out_valid && dut.fc2_out_ready) $display("cycle %0d : fc2 done", cycle_count);
            if (dut.fc3_in_valid && dut.fc3_in_ready) $display("cycle %0d : fc3 accept", cycle_count);
            if (dut.fc3_out_valid && dut.fc3_out_ready) $display("cycle %0d : fc3 done", cycle_count);
            if (out_valid) $display("cycle %0d : mlp out_valid", cycle_count);
        end
    end

    integer i;
    integer feat;
    integer idx;

    initial begin
        $readmemh("generated/runtime/mlp_test_input.mem", raw_examples);
        for (i = 0; i < FC1_N * NUM_FEATURES; i = i + 1) begin
            feat = i / FC1_N;
            idx = i % FC1_N;
            features[feat][idx] = raw_examples[i];
        end

        repeat (2) @(posedge clk);
        rst <= 1'b0;
        ce <= 1'b1;

        @(posedge clk);
        in_valid <= 1'b1;
        out_ready <= 1'b1;
        wait (in_ready);
        @(posedge clk);
        in_valid <= 1'b0;
        wait (out_valid);
        #1;
        $finish;
    end
endmodule
