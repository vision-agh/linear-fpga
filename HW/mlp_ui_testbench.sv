`timescale 1ns / 1ps

module mlp_ui_testbench;

`include "generated/mlp_params.svh"
`include "generated/runtime/mlp_ui_runtime_overrides.svh"

`ifndef UI_FC1_TEMP
`define UI_FC1_TEMP 1
`endif

`ifndef UI_FC2_TEMP
`define UI_FC2_TEMP 1
`endif

`ifndef UI_FC3_TEMP
`define UI_FC3_TEMP 1
`endif

`ifndef UI_FC1_MPF
`define UI_FC1_MPF 8
`endif

`ifndef UI_FC2_MPF
`define UI_FC2_MPF 8
`endif

`ifndef UI_FC3_MPF
`define UI_FC3_MPF 8
`endif

`ifndef UI_INPUT_FILE
`define UI_INPUT_FILE "generated/runtime/ui_input.mem"
`endif

`ifndef UI_OUTPUT_FILE
`define UI_OUTPUT_FILE "generated/runtime/ui_sim_output.txt"
`endif

`ifndef UI_FC1_WEIGHTS_FILE
`define UI_FC1_WEIGHTS_FILE "generated/fc1_weights.mem"
`endif

`ifndef UI_FC2_WEIGHTS_FILE
`define UI_FC2_WEIGHTS_FILE "generated/fc2_weights.mem"
`endif

`ifndef UI_FC3_WEIGHTS_FILE
`define UI_FC3_WEIGHTS_FILE "generated/fc3_weights.mem"
`endif

    localparam int NUM_FEATURES = 1;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic in_valid = 1'b0;
    logic out_ready = 1'b0;
    logic out_valid;
    logic in_ready;

    logic [FC1_INPUT_PRECISION-1:0] raw_examples [FC1_N * NUM_FEATURES];
    logic [FC1_INPUT_PRECISION-1:0] features [NUM_FEATURES-1:0][FC1_N-1:0];
    logic [FC3_OUTPUT_PRECISION-1:0] out [NUM_FEATURES-1:0][FC3_M-1:0];

    integer i;
    integer file;
    integer cycle_count;
    integer start_cycle;
    integer end_cycle;

    mlp_top #(
        .NUM_FEATURES(NUM_FEATURES),
        .FC1_TEMP(`UI_FC1_TEMP),
        .FC1_INPUT_PRECISION(FC1_INPUT_PRECISION),
        .FC1_WEIGHT_PRECISION(FC1_WEIGHT_PRECISION),
        .FC1_OUTPUT_PRECISION(FC1_OUTPUT_PRECISION),
        .FC1_BIAS_PRECISION(FC1_BIAS_PRECISION),
        .FC1_MUL_PER_FEATURE(`UI_FC1_MPF),
        .FC1_N(FC1_N),
        .FC1_M(FC1_M),
        .FC1_IN_ZP(FC1_IN_ZP),
        .FC1_W_ZP(FC1_W_ZP),
        .FC1_OUT_ZP(FC1_OUT_ZP),
        .FC1_M_MUL(FC1_M_MUL),
        .FC1_M_SHIFT(FC1_M_SHIFT),
        .FC1_MEMORY_FILE(`UI_FC1_WEIGHTS_FILE),
        .FC2_TEMP(`UI_FC2_TEMP),
        .FC2_INPUT_PRECISION(FC2_INPUT_PRECISION),
        .FC2_WEIGHT_PRECISION(FC2_WEIGHT_PRECISION),
        .FC2_OUTPUT_PRECISION(FC2_OUTPUT_PRECISION),
        .FC2_BIAS_PRECISION(FC2_BIAS_PRECISION),
        .FC2_MUL_PER_FEATURE(`UI_FC2_MPF),
        .FC2_N(FC2_N),
        .FC2_M(FC2_M),
        .FC2_IN_ZP(FC2_IN_ZP),
        .FC2_W_ZP(FC2_W_ZP),
        .FC2_OUT_ZP(FC2_OUT_ZP),
        .FC2_M_MUL(FC2_M_MUL),
        .FC2_M_SHIFT(FC2_M_SHIFT),
        .FC2_MEMORY_FILE(`UI_FC2_WEIGHTS_FILE),
        .FC3_TEMP(`UI_FC3_TEMP),
        .FC3_INPUT_PRECISION(FC3_INPUT_PRECISION),
        .FC3_WEIGHT_PRECISION(FC3_WEIGHT_PRECISION),
        .FC3_OUTPUT_PRECISION(FC3_OUTPUT_PRECISION),
        .FC3_BIAS_PRECISION(FC3_BIAS_PRECISION),
        .FC3_MUL_PER_FEATURE(`UI_FC3_MPF),
        .FC3_N(FC3_N),
        .FC3_M(FC3_M),
        .FC3_IN_ZP(FC3_IN_ZP),
        .FC3_W_ZP(FC3_W_ZP),
        .FC3_OUT_ZP(FC3_OUT_ZP),
        .FC3_M_MUL(FC3_M_MUL),
        .FC3_M_SHIFT(FC3_M_SHIFT),
        .FC3_MEMORY_FILE(`UI_FC3_WEIGHTS_FILE)
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
        $readmemh(`UI_INPUT_FILE, raw_examples);
        for (i = 0; i < FC1_N; i = i + 1) begin
            features[0][i] = raw_examples[i];
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

        file = $fopen(`UI_OUTPUT_FILE, "w");
        if (!file) begin
            $fatal(1, "Could not open UI output file %s", `UI_OUTPUT_FILE);
        end

        for (int output_idx = 0; output_idx < FC3_M; output_idx++) begin
            $fwrite(file, "%0d\n", out[0][output_idx]);
        end
        $fclose(file);

        $display(
            "UI_METRIC cycles=%0d fc1_temp=%0d fc2_temp=%0d fc3_temp=%0d fc1_mpf=%0d fc2_mpf=%0d fc3_mpf=%0d",
            end_cycle - start_cycle,
            `UI_FC1_TEMP,
            `UI_FC2_TEMP,
            `UI_FC3_TEMP,
            `UI_FC1_MPF,
            `UI_FC2_MPF,
            `UI_FC3_MPF
        );
        $display("PASS mlp_ui_testbench");
        $finish;
    end

endmodule
