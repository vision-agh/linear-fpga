module top_module #(
    parameter int WIDTH   = 8,
    parameter int WIDTH_B = 32,
    parameter int P = 2, //number of parallel features
    parameter int Q = 2, //number of modules per feature
    parameter int N = 10,
    parameter int M = 12,
    parameter in  M_MUL = 12345,
    parameter in  Z_WEIGHTS = 5
) (
    output logic                           axis_ready,
    input  logic                           clk,
    input  logic                           rst,
    input  logic                           ce,
    input  logic                           axis_valid,
    input  logic [P-1:0][N-1:0][WIDTH-1:0] features,
    output logic [P-1:0][M-1:0][WIDTH-1:0] out 
    // to do -> add more I/O signals
    // to do -> AXIS signals module
);

    localparam int DATA_WIDTH = WIDTH*N+WIDTH_B;

    typedef enum logic {
        INITIALIZE,
        IDLE,
        INSERT,
        MULTIPLY,
        OUT
    } t_state;
     
    t_state state, next_state;
    
    logic                           r_ce;
    logic [P-1:0][N-1:0][WIDTH-1:0] r_features_in;
    logic [WIDTH_B-1:0]             bias;
    logic [N-1:0][WIDTH-1:0]        weights_in;
    logic [$clog2(M)-1:0]           line_counter = 0;
    
    logic [P-1:0][WIDTH_B-1:0]   acc ; //to do -> parametrize bias width
    logic [P-1:0][WIDTH_B-1:0]   ai ;
    
    logic [P-1:0][WIDTH+16-1:0] r_out; //to do -> choose width
    
    logic [DATA_WIDTH-1:0]    mem_data_out;
        
    memory_weights #(
        .DATA_WIDTH ( DATA_WIDTH ),
        .ADDR_DEPTH ( M )
    ) u_memory_weights (
        .clk        ( clk ),
        .ce         ( r_ce ),
        .addr       ( line_counter ),
        .dout       ( mem_data_out )
    );
    
    genvar i;
    for(i=0; i<P; i++) begin
        vector_multiplier_generator #(
            .NP          ( N ),
            .REG_DEPTH   ( WIDTH ),
            .Q           ( Q )
        ) u_vector_multiplier_generator (
            .clk         ( clk ),
            .rst         ( rst ),
            .ce          ( r_ce ),
            .features_in ( r_features_in[P] ),
            .weights_in  ( weights_in[P] ),
            .acc         ( acc[P] ),
            .ai          ( ai[P] )
        );
    end

    /* Module internal logic */
    always_ff @(posedge clk or posedge rst) begin    
        if (rst) begin
            state <= IDLE;
            r_features_in <= '{default: '0};
            bias <= '{default: '0};
            weights_in <= '{default: '0};
            line_counter <= 0;           
        end else begin
            state <= next_state;
            
            case(state)
                
                IDLE: begin
                    if (axis_valid)  
                        axis_ready <= 0;                    
                end
                
                INSERT: begin
                    if (line_counter < M)
                        line_counter <= line_counter + 1;                         
                    else 
                        line_counter <= 0;  
                
                    for(int i=0; i<N; i++) begin
                        weights_in[i] = mem_data_out[i<<(3)-1+:WIDTH]; //to do -> parallel memory interface to read multiple weights lines 
                    end
                    bias = mem_data_out[N<<(3)-1+:WIDTH_B];
                    r_features_in <= features;
                    r_ce <= ce;
                end  
                
                OUT: begin
                    for(int i=0; i<Q; i++) begin
                         r_out[i] = (acc[i] - Z_WEIGHTS*ai[i])*(M_MUL>>>32) + bias;
                    end    
                    axis_ready <= 1;
                    out <= r_out; //to do -> quantize or slice?
                end  
            endcase;
         end
      end
            

    always_comb begin
        case (state)
            INITIALIZE: begin
                //to do -> calculate biases
                //to do -> slicing weights and biases module depending on bram size
                next_state = IDLE;
            end
       
            IDLE: begin // In this state BRAM address is incremented until it reaches its final line
                if (axis_valid) begin
                    next_state = INSERT;
                end else begin
                    next_state = IDLE;
                end       
            end
       
            INSERT: begin // In this state, weights lines stored in mem_data_out are sliced in for loop   
                next_state = MULTIPLY;
            end
       
            MULTIPLY: begin // In this state vector multiplication module calculates output value
                next_state = OUT;
            end
       
            OUT: begin // In this state final version of output vector is calculated
                next_state <= IDLE;
                //to do -> output module
            end
        endcase
    end

endmodule
