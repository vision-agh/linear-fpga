`timescale 1ns / 1ps

module mlp_testbench;

`include "generated/mlp_params.svh"
`include "mlp_runtime_overrides.svh"

`ifndef MLP_NUM_FEATURES
`define MLP_NUM_FEATURES 2
`endif

`ifndef MLP_FC1_TEMP
`define MLP_FC1_TEMP 1
`endif

`ifndef MLP_FC2_TEMP
`define MLP_FC2_TEMP 1
`endif

`ifndef MLP_FC3_TEMP
`define MLP_FC3_TEMP 1
`endif

`ifndef MLP_FC1_MPF
`define MLP_FC1_MPF 8
`endif

`ifndef MLP_FC2_MPF
`define MLP_FC2_MPF 8
`endif

`ifndef MLP_FC3_MPF
`define MLP_FC3_MPF 8
`endif

`ifndef MLP_CHECK_INTERMEDIATES
`define MLP_CHECK_INTERMEDIATES 0
`endif

`ifndef MLP_FC1_WEIGHTS_FILE
`define MLP_FC1_WEIGHTS_FILE "generated/fc1_weights.mem"
`endif

`ifndef MLP_FC2_WEIGHTS_FILE
`define MLP_FC2_WEIGHTS_FILE "generated/fc2_weights.mem"
`endif

`ifndef MLP_FC3_WEIGHTS_FILE
`define MLP_FC3_WEIGHTS_FILE "generated/fc3_weights.mem"
`endif

`ifndef MLP_INPUT_FILE
`define MLP_INPUT_FILE "generated/mlp_test_input.mem"
`endif

`ifndef MLP_FC1_TRUTH_FILE
`define MLP_FC1_TRUTH_FILE "generated/mlp_test_fc1_truth.mem"
`endif

`ifndef MLP_RELU1_TRUTH_FILE
`define MLP_RELU1_TRUTH_FILE "generated/mlp_test_relu1_truth.mem"
`endif

`ifndef MLP_FC2_TRUTH_FILE
`define MLP_FC2_TRUTH_FILE "generated/mlp_test_fc2_truth.mem"
`endif

`ifndef MLP_RELU2_TRUTH_FILE
`define MLP_RELU2_TRUTH_FILE "generated/mlp_test_relu2_truth.mem"
`endif

`ifndef MLP_FC3_TRUTH_FILE
`define MLP_FC3_TRUTH_FILE "generated/mlp_test_fc3_truth.mem"
`endif

`ifndef MLP_OUTPUT_FILE
`define MLP_OUTPUT_FILE "generated/mlp_sim_output.txt"
`endif

    localparam int NUM_FEATURES = `MLP_NUM_FEATURES;
    localparam string INPUT_FILE = `MLP_INPUT_FILE;
    localparam string FC1_TRUTH_FILE = `MLP_FC1_TRUTH_FILE;
    localparam string RELU1_TRUTH_FILE = `MLP_RELU1_TRUTH_FILE;
    localparam string FC2_TRUTH_FILE = `MLP_FC2_TRUTH_FILE;
    localparam string RELU2_TRUTH_FILE = `MLP_RELU2_TRUTH_FILE;
    localparam string FC3_TRUTH_FILE = `MLP_FC3_TRUTH_FILE;
    localparam string OUTPUT_FILE = `MLP_OUTPUT_FILE;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic in_valid = 1'b0;
    logic out_ready = 1'b0;
    logic out_valid;
    logic in_ready;

    logic [FC1_INPUT_PRECISION-1:0] raw_examples [FC1_N * NUM_FEATURES];
    logic [FC1_INPUT_PRECISION-1:0] features [NUM_FEATURES-1:0][FC1_N-1:0];
    logic [FC1_OUTPUT_PRECISION-1:0] raw_fc1_truth [FC1_M * NUM_FEATURES];
    logic [FC1_OUTPUT_PRECISION-1:0] raw_relu1_truth [FC1_M * NUM_FEATURES];
    logic [FC2_OUTPUT_PRECISION-1:0] raw_fc2_truth [FC2_M * NUM_FEATURES];
    logic [FC2_OUTPUT_PRECISION-1:0] raw_relu2_truth [FC2_M * NUM_FEATURES];
    logic [FC3_OUTPUT_PRECISION-1:0] raw_fc3_truth [FC3_M * NUM_FEATURES];

    logic [FC1_OUTPUT_PRECISION-1:0] fc1_truth [NUM_FEATURES-1:0][FC1_M-1:0];
    logic [FC1_OUTPUT_PRECISION-1:0] relu1_truth [NUM_FEATURES-1:0][FC1_M-1:0];
    logic [FC2_OUTPUT_PRECISION-1:0] fc2_truth [NUM_FEATURES-1:0][FC2_M-1:0];
    logic [FC2_OUTPUT_PRECISION-1:0] relu2_truth [NUM_FEATURES-1:0][FC2_M-1:0];
    logic [FC3_OUTPUT_PRECISION-1:0] fc3_truth [NUM_FEATURES-1:0][FC3_M-1:0];
    logic [FC3_OUTPUT_PRECISION-1:0] out [NUM_FEATURES-1:0][FC3_M-1:0];

    integer i;
    integer feat;
    integer idx;
    integer file;
    integer mismatch_count;
    integer cycle_count;
    integer start_cycle;
    integer end_cycle;

    mlp_top #(
        .NUM_FEATURES(NUM_FEATURES),

        .FC1_TEMP(`MLP_FC1_TEMP),
        .FC1_INPUT_PRECISION(FC1_INPUT_PRECISION),
        .FC1_WEIGHT_PRECISION(FC1_WEIGHT_PRECISION),
        .FC1_OUTPUT_PRECISION(FC1_OUTPUT_PRECISION),
        .FC1_BIAS_PRECISION(FC1_BIAS_PRECISION),
        .FC1_MUL_PER_FEATURE(`MLP_FC1_MPF),
        .FC1_N(FC1_N),
        .FC1_M(FC1_M),
        .FC1_IN_ZP(FC1_IN_ZP),
        .FC1_W_ZP(FC1_W_ZP),
        .FC1_OUT_ZP(FC1_OUT_ZP),
        .FC1_M_MUL(FC1_M_MUL),
        .FC1_M_SHIFT(FC1_M_SHIFT),
        .FC1_MEMORY_FILE(`MLP_FC1_WEIGHTS_FILE),

        .FC2_TEMP(`MLP_FC2_TEMP),
        .FC2_INPUT_PRECISION(FC2_INPUT_PRECISION),
        .FC2_WEIGHT_PRECISION(FC2_WEIGHT_PRECISION),
        .FC2_OUTPUT_PRECISION(FC2_OUTPUT_PRECISION),
        .FC2_BIAS_PRECISION(FC2_BIAS_PRECISION),
        .FC2_MUL_PER_FEATURE(`MLP_FC2_MPF),
        .FC2_N(FC2_N),
        .FC2_M(FC2_M),
        .FC2_IN_ZP(FC2_IN_ZP),
        .FC2_W_ZP(FC2_W_ZP),
        .FC2_OUT_ZP(FC2_OUT_ZP),
        .FC2_M_MUL(FC2_M_MUL),
        .FC2_M_SHIFT(FC2_M_SHIFT),
        .FC2_MEMORY_FILE(`MLP_FC2_WEIGHTS_FILE),

        .FC3_TEMP(`MLP_FC3_TEMP),
        .FC3_INPUT_PRECISION(FC3_INPUT_PRECISION),
        .FC3_WEIGHT_PRECISION(FC3_WEIGHT_PRECISION),
        .FC3_OUTPUT_PRECISION(FC3_OUTPUT_PRECISION),
        .FC3_BIAS_PRECISION(FC3_BIAS_PRECISION),
        .FC3_MUL_PER_FEATURE(`MLP_FC3_MPF),
        .FC3_N(FC3_N),
        .FC3_M(FC3_M),
        .FC3_IN_ZP(FC3_IN_ZP),
        .FC3_W_ZP(FC3_W_ZP),
        .FC3_OUT_ZP(FC3_OUT_ZP),
        .FC3_M_MUL(FC3_M_MUL),
        .FC3_M_SHIFT(FC3_M_SHIFT),
        .FC3_MEMORY_FILE(`MLP_FC3_WEIGHTS_FILE)
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
        end
    end

    initial begin
        cycle_count = 0;
        start_cycle = 0;
        end_cycle = 0;
        $readmemh(INPUT_FILE, raw_examples);
        $readmemh(FC1_TRUTH_FILE, raw_fc1_truth);
        $readmemh(RELU1_TRUTH_FILE, raw_relu1_truth);
        $readmemh(FC2_TRUTH_FILE, raw_fc2_truth);
        $readmemh(RELU2_TRUTH_FILE, raw_relu2_truth);
        $readmemh(FC3_TRUTH_FILE, raw_fc3_truth);

        for (i = 0; i < FC1_N * NUM_FEATURES; i = i + 1) begin
            feat = i / FC1_N;
            idx = i % FC1_N;
            features[feat][idx] = raw_examples[i];
        end

        for (i = 0; i < FC1_M * NUM_FEATURES; i = i + 1) begin
            feat = i / FC1_M;
            idx = i % FC1_M;
            fc1_truth[feat][idx] = raw_fc1_truth[i];
            relu1_truth[feat][idx] = raw_relu1_truth[i];
        end

        for (i = 0; i < FC2_M * NUM_FEATURES; i = i + 1) begin
            feat = i / FC2_M;
            idx = i % FC2_M;
            fc2_truth[feat][idx] = raw_fc2_truth[i];
            relu2_truth[feat][idx] = raw_relu2_truth[i];
        end

        for (i = 0; i < FC3_M * NUM_FEATURES; i = i + 1) begin
            feat = i / FC3_M;
            idx = i % FC3_M;
            fc3_truth[feat][idx] = raw_fc3_truth[i];
        end

        repeat (2) @(posedge clk);
        rst <= 1'b0;
        ce <= 1'b1;

        @(posedge clk);
        in_valid <= 1'b1;
        out_ready <= 1'b1;
        wait (in_ready);
        start_cycle = cycle_count;
        @(posedge clk);
        in_valid <= 1'b0;

        wait (out_valid);
        end_cycle = cycle_count;
        #1;

        mismatch_count = 0;
        if (`MLP_CHECK_INTERMEDIATES) begin
            for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                for (int output_idx = 0; output_idx < FC1_M; output_idx++) begin
                    if (dut.fc1_out[feature_idx][output_idx] !== fc1_truth[feature_idx][output_idx]) begin
                        mismatch_count = mismatch_count + 1;
                        if (mismatch_count <= 12) begin
                            $display("FC1 mismatch feature=%0d out=%0d sim=%0d truth=%0d", feature_idx, output_idx, dut.fc1_out[feature_idx][output_idx], fc1_truth[feature_idx][output_idx]);
                        end
                    end
                    if (dut.relu1_reg[feature_idx][output_idx] !== relu1_truth[feature_idx][output_idx]) begin
                        mismatch_count = mismatch_count + 1;
                        if (mismatch_count <= 12) begin
                            $display("RELU1 mismatch feature=%0d out=%0d sim=%0d truth=%0d", feature_idx, output_idx, dut.relu1_reg[feature_idx][output_idx], relu1_truth[feature_idx][output_idx]);
                        end
                    end
                end
            end

            for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                for (int output_idx = 0; output_idx < FC2_M; output_idx++) begin
                    if (dut.fc2_out[feature_idx][output_idx] !== fc2_truth[feature_idx][output_idx]) begin
                        mismatch_count = mismatch_count + 1;
                        if (mismatch_count <= 12) begin
                            $display("FC2 mismatch feature=%0d out=%0d sim=%0d truth=%0d", feature_idx, output_idx, dut.fc2_out[feature_idx][output_idx], fc2_truth[feature_idx][output_idx]);
                        end
                    end
                    if (dut.relu2_reg[feature_idx][output_idx] !== relu2_truth[feature_idx][output_idx]) begin
                        mismatch_count = mismatch_count + 1;
                        if (mismatch_count <= 12) begin
                            $display("RELU2 mismatch feature=%0d out=%0d sim=%0d truth=%0d", feature_idx, output_idx, dut.relu2_reg[feature_idx][output_idx], relu2_truth[feature_idx][output_idx]);
                        end
                    end
                end
            end
        end

        for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
            for (int output_idx = 0; output_idx < FC3_M; output_idx++) begin
                if (out[feature_idx][output_idx] !== fc3_truth[feature_idx][output_idx]) begin
                    mismatch_count = mismatch_count + 1;
                    if (mismatch_count <= 12) begin
                        $display("FC3 mismatch feature=%0d out=%0d sim=%0d truth=%0d", feature_idx, output_idx, out[feature_idx][output_idx], fc3_truth[feature_idx][output_idx]);
                    end
                end
            end
        end

        file = $fopen(OUTPUT_FILE, "w");
        if (file) begin
            for (int feature_write_idx = 0; feature_write_idx < NUM_FEATURES; feature_write_idx++) begin
                for (int output_write_idx = 0; output_write_idx < FC3_M; output_write_idx++) begin
                    $fwrite(file, "%0d\n", out[feature_write_idx][output_write_idx]);
                end
            end
            $fclose(file);
        end else begin
            $fatal(1, "Could not open output file %s", OUTPUT_FILE);
        end

        if (mismatch_count != 0) begin
            $fatal(1, "mlp_testbench mismatches=%0d", mismatch_count);
        end

        $display(
            "METRIC cycles=%0d fc1_temp=%0d fc2_temp=%0d fc3_temp=%0d fc1_mpf=%0d fc2_mpf=%0d fc3_mpf=%0d",
            end_cycle - start_cycle,
            `MLP_FC1_TEMP,
            `MLP_FC2_TEMP,
            `MLP_FC3_TEMP,
            `MLP_FC1_MPF,
            `MLP_FC2_MPF,
            `MLP_FC3_MPF
        );
        $display("PASS mlp_testbench");
        $finish;
    end

endmodule
