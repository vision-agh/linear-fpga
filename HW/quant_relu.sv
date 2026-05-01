`timescale 1ns / 1ps

module quant_relu #(
    parameter int PRECISION = 8,
    parameter int NUM_FEATURES = 1,
    parameter int N = 1,
    parameter int ZERO_POINT = 0
) (
    input  logic [PRECISION-1:0] data_in [NUM_FEATURES-1:0][N-1:0],
    output logic [PRECISION-1:0] data_out [NUM_FEATURES-1:0][N-1:0]
);

    always_comb begin
        for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
            for (int value_idx = 0; value_idx < N; value_idx++) begin
                if (data_in[feature_idx][value_idx] < ZERO_POINT[PRECISION-1:0]) begin
                    data_out[feature_idx][value_idx] = ZERO_POINT[PRECISION-1:0];
                end else begin
                    data_out[feature_idx][value_idx] = data_in[feature_idx][value_idx];
                end
            end
        end
    end

endmodule
