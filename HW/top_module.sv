module top_module #(
    parameter int PRECISION       = 8,
    parameter int TEMP            = 1,
    parameter int BIAS_PRECISION  = 32,
    parameter int NUM_FEATURES    = 2,          // number of parallel features
    parameter int MUL_PER_FEATURE = 2,          // number of multiplier instantiations per feature
    parameter int N               = 12,          // elements of feature
    parameter int M               = 32,          // elements of output
    parameter int M_MUL           = 2094967296, // multiplier constant needed to calculate pseudo-float number
    parameter int Z_WEIGHTS       = 5           // zero point of weights
) (
    output logic                 out_valid,
    output logic                 in_ready,
    input  logic                 in_valid,
    input  logic                 out_ready,
    input  logic                 buffer_clr,
    input  logic                 memory_clr,
    input  logic                 clk,
    input  logic                 rst,
    input  logic                 ce,
    input  logic [PRECISION-1:0] features [NUM_FEATURES-1:0][N-1:0],
    output logic [PRECISION-1:0] out      [NUM_FEATURES-1:0][M-1:0]
);

    localparam int INITIAL_LATENCY = 5; // latency needed for burst_buffer to skip thrash data, TEMP < 0 == 6, TEMP > 1 == 4, TEMP =1 == 5
    
    logic memory_clr;
    logic buffer_clr;
    logic burst_complete;
    logic buffer_clr_ser=0;
    
    logic [PRECISION-1:0] weights_in       [N-1:0];
    logic [PRECISION-1:0] features_sliced  [NUM_FEATURES-1:0][N/TEMP-1:0];
    logic [PRECISION-1:0] latched_features [NUM_FEATURES-1:0][N-1:0];
    logic [PRECISION-1:0] weights [N-1:0];

    
    logic [PRECISION-1:0] r_out_mult    [NUM_FEATURES-1:0];
    logic [PRECISION-1:0] r_out_top_sin [NUM_FEATURES-1:0][M-1:0];
    logic [PRECISION-1:0] r_out_top     [NUM_FEATURES-1:0][TEMP-1:0][(M/TEMP)-1:0];
    logic [PRECISION-1:0] r_out_top_ser [NUM_FEATURES-1:0][M-1:0];
    logic [BIAS_PRECISION-1:0] r_out_long    [NUM_FEATURES-1:0];

    logic [PRECISION-1:0] r_out_buffer [NUM_FEATURES-1:0][M-1:0];
    
    logic [PRECISION-1:0] weights_serial   [N/(-TEMP)-1:0];
    logic [PRECISION-1:0] weights_single   [N-1:0];
    logic [PRECISION-1:0] weights_parallel [TEMP-1:0][N-1:0];
    
    logic [BIAS_PRECISION-1:0] bias_parallel [TEMP-1:0];
    logic [BIAS_PRECISION-1:0] bias;
    
    logic [PRECISION-1:0] r_out_mult_parallel [TEMP-1:0][NUM_FEATURES-1:0];
    logic [PRECISION-1:0] r_out_mult_serial   [NUM_FEATURES-1:0];


    typedef enum logic [1:0] {
        IDLE,
        RUNNING,
        OUT
    } state_t;

    state_t state;
    
    generate
    if (TEMP < 0) begin
    
        localparam int BRAM_WIDTH = PRECISION*N/(-TEMP) + BIAS_PRECISION;
        logic [PRECISION-1:0] weights [N/(-TEMP)-1:0];
    
        serial_memory_fetcher #(
            .BRAM_WIDTH     ( BRAM_WIDTH     ),
            .TEMP           ( -TEMP          ),
            .M              ( M              ),
            .N              ( N              ),
            .BIAS_PRECISION ( BIAS_PRECISION ),
            .PRECISION      ( PRECISION      )
        ) u_serial_memory_fetcher (
            .clk            ( clk            ),
            .clr            ( memory_clr     ),
            .ce             ( ce             ),
            .data_out       ( weights_serial ),
            .bias           ( bias           )
        );
            
        multiplier_top #(
            .PRECISION              ( PRECISION        ),
            .BIAS_PRECISION         ( BIAS_PRECISION   ),
            .OUTPUT_STAGE_PRECISION ( BIAS_PRECISION*2 ),
            .NUM_FEATURES           ( NUM_FEATURES     ),
            .MUL_PER_FEATURE        ( MUL_PER_FEATURE  ),
            .N                      ( N/(-TEMP)        ),
            .M_MUL                  ( M_MUL            ),
            .Z_WEIGHTS              ( Z_WEIGHTS        )
        ) u_multiplier_top (
            .clk        ( clk               ),
            .rst        ( rst               ),
            .ce         ( ce                ),
            .bias       ( bias              ),     
            .weights_in ( weights_serial    ),
            .features   ( features_sliced   ),
            .out        ( r_out_mult_serial ),
            .long_out   ( r_out_long        )
        );
       
         serial_accumulator #(
            .PRECISION              ( PRECISION        ),
            .BIAS_PRECISION         ( BIAS_PRECISION   ),
            .TEMP                   ( -TEMP             ),
            .INITIAL_LATENCY        ( INITIAL_LATENCY  ),
            .NUM_FEATURES           ( NUM_FEATURES     ),
            .M                      ( M                )
         ) u_serial_accumulator (
            .clk      ( clk            ),
            .rst      ( rst            ),
            .clr      ( buffer_clr     ),
            .ce       ( ce             ),
            .features ( r_out_long     ),
            .out      ( r_out_buffer   ),
            .acc_done ( burst_complete )
        );
       
        serial_data_scheduler #(
            .PRECISION    ( PRECISION    ),
            .TEMP         ( -TEMP        ),
            .NUM_FEATURES ( NUM_FEATURES ),
            .N            ( N            ),
            .M            ( M            )
        ) u_serial_data_scheduler (
            .clk             ( clk              ),
            .rst             ( rst              ),
            .ce              ( ce               ),
            .ctrl            ( in_valid         ),
            .features        ( latched_features ),
            .features_sliced ( features_sliced  )
        );
        
    end else if (TEMP == 1) begin
    
        localparam int BRAM_WIDTH = PRECISION*N + BIAS_PRECISION;
    
        memory_fetcher #(
            .BRAM_WIDTH     ( BRAM_WIDTH     ),
            .M              ( M              ),
            .N              ( N              ),
            .BIAS_PRECISION ( BIAS_PRECISION ),
            .PRECISION      ( PRECISION      )
        ) u_memory_fetcher (
            .clk      ( clk            ),
            .clr      ( memory_clr     ),
            .ce       ( ce             ),
            .data_out ( weights_single ),
            .bias     ( bias           )
        );
        
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
            .weights_in ( weights_single   ),
            .features   ( latched_features ),
            .out        ( r_out_mult       )
        );
        
        genvar i;
        for(i=0; i<NUM_FEATURES; i++) begin
            burst_buffer #(
                .INITIAL_LATENCY ( INITIAL_LATENCY ),
                .M               ( M               ),
                .PRECISION       ( PRECISION       )
            ) u_burst_buffer (
                .clk            ( clk              ),
                .clr            ( buffer_clr       ),
                .ce             ( ce               ),
                .data_in        ( r_out_mult[i]    ),
                .data_out       ( r_out_buffer[i]  ),
                .burst_complete ( burst_complete   ) 
            ); 
        end  
        
        
        
    end else begin
    
        localparam int BRAM_WIDTH = PRECISION*N + BIAS_PRECISION;
    
        parallel_memory_fetcher #(
            .BRAM_WIDTH     ( BRAM_WIDTH     ),
            .TEMP           ( TEMP           ),
            .M              ( M              ),
            .N              ( N              ),
            .BIAS_PRECISION ( BIAS_PRECISION ),
            .PRECISION      ( PRECISION      )
        ) dut (
            .clk            ( clk              ),
            .clr            ( clr              ),
            .ce             ( ce               ),
            .data_out       ( weights_parallel ),
            .bias           ( bias_parallel    )
        );
        
        genvar i, j;
            for(i=0; i<TEMP; i++) begin 
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
                    .clk        ( clk                       ),
                    .rst        ( rst                       ),
                    .ce         ( ce                        ),
                    .bias       ( bias_parallel[i]          ),     
                    .weights_in ( weights_parallel[i]       ),
                    .features   ( latched_features    ),
                    .out        ( r_out_mult_parallel[i] )
                );
                
                for(j=0; j<NUM_FEATURES; j++) begin 
                burst_buffer #(
                    .INITIAL_LATENCY ( INITIAL_LATENCY ),
                    .M               ( M/TEMP          ),
                    .PRECISION       ( PRECISION       )
                ) u_burst_buffer (
                    .clk            ( clk                       ),
                    .clr            ( buffer_clr                ),
                    .ce             ( ce                        ),
                    .data_in        ( r_out_mult_parallel[i][j] ),
                    .data_out       ( r_out_top          [j][i] ),
                    .burst_complete ( burst_complete            ) 
                ); 
                end      
         end
    end 
    endgenerate


    always_comb begin
        if(TEMP > 1) begin
            for(int j=0; j<NUM_FEATURES; j++) begin
                for(int i=0; i<TEMP; i++) begin
                   r_out_buffer[j][i*(M/TEMP)+:(M/TEMP)] = r_out_top[j][TEMP-1-i];
                end 
            end
        end
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
                    out       <= r_out_buffer;
                    if (out_ready) begin
                        state <= IDLE;
                    end
                end
            endcase;
         end
      end



endmodule