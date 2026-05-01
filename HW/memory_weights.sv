`timescale 1ns / 1ps

module memory_weights #(
    parameter int DATA_WIDTH = 1024,
    parameter int ADDR_DEPTH = 1024,
    parameter int ADDR_WIDTH = $clog2(ADDR_DEPTH),
    parameter MEMORY_FILE = "generated/fc1_weights.mem",
    parameter RAM_TYPE = "block"
) (
    input  logic                  clk,
    input  logic                  ce,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] dout
);

    (* ram_style = RAM_TYPE *) logic [DATA_WIDTH-1:0] mem [0:ADDR_DEPTH-1];

    initial begin
        $readmemh(MEMORY_FILE, mem);
    end

    always_ff @(posedge clk) begin
        if (ce) begin
            dout <= mem[addr];
        end
    end

endmodule
