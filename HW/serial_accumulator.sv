`timescale 1ns / 1ps
module serial_accumulator #(
    parameter int PRECISION              = 64,
    parameter int TEMP                   = 2,
    parameter int INITIAL_LATENCY        = 4,
    parameter int NUM_FEATURES           = 1, // number of parallel features
    parameter int M                      = 6
) (
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      clr,
    input  logic                      ce,     
    input  logic signed [PRECISION-1:0] features [NUM_FEATURES-1:0],
    output logic signed [PRECISION-1:0] out      [NUM_FEATURES-1:0][M-1:0],
    output logic                      acc_done    
);

    typedef enum logic [1:0] {
        LATENCY,
        ACCUMULATING,
        IDLE
    } state_t;
    
    state_t state = LATENCY;

    localparam int LATENCY_LAST = (INITIAL_LATENCY > 1) ? (INITIAL_LATENCY - 2) : 0;

    logic [$clog2(INITIAL_LATENCY):0] count = 0;
    logic [$clog2(M)+1:0] bucket_count = 0;
    logic [$clog2(TEMP):0] segment_count = 0;
    logic signed [PRECISION-1:0] accumulator [NUM_FEATURES-1:0][M-1:0];
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count         <= 0;
            bucket_count  <= 0;
            segment_count <= 0;
            for (int reset_feature_idx = 0; reset_feature_idx < NUM_FEATURES; reset_feature_idx++) begin
                for (int reset_bucket_idx = 0; reset_bucket_idx < M; reset_bucket_idx++) begin
                    accumulator[reset_feature_idx][reset_bucket_idx] <= '0;
                end
            end
            state         <= LATENCY;
            acc_done      <= 0;
        end  else if (clr) begin
            count         <= 0;
            bucket_count  <= 0;
            segment_count <= 0;
            for (int clr_feature_idx = 0; clr_feature_idx < NUM_FEATURES; clr_feature_idx++) begin
                for (int clr_bucket_idx = 0; clr_bucket_idx < M; clr_bucket_idx++) begin
                    accumulator[clr_feature_idx][clr_bucket_idx] <= '0;
                end
            end
            state         <= LATENCY;
            acc_done      <= 0;
        end else begin
            if (ce) begin
                 case (state)
                    LATENCY: begin
                        if (count < LATENCY_LAST) begin
                            state <= LATENCY;
                            count <= count + 1;  
                        end else begin
                            state <= ACCUMULATING;
                            count <= 0;
                        end
                    end
                    ACCUMULATING: begin
                        state <= ACCUMULATING;
                        for(int i=0; i<NUM_FEATURES; i++) begin
                            accumulator[i][bucket_count] += features[i];
                        end
                        if(bucket_count < M-1)
                            bucket_count <= bucket_count + 1;
                        else begin
                            if(segment_count == TEMP-1) begin
                                for(int i=0; i<NUM_FEATURES; i++) begin
                                    for(int j=0; j<M; j++) begin
                                        out[i][j] <= accumulator[i][j];
                                    end
                                end
                                state <= IDLE;
                                acc_done <= 1;
                            end else begin
                                bucket_count <= 0;
                                segment_count <= segment_count+1;
                            end
                        end
                    end
                    IDLE: begin
                        acc_done <= 0;
                    end
                 endcase
            end 
        end
    end

endmodule
