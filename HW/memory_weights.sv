module memory_weights #(
    parameter int DATA_WIDTH = 1024,
    parameter int ADDR_DEPTH = 1024,
    parameter int ADDR_WIDTH = $clog2(ADDR_DEPTH),
    parameter RAM_TYPE = "block"
) (
    input  logic                  clk,
    input  logic                  ce,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] dout
);

    (* ram_style = RAM_TYPE *) logic [DATA_WIDTH-1:0] mem[ADDR_DEPTH-1:0] = '{default:0};
    
    initial begin
        $readmemh("memory_file.mem", mem);
    end

    always_ff @(posedge clk) begin
        if(ce) dout <= mem[addr];           
    end

endmodule
