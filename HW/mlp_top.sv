`timescale 1ns / 1ps

module mlp_top #(
    parameter int NUM_FEATURES = 1,

    parameter int FC1_TEMP = 1,
    parameter int FC1_INPUT_PRECISION = 8,
    parameter int FC1_WEIGHT_PRECISION = 8,
    parameter int FC1_OUTPUT_PRECISION = 8,
    parameter int FC1_BIAS_PRECISION = 32,
    parameter int FC1_MUL_PER_FEATURE = 1,
    parameter int FC1_N = 784,
    parameter int FC1_M = 128,
    parameter int FC1_IN_ZP = 128,
    parameter int FC1_W_ZP = 0,
    parameter int FC1_OUT_ZP = 128,
    parameter int FC1_M_MUL = 1073741824,
    parameter int FC1_M_SHIFT = 30,
    parameter FC1_MEMORY_FILE = "generated/fc1_weights.mem",

    parameter int FC2_TEMP = 1,
    parameter int FC2_INPUT_PRECISION = 8,
    parameter int FC2_WEIGHT_PRECISION = 8,
    parameter int FC2_OUTPUT_PRECISION = 8,
    parameter int FC2_BIAS_PRECISION = 32,
    parameter int FC2_MUL_PER_FEATURE = 1,
    parameter int FC2_N = 128,
    parameter int FC2_M = 128,
    parameter int FC2_IN_ZP = 128,
    parameter int FC2_W_ZP = 0,
    parameter int FC2_OUT_ZP = 128,
    parameter int FC2_M_MUL = 1073741824,
    parameter int FC2_M_SHIFT = 30,
    parameter FC2_MEMORY_FILE = "generated/fc2_weights.mem",

    parameter int FC3_TEMP = 1,
    parameter int FC3_INPUT_PRECISION = 8,
    parameter int FC3_WEIGHT_PRECISION = 8,
    parameter int FC3_OUTPUT_PRECISION = 8,
    parameter int FC3_BIAS_PRECISION = 32,
    parameter int FC3_MUL_PER_FEATURE = 1,
    parameter int FC3_N = 128,
    parameter int FC3_M = 10,
    parameter int FC3_IN_ZP = 128,
    parameter int FC3_W_ZP = 0,
    parameter int FC3_OUT_ZP = 128,
    parameter int FC3_M_MUL = 1073741824,
    parameter int FC3_M_SHIFT = 30,
    parameter FC3_MEMORY_FILE = "generated/fc3_weights.mem"
) (
    output logic out_valid,
    output logic in_ready,
    input  logic in_valid,
    input  logic out_ready,
    input  logic clk,
    input  logic rst,
    input  logic ce,
    input  logic [FC1_INPUT_PRECISION-1:0] features [NUM_FEATURES-1:0][FC1_N-1:0],
    output logic [FC3_OUTPUT_PRECISION-1:0] out [NUM_FEATURES-1:0][FC3_M-1:0]
);

    typedef enum logic [2:0] {
        IDLE,
        FC1_SEND,
        FC1_WAIT,
        FC2_SEND,
        FC2_WAIT,
        FC3_SEND,
        FC3_WAIT,
        OUTPUT_READY
    } state_t;

    state_t state = IDLE;

    logic fc1_in_valid;
    logic fc1_in_ready;
    logic fc1_out_valid;
    logic fc1_out_ready;
    logic [FC1_OUTPUT_PRECISION-1:0] fc1_out [NUM_FEATURES-1:0][FC1_M-1:0];
    logic [FC1_OUTPUT_PRECISION-1:0] fc1_out_reg [NUM_FEATURES-1:0][FC1_M-1:0];
    logic [FC1_OUTPUT_PRECISION-1:0] relu1_wire [NUM_FEATURES-1:0][FC1_M-1:0];
    logic [FC1_OUTPUT_PRECISION-1:0] relu1_reg [NUM_FEATURES-1:0][FC1_M-1:0];

    logic fc2_in_valid;
    logic fc2_in_ready;
    logic fc2_out_valid;
    logic fc2_out_ready;
    logic [FC2_OUTPUT_PRECISION-1:0] fc2_out [NUM_FEATURES-1:0][FC2_M-1:0];
    logic [FC2_OUTPUT_PRECISION-1:0] fc2_out_reg [NUM_FEATURES-1:0][FC2_M-1:0];
    logic [FC2_OUTPUT_PRECISION-1:0] relu2_wire [NUM_FEATURES-1:0][FC2_M-1:0];
    logic [FC2_OUTPUT_PRECISION-1:0] relu2_reg [NUM_FEATURES-1:0][FC2_M-1:0];

    logic fc3_in_valid;
    logic fc3_in_ready;
    logic fc3_out_valid;
    logic fc3_out_ready;
    logic [FC3_OUTPUT_PRECISION-1:0] fc3_out [NUM_FEATURES-1:0][FC3_M-1:0];

    quant_relu #(
        .PRECISION(FC1_OUTPUT_PRECISION),
        .NUM_FEATURES(NUM_FEATURES),
        .N(FC1_M),
        .ZERO_POINT(FC1_OUT_ZP)
    ) u_relu1 (
        .data_in(fc1_out),
        .data_out(relu1_wire)
    );

    quant_relu #(
        .PRECISION(FC2_OUTPUT_PRECISION),
        .NUM_FEATURES(NUM_FEATURES),
        .N(FC2_M),
        .ZERO_POINT(FC2_OUT_ZP)
    ) u_relu2 (
        .data_in(fc2_out),
        .data_out(relu2_wire)
    );

    top_module #(
        .TEMP(FC1_TEMP),
        .INPUT_PRECISION(FC1_INPUT_PRECISION),
        .WEIGHT_PRECISION(FC1_WEIGHT_PRECISION),
        .OUTPUT_PRECISION(FC1_OUTPUT_PRECISION),
        .ACC_PRECISION(FC1_BIAS_PRECISION),
        .NUM_FEATURES(NUM_FEATURES),
        .MUL_PER_FEATURE(FC1_MUL_PER_FEATURE),
        .N(FC1_N),
        .M(FC1_M),
        .IN_ZP(FC1_IN_ZP),
        .W_ZP(FC1_W_ZP),
        .OUT_ZP(FC1_OUT_ZP),
        .M_MUL(FC1_M_MUL),
        .M_SHIFT(FC1_M_SHIFT),
        .MEMORY_FILE(FC1_MEMORY_FILE)
    ) u_fc1 (
        .out_valid(fc1_out_valid),
        .in_ready(fc1_in_ready),
        .in_valid(fc1_in_valid),
        .out_ready(fc1_out_ready),
        .clk(clk),
        .rst(rst),
        .ce(ce),
        .features(features),
        .out(fc1_out)
    );

    top_module #(
        .TEMP(FC2_TEMP),
        .INPUT_PRECISION(FC2_INPUT_PRECISION),
        .WEIGHT_PRECISION(FC2_WEIGHT_PRECISION),
        .OUTPUT_PRECISION(FC2_OUTPUT_PRECISION),
        .ACC_PRECISION(FC2_BIAS_PRECISION),
        .NUM_FEATURES(NUM_FEATURES),
        .MUL_PER_FEATURE(FC2_MUL_PER_FEATURE),
        .N(FC2_N),
        .M(FC2_M),
        .IN_ZP(FC2_IN_ZP),
        .W_ZP(FC2_W_ZP),
        .OUT_ZP(FC2_OUT_ZP),
        .M_MUL(FC2_M_MUL),
        .M_SHIFT(FC2_M_SHIFT),
        .MEMORY_FILE(FC2_MEMORY_FILE)
    ) u_fc2 (
        .out_valid(fc2_out_valid),
        .in_ready(fc2_in_ready),
        .in_valid(fc2_in_valid),
        .out_ready(fc2_out_ready),
        .clk(clk),
        .rst(rst),
        .ce(ce),
        .features(relu1_reg),
        .out(fc2_out)
    );

    top_module #(
        .TEMP(FC3_TEMP),
        .INPUT_PRECISION(FC3_INPUT_PRECISION),
        .WEIGHT_PRECISION(FC3_WEIGHT_PRECISION),
        .OUTPUT_PRECISION(FC3_OUTPUT_PRECISION),
        .ACC_PRECISION(FC3_BIAS_PRECISION),
        .NUM_FEATURES(NUM_FEATURES),
        .MUL_PER_FEATURE(FC3_MUL_PER_FEATURE),
        .N(FC3_N),
        .M(FC3_M),
        .IN_ZP(FC3_IN_ZP),
        .W_ZP(FC3_W_ZP),
        .OUT_ZP(FC3_OUT_ZP),
        .M_MUL(FC3_M_MUL),
        .M_SHIFT(FC3_M_SHIFT),
        .MEMORY_FILE(FC3_MEMORY_FILE)
    ) u_fc3 (
        .out_valid(fc3_out_valid),
        .in_ready(fc3_in_ready),
        .in_valid(fc3_in_valid),
        .out_ready(fc3_out_ready),
        .clk(clk),
        .rst(rst),
        .ce(ce),
        .features(relu2_reg),
        .out(fc3_out)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            out_valid <= 1'b0;
            in_ready <= 1'b0;
            for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                for (int fc1_idx = 0; fc1_idx < FC1_M; fc1_idx++) begin
                    fc1_out_reg[feature_idx][fc1_idx] <= '0;
                    relu1_reg[feature_idx][fc1_idx] <= '0;
                end
                for (int fc2_idx = 0; fc2_idx < FC2_M; fc2_idx++) begin
                    fc2_out_reg[feature_idx][fc2_idx] <= '0;
                    relu2_reg[feature_idx][fc2_idx] <= '0;
                end
                for (int fc3_idx = 0; fc3_idx < FC3_M; fc3_idx++) begin
                    out[feature_idx][fc3_idx] <= '0;
                end
            end
        end else if (ce) begin
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    in_ready <= 1'b1;
                    if (in_valid) begin
                        in_ready <= 1'b0;
                        state <= FC1_SEND;
                    end
                end

                FC1_SEND: begin
                    if (fc1_in_valid && fc1_in_ready) begin
                        state <= FC1_WAIT;
                    end
                end

                FC1_WAIT: begin
                    if (fc1_out_valid && fc1_out_ready) begin
                        for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                            for (int output_idx = 0; output_idx < FC1_M; output_idx++) begin
                                fc1_out_reg[feature_idx][output_idx] <= fc1_out[feature_idx][output_idx];
                                relu1_reg[feature_idx][output_idx] <= relu1_wire[feature_idx][output_idx];
                            end
                        end
                        state <= FC2_SEND;
                    end
                end

                FC2_SEND: begin
                    if (fc2_in_valid && fc2_in_ready) begin
                        state <= FC2_WAIT;
                    end
                end

                FC2_WAIT: begin
                    if (fc2_out_valid && fc2_out_ready) begin
                        for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                            for (int output_idx = 0; output_idx < FC2_M; output_idx++) begin
                                fc2_out_reg[feature_idx][output_idx] <= fc2_out[feature_idx][output_idx];
                                relu2_reg[feature_idx][output_idx] <= relu2_wire[feature_idx][output_idx];
                            end
                        end
                        state <= FC3_SEND;
                    end
                end

                FC3_SEND: begin
                    if (fc3_in_valid && fc3_in_ready) begin
                        state <= FC3_WAIT;
                    end
                end

                FC3_WAIT: begin
                    if (fc3_out_valid && fc3_out_ready) begin
                        for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                            for (int output_idx = 0; output_idx < FC3_M; output_idx++) begin
                                out[feature_idx][output_idx] <= fc3_out[feature_idx][output_idx];
                            end
                        end
                        out_valid <= 1'b1;
                        state <= OUTPUT_READY;
                    end
                end

                OUTPUT_READY: begin
                    if (out_ready) begin
                        out_valid <= 1'b0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    always_comb begin
        fc1_in_valid = 1'b0;
        fc1_out_ready = 1'b0;
        fc2_in_valid = 1'b0;
        fc2_out_ready = 1'b0;
        fc3_in_valid = 1'b0;
        fc3_out_ready = 1'b0;

        case (state)
            FC1_SEND: begin
                fc1_in_valid = 1'b1;
            end
            FC1_WAIT: begin
                fc1_out_ready = 1'b1;
            end
            FC2_SEND: begin
                fc2_in_valid = 1'b1;
            end
            FC2_WAIT: begin
                fc2_out_ready = 1'b1;
            end
            FC3_SEND: begin
                fc3_in_valid = 1'b1;
            end
            FC3_WAIT: begin
                fc3_out_ready = 1'b1;
            end
            default: begin
            end
        endcase
    end

endmodule
