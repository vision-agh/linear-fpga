`timescale 1ns / 1ps

`include "../generated/fc1_params.svh"

module tb_fc1_serial_debug;
    localparam int NUM_FEATURES = 1;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic in_valid = 1'b0;
    logic out_ready = 1'b0;
    logic out_valid;
    logic in_ready;

    logic [INPUT_PRECISION-1:0] raw_examples [N * NUM_FEATURES];
    logic [OUTPUT_PRECISION-1:0] raw_truth [M * NUM_FEATURES];
    logic [INPUT_PRECISION-1:0] features [NUM_FEATURES-1:0][N-1:0];
    logic [OUTPUT_PRECISION-1:0] truth [NUM_FEATURES-1:0][M-1:0];
    logic [OUTPUT_PRECISION-1:0] out [NUM_FEATURES-1:0][M-1:0];

    integer i;
    integer debug_count;

    top_module #(
        .TEMP(-2),
        .INPUT_PRECISION(INPUT_PRECISION),
        .WEIGHT_PRECISION(WEIGHT_PRECISION),
        .OUTPUT_PRECISION(OUTPUT_PRECISION),
        .ACC_PRECISION(BIAS_PRECISION),
        .NUM_FEATURES(NUM_FEATURES),
        .MUL_PER_FEATURE(8),
        .N(N),
        .M(M),
        .IN_ZP(IN_ZP),
        .W_ZP(W_ZP),
        .OUT_ZP(OUT_ZP),
        .M_MUL(M_MUL),
        .M_SHIFT(M_SHIFT),
        .MEMORY_FILE("generated/runtime/fc1_weights.mem")
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
        if (!rst && ce && dut.gen_serial_mode.serial_valid_pipe[dut.gen_serial_mode.SERIAL_PIPELINE_LATENCY-1] && debug_count < 24) begin
            $display(
                "pipe idx=%0d first=%0d last=%0d corr_now=%0d row=%0d slice=%0d",
                dut.gen_serial_mode.serial_index_pipe[dut.gen_serial_mode.SERIAL_PIPELINE_LATENCY-1],
                dut.gen_serial_mode.serial_first_pipe[dut.gen_serial_mode.SERIAL_PIPELINE_LATENCY-1],
                dut.gen_serial_mode.serial_last_pipe[dut.gen_serial_mode.SERIAL_PIPELINE_LATENCY-1],
                dut.gen_serial_mode.corrected_acc_serial[0],
                dut.gen_serial_mode.serial_row_index,
                dut.gen_serial_mode.serial_slice_index
            );
        end
        if (!rst && ce && dut.gen_serial_mode.serial_acc_valid && debug_count < 16) begin
            $display(
                "serial_acc idx=%0d corrected=%0d requant_prev=%0d row=%0d slice=%0d",
                dut.gen_serial_mode.serial_acc_index,
                dut.gen_serial_mode.serial_acc_value[0],
                dut.gen_serial_mode.serial_requant_out[0],
                dut.gen_serial_mode.serial_row_index,
                dut.gen_serial_mode.serial_slice_index
            );
            debug_count <= debug_count + 1;
        end
    end

    initial begin
        debug_count = 0;
        $readmemh("generated/runtime/mlp_test_input.mem", raw_examples);
        $readmemh("generated/runtime/mlp_test_fc1_truth.mem", raw_truth);

        for (i = 0; i < N; i = i + 1) begin
            features[0][i] = raw_examples[i];
        end

        for (i = 0; i < M; i = i + 1) begin
            truth[0][i] = raw_truth[i];
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

        for (i = 0; i < 16; i = i + 1) begin
            $display("final fc1 out[%0d]=%0d truth=%0d", i, out[0][i], truth[0][i]);
        end

        $finish;
    end
endmodule
