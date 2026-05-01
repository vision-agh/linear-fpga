`timescale 1ns / 1ps

`include "fc1_params.svh"

`ifndef FC1_TEMP
`define FC1_TEMP 2
`endif

`ifndef FC1_MUL_PER_FEATURE
`define FC1_MUL_PER_FEATURE 8
`endif

`ifndef FC1_NUM_FEATURES
`define FC1_NUM_FEATURES 2
`endif

`ifndef FC1_FEATURES_FILE
`define FC1_FEATURES_FILE "generated/fc1_test_input.mem"
`endif

`ifndef FC1_TRUTH_FILE
`define FC1_TRUTH_FILE "generated/fc1_test_truth.mem"
`endif

`ifndef FC1_WEIGHTS_FILE
`define FC1_WEIGHTS_FILE "generated/fc1_weights.mem"
`endif

`ifndef FC1_OUTPUT_FILE
`define FC1_OUTPUT_FILE "generated/fc1_sim_output.txt"
`endif

module fc1_mode_testbench;
    localparam int TEMP = `FC1_TEMP;
    localparam int TEST_MUL_PER_FEATURE = `FC1_MUL_PER_FEATURE;
    localparam int NUM_FEATURES = `FC1_NUM_FEATURES;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic in_valid = 1'b0;
    logic out_ready = 1'b0;
    logic out_valid;
    logic in_ready;

    logic [INPUT_PRECISION-1:0] raw_examples [N * NUM_FEATURES];
    logic [INPUT_PRECISION-1:0] features [NUM_FEATURES-1:0][N-1:0];
    logic [OUTPUT_PRECISION-1:0] raw_truth [M * NUM_FEATURES];
    logic [OUTPUT_PRECISION-1:0] truth [NUM_FEATURES-1:0][M-1:0];
    logic [OUTPUT_PRECISION-1:0] out [NUM_FEATURES-1:0][M-1:0];

    integer i;
    integer feat;
    integer idx;
    integer file;
    integer mismatch_count;

    top_module #(
        .TEMP(TEMP),
        .INPUT_PRECISION(INPUT_PRECISION),
        .WEIGHT_PRECISION(WEIGHT_PRECISION),
        .OUTPUT_PRECISION(OUTPUT_PRECISION),
        .ACC_PRECISION(BIAS_PRECISION),
        .NUM_FEATURES(NUM_FEATURES),
        .MUL_PER_FEATURE(TEST_MUL_PER_FEATURE),
        .N(N),
        .M(M),
        .IN_ZP(IN_ZP),
        .W_ZP(W_ZP),
        .OUT_ZP(OUT_ZP),
        .M_MUL(M_MUL),
        .M_SHIFT(M_SHIFT),
        .MEMORY_FILE(`FC1_WEIGHTS_FILE)
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

    initial begin
        $readmemh(`FC1_FEATURES_FILE, raw_examples);
        $readmemh(`FC1_TRUTH_FILE, raw_truth);

        for (i = 0; i < N * NUM_FEATURES; i = i + 1) begin
            feat = i / N;
            idx = i % N;
            features[feat][idx] = raw_examples[i];
        end

        for (i = 0; i < M * NUM_FEATURES; i = i + 1) begin
            feat = i / M;
            idx = i % M;
            truth[feat][idx] = raw_truth[i];
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

        mismatch_count = 0;
        for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
            for (int output_idx = 0; output_idx < M; output_idx++) begin
                if (out[feature_idx][output_idx] !== truth[feature_idx][output_idx]) begin
                    mismatch_count = mismatch_count + 1;
                    if (mismatch_count <= 16) begin
                        $display(
                            "MISMATCH temp=%0d feature=%0d out=%0d sim=%0d truth=%0d",
                            TEMP,
                            feature_idx,
                            output_idx,
                            out[feature_idx][output_idx],
                            truth[feature_idx][output_idx]
                        );
                    end
                end
            end
        end

        file = $fopen(`FC1_OUTPUT_FILE, "w");
        if (file) begin
            for (int feature_write_idx = 0; feature_write_idx < NUM_FEATURES; feature_write_idx++) begin
                for (int output_write_idx = 0; output_write_idx < M; output_write_idx++) begin
                    $fwrite(file, "%0d\n", out[feature_write_idx][output_write_idx]);
                end
            end
            $fclose(file);
        end else begin
            $fatal(1, "Could not open output file %s", `FC1_OUTPUT_FILE);
        end

        if (mismatch_count != 0) begin
            $fatal(1, "fc1_mode_testbench temp=%0d mismatches=%0d", TEMP, mismatch_count);
        end

        $display("PASS fc1_mode_testbench temp=%0d", TEMP);
        $finish;
    end

endmodule
