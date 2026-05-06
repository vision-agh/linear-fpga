`timescale 1ns / 1ps

module serial_accumulator #(
    parameter int PRECISION    = 64,
    parameter int NUM_FEATURES = 1,
    parameter int M            = 6
) (
    input  logic                                   clk,
    input  logic                                   rst,
    input  logic                                   clr,
    input  logic                                   ce,
    input  logic                                   value_valid,
    input  logic                                   value_first,
    input  logic                                   value_last,
    input  logic [$clog2(M)-1:0]                   value_index,
    input  logic signed [PRECISION-1:0]            features [NUM_FEATURES-1:0],
    output logic                                   out_valid,
    output logic                                   layer_done,
    output logic [$clog2(M)-1:0]                   out_index,
    output logic signed [PRECISION-1:0]            out_features [NUM_FEATURES-1:0]
);

    logic signed [PRECISION-1:0] running_acc [NUM_FEATURES-1:0];
    logic signed [PRECISION-1:0] next_running_acc [NUM_FEATURES-1:0];
    logic signed [PRECISION-1:0] next_out_features [NUM_FEATURES-1:0];
    logic next_out_valid;
    logic next_layer_done;
    logic [$clog2(M)-1:0] next_out_index;

    always_comb begin
        next_out_valid = 1'b0;
        next_layer_done = 1'b0;
        next_out_index = out_index;

        for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
            next_running_acc[feature_idx] = running_acc[feature_idx];
            next_out_features[feature_idx] = out_features[feature_idx];
        end

        if (value_valid) begin
            next_out_index = value_index;
            for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                if (value_first) begin
                    next_running_acc[feature_idx] = features[feature_idx];
                end else begin
                    next_running_acc[feature_idx] = running_acc[feature_idx] + features[feature_idx];
                end

                if (value_last) begin
                    next_out_features[feature_idx] = next_running_acc[feature_idx];
                end
            end

            if (value_last) begin
                next_out_valid = 1'b1;
                next_layer_done = (value_index == M - 1);
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            out_valid <= 1'b0;
            layer_done <= 1'b0;
            out_index <= '0;
            for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                running_acc[feature_idx] <= '0;
                out_features[feature_idx] <= '0;
            end
        end else if (clr) begin
            out_valid <= 1'b0;
            layer_done <= 1'b0;
            out_index <= '0;
            for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                running_acc[feature_idx] <= '0;
                out_features[feature_idx] <= '0;
            end
        end else if (ce) begin
            out_valid <= next_out_valid;
            layer_done <= next_layer_done;
            out_index <= next_out_index;
            for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                running_acc[feature_idx] <= next_running_acc[feature_idx];
                out_features[feature_idx] <= next_out_features[feature_idx];
            end
        end
    end

endmodule
