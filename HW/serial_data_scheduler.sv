`timescale 1ns / 1ps

module serial_data_scheduler #(
    parameter int PRECISION              = 8,
    parameter int TEMP                   = 4,
    parameter int BIAS_PRECISION         = 32,
    parameter int NUM_FEATURES           = 2, // number of parallel features
    parameter int N                      = 16,
    parameter int M                      = 8
) (
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      ce,
    input  logic                      ctrl,
    input  logic [PRECISION-1:0]      features        [NUM_FEATURES-1:0][N-1:0],
    output logic [PRECISION-1:0]      features_sliced [NUM_FEATURES-1:0][N/TEMP-1:0]
);

    localparam int WAIT_LENGTH = M-1;

    typedef enum logic [1:0] {
        IDLE,
        SLICE,
        WAITING
    } state_t;

    state_t state = IDLE;
    
    logic [$clog2(TEMP):0] counter_slice;
    logic [$clog2(WAIT_LENGTH):0] counter_wait;
  
    always_ff @(posedge clk) begin
        if(rst) begin
            counter_slice <= 0;
            counter_wait  <= 0;
            for (int feature_idx = 0; feature_idx < NUM_FEATURES; feature_idx++) begin
                for (int slice_idx = 0; slice_idx < N / TEMP; slice_idx++) begin
                    features_sliced[feature_idx][slice_idx] <= '0;
                end
            end
            state         <= IDLE;
        end else
            if(ce) begin
                  unique case(state) 
                    IDLE:  begin
                        counter_slice <= 0;
                        counter_wait <= 0; 
                        if(ctrl == 1)
                            state <= SLICE;
                        else
                            state <= IDLE;
                    end
                    SLICE: begin
                        for(int i=0; i<NUM_FEATURES; i++) begin
                            for (int j = 0; j < N / TEMP; j++) begin
                                features_sliced[i][j] <= features[i][counter_slice * (N / TEMP) + j];
                            end
                        end
                        state <= WAITING;
                    end
                    WAITING: begin 
                        counter_wait++;
                        if(counter_wait == WAIT_LENGTH) begin
                            if(counter_slice == TEMP-1) begin
                                state <= IDLE;
                                counter_slice <= 0;
                            end else begin 
                                counter_slice++;
                                counter_wait <= 0;
                                state <= SLICE;
                            end
                        end
                    end
                 endcase
           end
       end
    

endmodule
