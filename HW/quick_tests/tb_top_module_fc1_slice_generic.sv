`timescale 1ns / 1ps

`ifndef SLICE_M
`define SLICE_M 4
`endif

`ifndef SLICE_WEIGHTS_FILE
`define SLICE_WEIGHTS_FILE "quick_tests/fc1_slice_4_weights.mem"
`endif

`ifndef SLICE_INPUT_FILE
`define SLICE_INPUT_FILE "quick_tests/fc1_slice_4_input.mem"
`endif

`ifndef SLICE_TRUTH_FILE
`define SLICE_TRUTH_FILE "quick_tests/fc1_slice_4_truth.mem"
`endif

module tb_top_module_fc1_slice_generic;
    localparam int INPUT_PRECISION = 8;
    localparam int WEIGHT_PRECISION = 8;
    localparam int OUTPUT_PRECISION = 8;
    localparam int ACC_PRECISION = 32;
    localparam int NUM_FEATURES = 2;
    localparam int MUL_PER_FEATURE = 8;
    localparam int N = 784;
    localparam int M = `SLICE_M;
    localparam int TEMP = 2;
    localparam int IN_ZP = 128;
    localparam int W_ZP = 133;
    localparam int OUT_ZP = 131;
    localparam int M_MUL = 1616892571;
    localparam int M_SHIFT = 43;

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
    integer mismatch_count;

    top_module #(
        .TEMP(TEMP),
        .INPUT_PRECISION(INPUT_PRECISION),
        .WEIGHT_PRECISION(WEIGHT_PRECISION),
        .OUTPUT_PRECISION(OUTPUT_PRECISION),
        .ACC_PRECISION(ACC_PRECISION),
        .NUM_FEATURES(NUM_FEATURES),
        .MUL_PER_FEATURE(MUL_PER_FEATURE),
        .N(N),
        .M(M),
        .IN_ZP(IN_ZP),
        .W_ZP(W_ZP),
        .OUT_ZP(OUT_ZP),
        .M_MUL(M_MUL),
        .M_SHIFT(M_SHIFT),
        .MEMORY_FILE(`SLICE_WEIGHTS_FILE)
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

    always #5 clk = ~clk;

    initial begin
        $readmemh(`SLICE_INPUT_FILE, raw_examples);
        $readmemh(`SLICE_TRUTH_FILE, raw_truth);

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
                            "fc1_slice_m%0d mismatch feature=%0d out=%0d sim=%0d truth=%0d",
                            M,
                            feature_idx,
                            output_idx,
                            out[feature_idx][output_idx],
                            truth[feature_idx][output_idx]
                        );
                    end
                end
            end
        end

        if (mismatch_count != 0) begin
            $fatal(1, "fc1_slice_m%0d mismatches=%0d", M, mismatch_count);
        end

        $display("PASS tb_top_module_fc1_slice_generic m=%0d", M);
        $finish;
    end
endmodule
