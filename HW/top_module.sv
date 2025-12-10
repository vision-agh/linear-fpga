module top_module #(
    parameter int PRECISION   = 8,
    parameter int BIAS_PRECISION = 32,
    parameter int NUM_FEATURES = 2, //number of parallel features
    parameter int N = 10,
    parameter int M = 12,
    parameter in  M_MUL = 12345,
    parameter in  Z_WEIGHTS = 5
) (
    output logic                           out_valid,
    output logic                           in_ready,
    input  logic                           in_valid,
    input  logic                           out_ready,
    input  logic                           clk,
    input  logic                           rst,
    input  logic                           ce,
    input  logic [NUM_FEATURES-1:0][N-1:0][PRECISION-1:0] features,
    output logic [NUM_FEATURES-1:0][M-1:0][PRECISION-1:0] out 
);

    localparam int BRAM_WIDTH = WIDTH*N+WIDTH_B;

    typedef enum logic {
        IDLE,
        RUNNING,
        OUT
    } t_state;
     
    t_state state;

    logic [NUM_FEATURES-1:0][N-1:0][PRECISION-1:0] latched_features,
    
    logic [NUM_FEATURES-1:0][M-1:0][WIDTH_B-1:0]   acc ;
    logic [NUM_FEATURES-1:0][WIDTH_B-1:0]          ai ;
    
    always_ff @(posedge clk or posedge rst) begin    
        if (rst) begin
            state <= IDLE;
        end else begin
            case(state)
                IDLE: begin
                    in_ready = 1;
                    if (in_valid)  begin
                        latched_features = features;
                        state = RUNNING;
                    end
                end
                
                RUNNING: begin
                    in_ready = 0;
                    // HW team;
                end  
                
                OUT: begin
                    out_valid = 1;
                    if (out_ready) begin
                        state = IDLE;
                    end
                end  
            endcase;
         end
      end
            
endmodule
