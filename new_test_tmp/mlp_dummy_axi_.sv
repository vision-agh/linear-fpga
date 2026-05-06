`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: engine
// 
// Create Date: 03.05.1026 23:11:02
// Design Name: dummy
// Module Name: mlp_dummy_axi
// Project Name: dummy dummy
// Target Devices:
// Tool Versions: 6969
// Description: DEUS VULT
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mlp_dummy_axi (
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    // AXI4-Lite Slave Interface
    input  wire [15:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire        s_axi_rready,   // ? was missing!
    input  wire [3:0]  s_axi_wstrb, 
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [15:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid
);

    // AXI4-Lite handshaking registers
    reg awready;
    reg wready;
    reg bvalid;
    reg arready;
    reg rvalid;
    reg [31:0] rdata;

    assign s_axi_awready = awready;
    assign s_axi_wready  = wready;
    assign s_axi_bresp   = 2'b00; // OKAY
    assign s_axi_bvalid  = bvalid;
    assign s_axi_arready = arready;
    assign s_axi_rdata   = rdata;
    assign s_axi_rresp   = 2'b00; // OKAY
    assign s_axi_rvalid  = rvalid;

    // Address latching
    reg [15:0] awaddr_reg;
    reg [15:0] araddr_reg;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            awready <= 1'b0;
            wready  <= 1'b0;
            bvalid  <= 1'b0;
            arready <= 1'b0;
            rvalid  <= 1'b0;
        end else begin
            // Write handshaking
            if (~awready && s_axi_awvalid && s_axi_wvalid) begin
                awready <= 1'b1;
                wready  <= 1'b1;
                awaddr_reg <= s_axi_awaddr;
            end else begin
                awready <= 1'b0;
                wready  <= 1'b0;
            end

            if (awready && s_axi_awvalid && wready && s_axi_wvalid && ~bvalid) begin
                bvalid <= 1'b1;
            end else if (bvalid && s_axi_bready) begin
                bvalid <= 1'b0;
            end

            // Read handshaking
            if (~arready && s_axi_arvalid) begin
                arready <= 1'b1;
                araddr_reg <= s_axi_araddr;
            end else begin
                arready <= 1'b0;
            end

            if (arready && s_axi_arvalid && ~rvalid) begin
                rvalid <= 1'b1;
            end else if (rvalid && s_axi_rready) begin
                rvalid <= 1'b0;
            end
        end
    end

    // --------------------------------------------------------
    // User Application Logic
    // --------------------------------------------------------
    reg control;
    reg status;
    reg [7:0] input_ram  [0:783];   // 784 x 8-bit inputs
    reg [7:0] output_ram [0:9];     // 10 x 8-bit outputs

    wire slv_reg_wren = wready && s_axi_wvalid && awready && s_axi_awvalid;
    wire slv_reg_rden = arready && s_axi_arvalid && ~rvalid;

    // AXI Write logic
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            control <= 1'b0;
        end else begin
            if (slv_reg_wren) begin
                if (awaddr_reg == 16'h0000) begin
                    control <= s_axi_wdata[0];
                end else if (awaddr_reg >= 16'h0008 && awaddr_reg < 16'h0C50) begin
                    input_ram[(awaddr_reg - 16'h0008) >> 2] <= s_axi_wdata[7:0];
                end
            end else if (status == 1'b1) begin
                control <= 1'b0;
            end
        end
    end

    // AXI Read logic
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            rdata <= 32'b0;
        end else if (slv_reg_rden) begin
            if (araddr_reg == 16'h0000) begin
                rdata <= {31'b0, control};
            end else if (araddr_reg == 16'h0004) begin
                rdata <= {31'b0, status};
            end else if (araddr_reg >= 16'h0008 && araddr_reg < 16'h0C50) begin
                rdata <= {24'b0, input_ram[(araddr_reg - 16'h0008) >> 2]};
            end else if (araddr_reg >= 16'h0C50 && araddr_reg <= 16'h0C74) begin
                rdata <= {24'b0, output_ram[(araddr_reg - 16'h0C50) >> 2]};
            end else begin
                rdata <= 32'b0;
            end
        end
    end

    // --------------------------------------------------------
    // MLP wires
    // --------------------------------------------------------
    reg mlp_in_valid;
    wire mlp_in_ready;
    wire mlp_out_valid;
    reg mlp_out_ready;

    wire [7:0] mlp_features [0:0][0:783];
    wire [7:0] mlp_out      [0:0][0:9];

    genvar gi;
    generate
        for (gi = 0; gi < 784; gi = gi + 1) begin : gen_features
            assign mlp_features[0][gi] = input_ram[gi];
        end
    endgenerate

    mlp_top #(
        .NUM_FEATURES(1),
        .FC1_N(784),
        .FC1_M(128),
        .FC1_TEMP(-8),   // reduce from 128 to 64
        .FC2_N(128),   // reduce from 128 to 64
        .FC2_M(128),
        .FC2_TEMP(-2),   // reduce from 128 to 64
        .FC3_N(128),   // reduce from 128 to 64
        .FC3_M(10),
        .FC3_TEMP(-2),
        .FC1_MEMORY_FILE("fc1_weights.mem"),
        .FC2_MEMORY_FILE("fc2_weights.mem"),
        .FC3_MEMORY_FILE("fc3_weights.mem")

    ) u_mlp (
        .clk      (s_axi_aclk),
        .rst      (~s_axi_aresetn),
        .ce       (1'b1),
        .in_valid (mlp_in_valid),
        .in_ready (mlp_in_ready),
        .out_valid(mlp_out_valid),
        .out_ready(mlp_out_ready),
        .features (mlp_features),
        .out      (mlp_out)
    );

    // --------------------------------------------------------
    // Control State Machine
    // --------------------------------------------------------
    reg [3:0] state;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            status       <= 1'b0;
            state        <= 4'd0;
            mlp_in_valid <= 1'b0;
            mlp_out_ready<= 1'b0;
        end else begin
            case (state)

                // IDLE - wait for PS to set control=1
                4'd0: begin
                    status        <= 1'b0;
                    mlp_in_valid  <= 1'b0;
                    mlp_out_ready <= 1'b0;
                    if (control == 1'b1) begin
                        state <= 4'd1;
                    end
                end

                // SEND - assert in_valid, wait for in_ready handshake
                4'd1: begin
                    mlp_in_valid <= 1'b1;
                    if (mlp_in_valid && mlp_in_ready) begin  // both must be high same cycle
                        mlp_in_valid <= 1'b0;
                        state <= 4'd2;
                    end
                end

                // WAIT - wait for MLP to finish
                // WAIT - wait for MLP to finish, latch immediately
                4'd2: begin
                    mlp_out_ready <= 1'b1;
                    if (mlp_out_valid) begin
                        mlp_out_ready <= 1'b0;
                        // latch output HERE, same cycle
                        output_ram[0] <= mlp_out[0][0];
                        output_ram[1] <= mlp_out[0][1];
                        output_ram[2] <= mlp_out[0][2];
                        output_ram[3] <= mlp_out[0][3];
                        output_ram[4] <= mlp_out[0][4];
                        output_ram[5] <= mlp_out[0][5];
                        output_ram[6] <= mlp_out[0][6];
                        output_ram[7] <= mlp_out[0][7];
                        output_ram[8] <= mlp_out[0][8];
                        output_ram[9] <= mlp_out[0][9];
                        state <= 4'd3;  // skip separate CAPTURE state
                    end
                end
                
                // DONE - signal PS (was 4'd4, now 4'd3)
                4'd3: begin
                    status <= 1'b1;
                    if (control == 1'b0) begin
                        state <= 4'd0;
                    end
                end

                default: state <= 4'd0;
            endcase
        end
    end

endmodule