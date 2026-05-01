`timescale 1ns / 1ps


module burst_buffer #(
    parameter int INITIAL_LATENCY = 3,
    parameter int M               = 5,
    parameter int PRECISION       = 5
) (
    input  logic                 clk,
    input  logic                 clr,
    input  logic                 ce,
    input  logic [PRECISION-1:0] data_in,
    output logic [PRECISION-1:0] data_out [M-1:0],
    output logic burst_complete 
);
    
    typedef enum logic {
        LATENCY,
        BUFFERING
    } state_t;

    state_t state = LATENCY;
    localparam int LATENCY_LAST = (INITIAL_LATENCY > 0) ? (INITIAL_LATENCY - 1) : 0;
    
    logic [$clog2(M + INITIAL_LATENCY):0]   count;
    logic [PRECISION-1:0] r_burst_buffer [M-1:0];
    
    always_ff @ (posedge clk) begin
        if (clr) begin
            count          <= 0;
            for (int reset_idx = 0; reset_idx < M; reset_idx++) begin
                r_burst_buffer[reset_idx] <= '0;
                data_out[reset_idx] <= '0;
            end
            burst_complete <= 0;
            state          <= LATENCY;
        end else begin
            if (ce) begin
                case (state)
                    LATENCY: begin
                        if (count < LATENCY_LAST) begin
                            state <= LATENCY;
                            count <= count + 1;  
                        end else begin
                            state <= BUFFERING;
                            count <= 0;
                        end
                    end
                    BUFFERING: begin
                        state <= BUFFERING;
                        if (count < M) begin
                            burst_complete <= 0;
                            r_burst_buffer[count] <= data_in;
                            count <= count + 1;
                        end else begin
                            for (int copy_idx = 0; copy_idx < M; copy_idx++) begin
                                data_out[copy_idx] <= r_burst_buffer[copy_idx];
                            end
                            burst_complete <= 1;
                        end
                    end
                 endcase
            end
        end
    end             
endmodule
