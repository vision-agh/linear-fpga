`timescale 1ns / 1ps

module delay_buffer_2d #(
    parameter NUM_FEATURES = 4,
    parameter N            = 4,
    parameter PRECISION    = 4,
    parameter DELAY        = 1
)(
    input          clk,
    input  [PRECISION-1:0] idata [NUM_FEATURES-1:0][N-1:0],
    output [PRECISION-1:0] odata [NUM_FEATURES-1:0][N-1:0]
);
    parameter int I_DELAY = DELAY + 1;
    logic [PRECISION-1:0] r_idata [I_DELAY-1:0][NUM_FEATURES-1:0][N-1:0];
    
    always_ff @(posedge clk) begin
        for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
            for (int col = 0; col < N; col++) begin
                r_idata[0][feature_idx][col] <= idata[feature_idx][col];
            end
        end
        for (int delay_idx = 1; delay_idx < I_DELAY; delay_idx++) begin
            for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                for (int col = 0; col < N; col++) begin
                    r_idata[delay_idx][feature_idx][col] <= r_idata[delay_idx-1][feature_idx][col];
                end
            end
        end
    end 
    
    generate
        genvar out_feature_idx, out_col_idx;
        for (out_feature_idx = 0; out_feature_idx < NUM_FEATURES; out_feature_idx++) begin : gen_odata_feature
            for (out_col_idx = 0; out_col_idx < N; out_col_idx++) begin : gen_odata_col
                assign odata[out_feature_idx][out_col_idx] = r_idata[I_DELAY-1][out_feature_idx][out_col_idx];
            end
        end
    endgenerate
    
endmodule
