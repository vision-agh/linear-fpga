`timescale 1ns / 1ps

module top_module #(
    parameter int TEMP                   = 1,
    parameter int INPUT_PRECISION        = 8,
    parameter int WEIGHT_PRECISION       = 8,
    parameter int OUTPUT_PRECISION       = 8,
    parameter int ACC_PRECISION          = 32,
    parameter int NUM_FEATURES           = 2,
    parameter int MUL_PER_FEATURE        = 2,
    parameter int N                      = 12,
    parameter int M                      = 32,
    parameter int IN_ZP                  = 128,
    parameter int W_ZP                   = 0,
    parameter int OUT_ZP                 = 128,
    parameter int M_MUL                  = 1073741824,
    parameter int M_SHIFT                = 30,
    parameter MEMORY_FILE                = "generated/fc1_weights.mem"
) (
    output logic                            out_valid,
    output logic                            in_ready,
    input  logic                            in_valid,
    input  logic                            out_ready,
    input  logic                            clk,
    input  logic                            rst,
    input  logic                            ce,
    input  logic [INPUT_PRECISION-1:0]      features [NUM_FEATURES-1:0][N-1:0],
    output logic [OUTPUT_PRECISION-1:0]     out [NUM_FEATURES-1:0][M-1:0]
);

    localparam int INITIAL_LATENCY = 5;
    localparam int SERIAL_SPLIT = (TEMP < 0) ? -TEMP : 1;
    localparam int PARALLEL_SPLIT = (TEMP > 1) ? TEMP : 1;

    logic memory_clr;
    logic buffer_clr;
    logic burst_complete;

    logic [INPUT_PRECISION-1:0] latched_features [NUM_FEATURES-1:0][N-1:0];
    logic [OUTPUT_PRECISION-1:0] r_out_buffer [NUM_FEATURES-1:0][M-1:0];

    typedef enum logic [1:0] {
        IDLE,
        RUNNING,
        WAIT_OUTPUT_STAGE,
        OUTPUT_READY
    } state_t;

    state_t state = IDLE;

    generate
        if (TEMP < 0) begin : gen_serial_mode
            localparam int SERIAL_N = N / SERIAL_SPLIT;
            localparam int BRAM_WIDTH = WEIGHT_PRECISION * SERIAL_N + ACC_PRECISION;
            localparam int SERIAL_OUTPUT_STAGE_PRECISION = ACC_PRECISION * 2;

            logic [WEIGHT_PRECISION-1:0] weights_serial [SERIAL_N-1:0];
            logic signed [ACC_PRECISION-1:0] bias_serial;
            logic [INPUT_PRECISION-1:0] features_sliced [NUM_FEATURES-1:0][SERIAL_N-1:0];
            logic [OUTPUT_PRECISION-1:0] r_out_mult_serial [NUM_FEATURES-1:0];
            logic signed [SERIAL_OUTPUT_STAGE_PRECISION-1:0] corrected_acc_serial [NUM_FEATURES-1:0];
            logic signed [SERIAL_OUTPUT_STAGE_PRECISION-1:0] corrected_acc_buffer [NUM_FEATURES-1:0][M-1:0];
            logic [OUTPUT_PRECISION-1:0] serial_out_buffer [NUM_FEATURES-1:0][M-1:0];

            serial_memory_fetcher #(
                .BRAM_WIDTH       ( BRAM_WIDTH       ),
                .TEMP             ( SERIAL_SPLIT     ),
                .M                ( M                ),
                .N                ( N                ),
                .BIAS_PRECISION   ( ACC_PRECISION    ),
                .WEIGHT_PRECISION ( WEIGHT_PRECISION ),
                .MEMORY_FILE      ( MEMORY_FILE      )
            ) u_serial_memory_fetcher (
                .clk      ( clk            ),
                .clr      ( memory_clr     ),
                .ce       ( ce             ),
                .data_out ( weights_serial ),
                .bias     ( bias_serial    )
            );

            multiplier_top #(
                .INPUT_PRECISION        ( INPUT_PRECISION        ),
                .WEIGHT_PRECISION       ( WEIGHT_PRECISION       ),
                .OUTPUT_PRECISION       ( OUTPUT_PRECISION       ),
                .ACC_PRECISION          ( ACC_PRECISION          ),
                .OUTPUT_STAGE_PRECISION ( SERIAL_OUTPUT_STAGE_PRECISION ),
                .NUM_FEATURES           ( NUM_FEATURES           ),
                .MUL_PER_FEATURE        ( MUL_PER_FEATURE        ),
                .N                      ( SERIAL_N               ),
                .IN_ZP                  ( IN_ZP                  ),
                .W_ZP                   ( W_ZP                   ),
                .OUT_ZP                 ( OUT_ZP                 ),
                .M_MUL                  ( M_MUL                  ),
                .M_SHIFT                ( M_SHIFT                )
            ) u_multiplier_top (
                .clk        ( clk              ),
                .rst        ( rst              ),
                .ce         ( ce               ),
                .bias       ( bias_serial      ),
                .weights_in ( weights_serial   ),
                .features   ( features_sliced  ),
                .out        ( r_out_mult_serial ),
                .corrected_acc_out ( corrected_acc_serial )
            );

            serial_accumulator #(
                .PRECISION       ( SERIAL_OUTPUT_STAGE_PRECISION ),
                .TEMP            ( SERIAL_SPLIT     ),
                .INITIAL_LATENCY ( INITIAL_LATENCY  ),
                .NUM_FEATURES    ( NUM_FEATURES     ),
                .M               ( M                )
            ) u_serial_accumulator (
                .clk      ( clk               ),
                .rst      ( rst               ),
                .clr      ( buffer_clr        ),
                .ce       ( ce                ),
                .features ( corrected_acc_serial ),
                .out      ( corrected_acc_buffer ),
                .acc_done ( burst_complete    )
            );

            serial_data_scheduler #(
                .PRECISION    ( INPUT_PRECISION ),
                .TEMP         ( SERIAL_SPLIT    ),
                .NUM_FEATURES ( NUM_FEATURES    ),
                .N            ( N               ),
                .M            ( M               )
            ) u_serial_data_scheduler (
                .clk             ( clk              ),
                .rst             ( rst              ),
                .ce              ( ce               ),
                .ctrl            ( in_valid         ),
                .features        ( latched_features ),
                .features_sliced ( features_sliced  )
            );

            for (genvar serial_feature_idx = 0; serial_feature_idx < NUM_FEATURES; serial_feature_idx++) begin : gen_serial_feature_outputs
                for (genvar serial_out_idx = 0; serial_out_idx < M; serial_out_idx++) begin : gen_serial_output_stage
                    output_stage #(
                        .INPUT_PRECISION        ( INPUT_PRECISION        ),
                        .OUTPUT_PRECISION       ( OUTPUT_PRECISION       ),
                        .ACC_PRECISION          ( ACC_PRECISION          ),
                        .OUTPUT_STAGE_PRECISION ( SERIAL_OUTPUT_STAGE_PRECISION ),
                        .IN_ZP                  ( IN_ZP                  ),
                        .W_ZP                   ( W_ZP                   ),
                        .N                      ( N                      ),
                        .OUT_ZP                 ( OUT_ZP                 ),
                        .M_MUL                  ( M_MUL                  ),
                        .M_SHIFT                ( M_SHIFT                ),
                        .USE_DIRECT_CORRECTED_ACC ( 1'b1                )
                    ) u_output_stage (
                        .clk              ( clk ),
                        .rst              ( rst ),
                        .ce               ( ce ),
                        .weight_sum       ( '0 ),
                        .feature_sum      ( '0 ),
                        .mac_acc          ( '0 ),
                        .bias             ( '0 ),
                        .corrected_acc_in ( corrected_acc_buffer[serial_feature_idx][serial_out_idx] ),
                        .corrected_acc_out( ),
                        .out              ( serial_out_buffer[serial_feature_idx][serial_out_idx] )
                    );

                    assign r_out_buffer[serial_feature_idx][serial_out_idx] =
                        serial_out_buffer[serial_feature_idx][serial_out_idx];
                end
            end
        end else begin : gen_feature_parallel_mode
            localparam int BRAM_WIDTH = WEIGHT_PRECISION * N + ACC_PRECISION;

            logic [WEIGHT_PRECISION-1:0] weights_single [N-1:0];
            logic signed [ACC_PRECISION-1:0] bias_single;
            logic [OUTPUT_PRECISION-1:0] r_out_mult [NUM_FEATURES-1:0];
            logic [NUM_FEATURES-1:0] burst_complete_single;

            memory_fetcher #(
                .BRAM_WIDTH       ( BRAM_WIDTH       ),
                .M                ( M                ),
                .N                ( N                ),
                .BIAS_PRECISION   ( ACC_PRECISION    ),
                .WEIGHT_PRECISION ( WEIGHT_PRECISION ),
                .MEMORY_FILE      ( MEMORY_FILE      )
            ) u_memory_fetcher (
                .clk      ( clk            ),
                .clr      ( memory_clr     ),
                .ce       ( ce             ),
                .data_out ( weights_single ),
                .bias     ( bias_single    )
            );

            multiplier_top #(
                .INPUT_PRECISION        ( INPUT_PRECISION   ),
                .WEIGHT_PRECISION       ( WEIGHT_PRECISION  ),
                .OUTPUT_PRECISION       ( OUTPUT_PRECISION  ),
                .ACC_PRECISION          ( ACC_PRECISION     ),
                .OUTPUT_STAGE_PRECISION ( ACC_PRECISION * 2 ),
                .NUM_FEATURES           ( NUM_FEATURES      ),
                .MUL_PER_FEATURE        ( MUL_PER_FEATURE   ),
                .N                      ( N                 ),
                .IN_ZP                  ( IN_ZP             ),
                .W_ZP                   ( W_ZP              ),
                .OUT_ZP                 ( OUT_ZP            ),
                .M_MUL                  ( M_MUL             ),
                .M_SHIFT                ( M_SHIFT           )
            ) u_multiplier_top (
                .clk        ( clk              ),
                .rst        ( rst              ),
                .ce         ( ce               ),
                .bias       ( bias_single      ),
                .weights_in ( weights_single   ),
                .features   ( latched_features ),
                .out        ( r_out_mult       ),
                .corrected_acc_out ( )
            );

            genvar feature_idx;
            for (feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin : gen_single_burst
                logic [OUTPUT_PRECISION-1:0] feature_buffer_out [M-1:0];

                burst_buffer #(
                    .INITIAL_LATENCY ( INITIAL_LATENCY  ),
                    .M               ( M                ),
                    .PRECISION       ( OUTPUT_PRECISION )
                ) u_burst_buffer (
                    .clk            ( clk                  ),
                    .clr            ( buffer_clr           ),
                    .ce             ( ce                   ),
                    .data_in        ( r_out_mult[feature_idx] ),
                    .data_out       ( feature_buffer_out   ),
                    .burst_complete ( burst_complete_single[feature_idx] )
                );

                for (genvar feature_out_idx = 0; feature_out_idx < M; feature_out_idx++) begin : gen_feature_out_copy
                    assign r_out_buffer[feature_idx][feature_out_idx] = feature_buffer_out[feature_out_idx];
                end
            end

            assign burst_complete = &burst_complete_single;
        end
    endgenerate

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            memory_clr <= 1'b1;
            buffer_clr <= 1'b1;
            out_valid  <= 1'b0;
            in_ready   <= 1'b0;
            for (int feature_reset_idx = 0; feature_reset_idx < NUM_FEATURES; feature_reset_idx++) begin
                for (int output_reset_idx = 0; output_reset_idx < M; output_reset_idx++) begin
                    out[feature_reset_idx][output_reset_idx] <= '0;
                end
            end
        end else begin
            unique case (state)
                IDLE: begin
                    out_valid  <= 1'b0;
                    in_ready   <= 1'b1;
                    memory_clr <= 1'b1;
                    buffer_clr <= 1'b1;
                    if (in_valid) begin
                        for (int feature_latch_idx = 0; feature_latch_idx < NUM_FEATURES; feature_latch_idx++) begin
                            for (int input_latch_idx = 0; input_latch_idx < N; input_latch_idx++) begin
                                latched_features[feature_latch_idx][input_latch_idx] <= features[feature_latch_idx][input_latch_idx];
                            end
                        end
                        memory_clr <= 1'b0;
                        buffer_clr <= 1'b0;
                        state <= RUNNING;
                    end
                end

                RUNNING: begin
                    in_ready <= 1'b0;
                    if (burst_complete) begin
                        memory_clr <= 1'b1;
                        buffer_clr <= 1'b1;
                        if (TEMP < 0) begin
                            state <= WAIT_OUTPUT_STAGE;
                        end else begin
                            state <= OUTPUT_READY;
                        end
                    end
                end

                WAIT_OUTPUT_STAGE: begin
                    state <= OUTPUT_READY;
                end

                OUTPUT_READY: begin
                    out_valid <= 1'b1;
                    for (int feature_out_idx = 0; feature_out_idx < NUM_FEATURES; feature_out_idx++) begin
                        for (int output_out_idx = 0; output_out_idx < M; output_out_idx++) begin
                            out[feature_out_idx][output_out_idx] <= r_out_buffer[feature_out_idx][output_out_idx];
                        end
                    end
                    if (out_ready) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
