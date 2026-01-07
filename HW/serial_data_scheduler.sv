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


    typedef enum logic [1:0] {
        IDLE,
        SLICE,
        WAITING
    } state_t;

    state_t state = IDLE;
    
    logic [$clog2(TEMP):0] counter_slice;
    logic [$clog2(WAIT_LENGTH):0] counter_wait;
    
    parameter int WAIT_LENGTH = M-1;
  
    always_ff @(posedge clk) begin
        if(rst) begin
            counter_slice <= TEMP-1;
            counter_wait  <= 0;
            features_sliced <= '{default:0};
            state         <= IDLE;
        end else
            if(ce) begin
                  unique case(state) 
                    IDLE:  begin
                        counter_slice <= TEMP-1;
                        counter_wait <= 0; 
                        if(ctrl == 1)
                            state <= SLICE;
                        else
                            state <= IDLE;
                    end
                    SLICE: begin
                        for(int i=0; i<NUM_FEATURES; i++) begin
                            features_sliced[i] <= features[i][counter_slice*N/TEMP+:N/TEMP];
                        end
                        state <= WAITING;
                    end
                    WAITING: begin 
                        counter_wait++;
                        if(counter_wait == WAIT_LENGTH) begin
                            if(counter_slice == 0) begin
                                state <= IDLE;
                                counter_slice <= TEMP-1;
                            end else begin 
                                counter_slice--;
                                counter_wait <= 0;
                                state <= SLICE;
                            end
                        end
                    end
                 endcase
           end
       end
    

endmodule
