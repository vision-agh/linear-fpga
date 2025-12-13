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
    input  logic [PRECISION-1:0] features [NUM_FEATURES][N],
    output logic [PRECISION-1:0] out [NUM_FEATURES][N]
);

    localparam int BramWidth = WIDTH*N+WIDTH_B;

    typedef enum logic {
        IDLE,
        RUNNING,
        OUT
    } state_t;

    state_t state;

    logic [PRECISION-1:0] latched_features [NUM_FEATURES][N];

    logic [WIDTH_B-1:0] acc [NUM_FEATURES][M];
    logic [WIDTH_B-1:0] ai [NUM_FEATURES];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            unique case(state)
                IDLE: begin
                    in_ready <= 1;
                    if (in_valid)  begin
                        latched_features <= features;
                        state <= RUNNING;
                    end
                end

                RUNNING: begin
                    in_ready <= 0;
                    // HW team;
                end

                OUT: begin
                    out_valid <= 1;
                    if (out_ready) begin
                        state <= IDLE;
                    end
                end
            endcase;
         end
      end

endmodule
