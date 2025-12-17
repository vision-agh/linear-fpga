module top_module #(
    parameter int PRECISION       = 8,
    parameter int BIAS_PRECISION  = 32,
    parameter int NUM_FEATURES    = 2,          // number of parallel features
    parameter int MUL_PER_FEATURE = 4,          // number of multiplier instantiations per feature
    parameter int N               = 4,          // elements of feature
    parameter int M               = 4,          // elements of output
    parameter int M_MUL           = 2094967296, // multiplier constant needed to calculate pseudo-float number
    parameter int Z_WEIGHTS       = 5           // zero point of weights
) (
    output logic                 out_valid,
    output logic                 in_ready,
    input  logic                 in_valid,
    input  logic                 out_ready,
    input  logic                 clk,
    input  logic                 rst,
    input  logic                 ce,
    input  logic [PRECISION-1:0] features [NUM_FEATURES-1:0][N-1:0],
    output logic [PRECISION-1:0] out      [NUM_FEATURES-1:0][M-1:0]
);

    localparam int BRAM_WIDTH      = PRECISION*N + BIAS_PRECISION;
    localparam int INITIAL_LATENCY = 4; // latency needed for burst_buffer to skip thrash data
    
    logic memory_clr;
    logic buffer_clr;
    logic burst_complete;
    
    logic [PRECISION-1:0] weights_in       [N-1:0];
    logic [PRECISION-1:0] latched_features [NUM_FEATURES-1:0][N-1:0];
    
    logic [PRECISION-1:0] r_out_mult [NUM_FEATURES-1:0];
    logic [PRECISION-1:0] r_out_top  [NUM_FEATURES-1:0][M-1:0];
    
    logic [BIAS_PRECISION-1:0] bias;

    typedef enum logic [1:0] {
        IDLE,
        RUNNING,
        OUT
    } state_t;

    state_t state;
    
    multiplier_top #(
        .PRECISION              ( PRECISION        ),
        .BIAS_PRECISION         ( BIAS_PRECISION   ),
        .OUTPUT_STAGE_PRECISION ( BIAS_PRECISION*2 ),
        .NUM_FEATURES           ( NUM_FEATURES     ),
        .MUL_PER_FEATURE        ( MUL_PER_FEATURE  ),
        .N                      ( N                ),
        .M_MUL                  ( M_MUL            ),
        .Z_WEIGHTS              ( Z_WEIGHTS        )
    ) u_multiplier_top (
        .clk        ( clk              ),
        .rst        ( rst              ),
        .ce         ( ce               ),
        .bias       ( bias             ),     
        .weights_in ( weights_in       ),
        .features   ( latched_features ),
        .out        ( r_out_mult       )
    );
    
    memory_fetcher #(
        .BRAM_WIDTH     ( BRAM_WIDTH     ),
        .M              ( M              ),
        .N              ( N              ),
        .BIAS_PRECISION ( BIAS_PRECISION ),
        .PRECISION      ( PRECISION      )
    ) u_memory_fetcher (
        .clk      ( clk        ),
        .clr      ( memory_clr ),
        .ce       ( ce         ),
        .data_out ( weights_in ),
        .bias     ( bias       )
    );
    
    genvar i;
    for(i=0; i<NUM_FEATURES; i++) begin
        burst_buffer #(
            .INITIAL_LATENCY ( INITIAL_LATENCY ),
            .M               ( M               ),
            .PRECISION       ( PRECISION       )
        ) u_burst_buffer (
            .clk            ( clk             ),
            .clr            ( buffer_clr      ),
            .ce             ( ce              ),
            .data_in        ( r_out_mult[i]   ),
            .data_out       ( r_out_top[i]    ),
            .burst_complete ( burst_complete  ) 
        ); 
    end   
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            memory_clr <= 1;
            buffer_clr <= 1;
            out_valid  <= 0;
        end else begin
            unique case(state)
                IDLE: begin
                    out_valid  <= 0; 
                    in_ready   <= 1;
                    memory_clr <= 1;
                    buffer_clr <= 1;
                    if (in_valid)  begin
                        latched_features <= features;
                        memory_clr <= 0;
                        buffer_clr <= 0;
                        state <= RUNNING;
                    end
                end

                RUNNING: begin
                    in_ready   <= 0;
                    if(burst_complete == 1) begin
                        memory_clr <= 1;
                        buffer_clr <= 1;
                        state      <= OUT;  
                    end  
                end

                OUT: begin
                    out_valid <= 1;  
                    out       <= r_out_top;
                    if (out_ready) begin
                        state <= IDLE;
                    end
                end
            endcase;
         end
      end

endmodule