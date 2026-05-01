`timescale 1ns / 1ps

module unit_test;

`include "generated/fc1_params.svh"

localparam int TEMP = 2;
localparam int TEST_MUL_PER_FEATURE = 8;
localparam int NUM_FEATURES = 2;
localparam int NUM_EXAMPLES = 1;
localparam FEATURES_FILE = "generated/fc1_test_input.mem";
localparam TRUTH_FILE = "generated/fc1_test_truth.mem";
localparam WEIGHTS_FILE = "generated/fc1_weights.mem";
localparam OUTPUT_FILE = "generated/fc1_sim_output.txt";

initial begin
    if (MUL_PER_FEATURE <= 0) begin
        $fatal(1, "MUL_PER_FEATURE must be positive");
    end
    if (TEMP == 0) begin
        $fatal(1, "TEMP must not be zero");
    end
    if (TEMP < 0) begin
        if ((N % (-TEMP)) != 0) begin
            $fatal(1, "Negative TEMP must divide N exactly");
        end
        if (((N / (-TEMP)) % MUL_PER_FEATURE) != 0) begin
            $fatal(1, "For TEMP < 0, MUL_PER_FEATURE must divide N/(-TEMP)");
        end
    end else begin
        if ((N % MUL_PER_FEATURE) != 0) begin
            $fatal(1, "For TEMP > 0, MUL_PER_FEATURE must divide N");
        end
    end
end

logic [INPUT_PRECISION-1:0] raw_examples [N * NUM_FEATURES * NUM_EXAMPLES];
logic [INPUT_PRECISION-1:0] examples [NUM_EXAMPLES-1:0][NUM_FEATURES-1:0][N-1:0];
logic [INPUT_PRECISION-1:0] features [NUM_FEATURES-1:0][N-1:0];
logic [OUTPUT_PRECISION-1:0] out [NUM_FEATURES-1:0][M-1:0];
logic [OUTPUT_PRECISION-1:0] latched_out [NUM_FEATURES-1:0][M-1:0];
logic [OUTPUT_PRECISION-1:0] raw_truth [M * NUM_FEATURES * NUM_EXAMPLES];
logic [OUTPUT_PRECISION-1:0] truth [NUM_EXAMPLES-1:0][NUM_FEATURES-1:0][M-1:0];
logic clk = 1'b1;
logic ce = 1'b1;
logic rst = 1'b1;

integer ex;
integer fea;
integer n;
integer i;

initial begin
    $readmemh(FEATURES_FILE, raw_examples);
    $readmemh(TRUTH_FILE, raw_truth);
    for (i = 0; i < NUM_EXAMPLES * NUM_FEATURES * N; i = i + 1) begin
        ex = i / (NUM_FEATURES * N);
        fea = (i / N) % NUM_FEATURES;
        n = i % N;
        examples[ex][fea][n] = raw_examples[i];
    end
    for (i = 0; i < NUM_EXAMPLES * NUM_FEATURES * M; i = i + 1) begin
        ex = i / (NUM_FEATURES * M);
        fea = (i / M) % NUM_FEATURES;
        n = i % M;
        truth[ex][fea][n] = raw_truth[i];
    end
end

always #1 clk = ~clk;

logic out_ready;
logic out_valid;
logic in_ready;
logic in_valid;

top_module #(
    .TEMP             ( TEMP             ),
    .INPUT_PRECISION  ( INPUT_PRECISION  ),
    .WEIGHT_PRECISION ( WEIGHT_PRECISION ),
    .OUTPUT_PRECISION ( OUTPUT_PRECISION ),
    .ACC_PRECISION    ( BIAS_PRECISION   ),
    .NUM_FEATURES     ( NUM_FEATURES     ),
    .MUL_PER_FEATURE  ( TEST_MUL_PER_FEATURE ),
    .N                ( N                ),
    .M                ( M                ),
    .IN_ZP            ( IN_ZP            ),
    .W_ZP             ( W_ZP             ),
    .OUT_ZP           ( OUT_ZP           ),
    .M_MUL            ( M_MUL            ),
    .M_SHIFT          ( M_SHIFT          ),
    .MEMORY_FILE      ( WEIGHTS_FILE     )
) dut (
    .out_valid ( out_valid ),
    .in_ready  ( in_ready  ),
    .in_valid  ( in_valid  ),
    .out_ready ( out_ready ),
    .clk       ( clk       ),
    .rst       ( rst       ),
    .ce        ( ce        ),
    .features  ( features  ),
    .out       ( out       )
);

typedef enum logic [2:0] {
    LOAD,
    SEND,
    RECEIVE,
    SAVE,
    FINISHED
} state_t;

state_t state = LOAD;
logic [31:0] index = '0;

string filename;
integer file;
integer mismatch_count;
integer compare_count;

always_ff @(posedge clk) begin
    unique case (state)
        LOAD: begin
            in_valid <= 1'b0;
            out_ready <= 1'b0;
            if (index < NUM_EXAMPLES) begin
                for (int feature_load_idx = 0; feature_load_idx < NUM_FEATURES; feature_load_idx++) begin
                    for (int input_load_idx = 0; input_load_idx < N; input_load_idx++) begin
                        features[feature_load_idx][input_load_idx] <= examples[index][feature_load_idx][input_load_idx];
                    end
                end
                rst <= 1'b0;
                state <= SEND;
                index <= index + 1'b1;
            end else begin
                $display("FINISHED");
                state <= FINISHED;
            end
        end

        SEND: begin
            in_valid <= 1'b1;
            if (in_valid && in_ready) begin
                in_valid <= 1'b0;
                state <= RECEIVE;
            end
        end

        RECEIVE: begin
            out_ready <= 1'b1;
            if (out_ready && out_valid) begin
                out_ready <= 1'b0;
                for (int feature_store_idx = 0; feature_store_idx < NUM_FEATURES; feature_store_idx++) begin
                    for (int output_store_idx = 0; output_store_idx < M; output_store_idx++) begin
                        latched_out[feature_store_idx][output_store_idx] <= out[feature_store_idx][output_store_idx];
                    end
                end
                state <= SAVE;
            end
        end

        SAVE: begin
            mismatch_count = 0;
            compare_count = 0;
            for (int feature_cmp_idx = 0; feature_cmp_idx < NUM_FEATURES; feature_cmp_idx++) begin
                for (int output_cmp_idx = 0; output_cmp_idx < M; output_cmp_idx++) begin
                    compare_count = compare_count + 1;
                    if (latched_out[feature_cmp_idx][output_cmp_idx] !== truth[index - 1][feature_cmp_idx][output_cmp_idx]) begin
                        mismatch_count = mismatch_count + 1;
                        $display(
                            "MISMATCH example=%0d feature=%0d out=%0d sim=%0d truth=%0d",
                            index - 1,
                            feature_cmp_idx,
                            output_cmp_idx,
                            latched_out[feature_cmp_idx][output_cmp_idx],
                            truth[index - 1][feature_cmp_idx][output_cmp_idx]
                        );
                    end
                end
            end

            filename = OUTPUT_FILE;
            file = $fopen(filename, "w");
            if (file) begin
                for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                    for (int output_idx = 0; output_idx < M; output_idx++) begin
                        $fwrite(file, "%0d\n", latched_out[feature_idx][output_idx]);
                    end
                end
                $fclose(file);
                $display(
                    "Saved example %0d to %s (%0d/%0d matched)",
                    index - 1,
                    filename,
                    compare_count - mismatch_count,
                    compare_count
                );
            end else begin
                $display("ERROR: Could not open file %s", filename);
            end
            state <= LOAD;
        end

        FINISHED: begin
            $finish;
        end
    endcase
end

endmodule
