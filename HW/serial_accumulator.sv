`timescale 1ns / 1ps
module serial_accumulator #(
    parameter int PRECISION              = 8,
    parameter int BIAS_PRECISION         = 32,
    parameter int TEMP                   = 2,
    parameter int INITIAL_LATENCY        = 4,
    parameter int NUM_FEATURES           = 1, // number of parallel features
    parameter int M                      = 6
) (
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      clr,
    input  logic                      ce,     
    input  logic [PRECISION-1:0]      features   [NUM_FEATURES-1:0],
    output logic [PRECISION-1:0]      out        [NUM_FEATURES-1:0][M-1:0],
    output logic                      acc_done    
);

    typedef enum logic [1:0] {
        LATENCY,
        ACCUMULATING,
        IDLE
    } state_t;
    
    state_t state = LATENCY;

    logic [$clog2(INITIAL_LATENCY):0] count = 0;
    logic [$clog2(M)+1:0] bucket_count = 0;
    logic [$clog2(TEMP):0] segment_count = 0;
    logic signed [BIAS_PRECISION-1:0] accumulator [NUM_FEATURES-1:0][M-1:0];
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count         <= 0;
            bucket_count  <= 0;
            segment_count <= 0;
            accumulator   <= '{default:0};
            state         <= LATENCY;
            acc_done      <= 0;
        end  else if (clr) begin
            count         <= 0;
            bucket_count  <= 0;
            segment_count <= 0;
            accumulator   <= '{default:0};
            state         <= LATENCY;
            acc_done      <= 0;
        end else begin
            if (ce) begin
                 case (state)
                    LATENCY: begin
                        if (count < INITIAL_LATENCY) begin
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
                                        if(accumulator[i][M-1-j]>255)
                                             out[i][j] <= 255;
                                        else if(accumulator[i][M-1-j]<0)
                                            out[i][j] <= 0;
                                        else
                                            out[i][j] <= accumulator[i][M-1-j][PRECISION-1:0];
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
