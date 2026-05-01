`timescale 1ns / 1ps

module tb_top_module_fc1_stream_probe;
    localparam int INPUT_PRECISION = 8;
    localparam int WEIGHT_PRECISION = 8;
    localparam int OUTPUT_PRECISION = 8;
    localparam int ACC_PRECISION = 32;
    localparam int NUM_FEATURES = 2;
    localparam int MUL_PER_FEATURE = 8;
    localparam int N = 784;
    localparam int M = 64;
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
    integer lc;
    integer bc;

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
        .MEMORY_FILE("quick_tests/fc1_slice_64_weights.mem")
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

    always @(posedge clk) begin
        if (!rst && ce) begin
            lc = dut.gen_feature_parallel_mode.u_memory_fetcher.line_counter;
            bc = dut.gen_feature_parallel_mode.gen_single_burst[0].u_burst_buffer.count;
            if (lc >= 50 && lc <= 55) begin
                $display(
                    "probe t=%0t lc=%0d bc=%0d bias=%0d row_out={%0d,%0d} truth={%0d,%0d}",
                    $time,
                    lc,
                    bc,
                    dut.gen_feature_parallel_mode.bias_single,
                    dut.gen_feature_parallel_mode.r_out_mult[0],
                    dut.gen_feature_parallel_mode.r_out_mult[1],
                    truth[0][lc],
                    truth[1][lc]
                );
            end
        end
    end

    initial begin
        $readmemh("quick_tests/fc1_slice_64_input.mem", raw_examples);
        $readmemh("quick_tests/fc1_slice_64_truth.mem", raw_truth);

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
        $finish;
    end
endmodule
