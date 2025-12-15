`timescale 1ns / 1ps


module burst_buffer #(
    parameter int INITIAL_LATENCY = 3,
    parameter int M = 5,
    parameter int PRECISION = 5
) (
    input  logic                        clk,
    input  logic                        rst,
    input  logic                        ce,
    input  logic [PRECISION-1:0]        data_in,
    output logic [M-1:0][PRECISION-1:0] data_out,
    output logic out_ready // temporary signal
);
    
    typedef enum logic {
        LATENCY,
        BUFFERING
    } state_t;

    state_t state = LATENCY;
    
    logic [3:0]   count;
    logic [M-1:0][PRECISION-1:0] r_burst_buffer;
    
    always_ff @ (posedge clk) begin
        if (rst) begin
            count          <= 0;
            r_burst_buffer <= 0;
            data_out       <= 0;
            out_ready      <= 0;
            state          <= LATENCY;
        end else begin
            if (ce) begin
                case (state)
                    LATENCY: begin
                        if (count < INITIAL_LATENCY) begin
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
                            out_ready <= 0;
                            r_burst_buffer[M-1-count] <= data_in;
                            count <= count + 1;
                        end else begin
                            count <= 1;
                            data_out  <= r_burst_buffer;
                            r_burst_buffer[M-1] <= data_in;
                            out_ready <= 1;
                        end
                    end
                 endcase
            end
        end
    end             
endmodule
