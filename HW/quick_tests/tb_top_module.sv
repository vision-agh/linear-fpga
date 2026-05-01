`timescale 1ns / 1ps

module tb_top_module;
    localparam int INPUT_PRECISION = 8;
    localparam int WEIGHT_PRECISION = 8;
    localparam int OUTPUT_PRECISION = 8;
    localparam int ACC_PRECISION = 32;
    localparam int NUM_FEATURES = 2;
    localparam int MUL_PER_FEATURE = 2;
    localparam int N = 4;
    localparam int M = 2;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic ce = 1'b0;
    logic in_valid = 1'b0;
    logic out_ready = 1'b0;
    logic out_valid;
    logic in_ready;
    logic [INPUT_PRECISION-1:0] features [NUM_FEATURES-1:0][N-1:0];
    logic [OUTPUT_PRECISION-1:0] out [NUM_FEATURES-1:0][M-1:0];

    top_module #(
        .TEMP(2),
        .INPUT_PRECISION(INPUT_PRECISION),
        .WEIGHT_PRECISION(WEIGHT_PRECISION),
        .OUTPUT_PRECISION(OUTPUT_PRECISION),
        .ACC_PRECISION(ACC_PRECISION),
        .NUM_FEATURES(NUM_FEATURES),
        .MUL_PER_FEATURE(MUL_PER_FEATURE),
        .N(N),
        .M(M),
        .IN_ZP(1),
        .W_ZP(128),
        .OUT_ZP(0),
        .M_MUL(16),
        .M_SHIFT(4),
        .MEMORY_FILE("quick_tests/weights_small.mem")
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
            $display(
                "t=%0t state=%0d in_v=%0d in_r=%0d out_v=%0d out_r=%0d mem_clr=%0d buf_clr=%0d lc=%0d bias=%0d w={%0d,%0d,%0d,%0d} row_out={%0d,%0d} burst={%0d,%0d}",
                $time,
                dut.state,
                in_valid,
                in_ready,
                out_valid,
                out_ready,
                dut.memory_clr,
                dut.buffer_clr,
                dut.gen_feature_parallel_mode.u_memory_fetcher.line_counter,
                dut.gen_feature_parallel_mode.bias_single,
                dut.gen_feature_parallel_mode.weights_single[0],
                dut.gen_feature_parallel_mode.weights_single[1],
                dut.gen_feature_parallel_mode.weights_single[2],
                dut.gen_feature_parallel_mode.weights_single[3],
                dut.gen_feature_parallel_mode.r_out_mult[0],
                dut.gen_feature_parallel_mode.r_out_mult[1],
                dut.gen_feature_parallel_mode.burst_complete_single[0],
                dut.gen_feature_parallel_mode.burst_complete_single[1]
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
        if (out[0][0] !== 8'd0 || out[0][1] !== 8'd52 ||
            out[1][0] !== 8'd7 || out[1][1] !== 8'd32) begin
            $display("debug final out f0={%0d,%0d} f1={%0d,%0d}", out[0][0], out[0][1], out[1][0], out[1][1]);
            $display(
                "debug burst buffers f0={%0d,%0d} f1={%0d,%0d}",
                dut.r_out_buffer[0][0],
                dut.r_out_buffer[0][1],
                dut.r_out_buffer[1][0],
                dut.r_out_buffer[1][1]
            );
            $fatal(
                1,
                "top_module mismatch: f0={%0d,%0d} f1={%0d,%0d}",
                out[0][0], out[0][1], out[1][0], out[1][1]
            );
        end

        $display("PASS tb_top_module");
        $finish;
    end
endmodule
