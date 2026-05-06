`timescale 1ns / 1ps

module serial_data_scheduler #(
    parameter int PRECISION    = 8,
    parameter int TEMP         = 4,
    parameter int NUM_FEATURES = 2,
    parameter int N            = 16
) (
    input  logic [$clog2(TEMP)-1:0]               slice_index,
    input  logic [PRECISION-1:0]                  features        [NUM_FEATURES-1:0][N-1:0],
    output logic [PRECISION-1:0]                  features_sliced [NUM_FEATURES-1:0][N / TEMP - 1:0]
);

    localparam int CHUNK_WIDTH = N / TEMP;

    always_comb begin
        for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
            for (int chunk_idx = 0; chunk_idx < CHUNK_WIDTH; chunk_idx++) begin
                features_sliced[feature_idx][chunk_idx] =
                    features[feature_idx][slice_index * CHUNK_WIDTH + chunk_idx];
            end
        end
    end

endmodule
