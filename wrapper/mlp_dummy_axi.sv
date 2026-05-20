// =============================================================================
// mlp_dummy_axi.sv
//
// AXI4-Lite Slave for the MLP accelerator.
//
// All MLP sizing comes from mlp_pkg::MLP_CFG - no parameter list to maintain.
// AXI bus widths (data/address) remain as module parameters because they are
// AXI infrastructure concerns, not MLP model concerns.
//
// Port names: uppercase S_AXI_ prefix required for Vivado IP Integrator to
// auto-detect and group signals into an AXI4-Lite interface in the BD canvas.
//
// No 2D unpacked arrays appear at any port of this module.
//
// ─── Memory Map ─────────────────────────────────────────────────────────────
//  Offset   Access  Field
//  0x0000   R/W     Control: bit[0] = START  (PS sets 1 to start; clears to ack)
//  0x0004   RO      Status : bit[0] = DONE   (HW sets; clears when START→0)
//  0x0008   W       Input  RAM [0..783] - one 8-bit value per 32-bit word
//    ⋮                                     (only wdata[7:0] stored)
//  0x0C44   W       Input  RAM [783]
//  0x0C50   R       Output RAM [0..9]  - zero-extended to 32 bits on read
//  0x0C74   R       Output RAM [9]
//
// ─── FSM ────────────────────────────────────────────────────────────────────
//  IDLE      → START=1  → SEND
//  SEND      → in_ready → WAIT_OUT
//  WAIT_OUT  → out_valid → LATCH
//  LATCH     (1 cycle: capture outputs, set DONE) → WAIT_CLR
//  WAIT_CLR  → START=0  → IDLE
// =============================================================================
`timescale 1ns / 1ps

import mlp_pkg::*;   // MLP_CFG, FEAT_BITS, OUT_BITS

module mlp_dummy_axi #(
    // AXI bus parameters only - MLP config lives in mlp_pkg
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 16
)(
    input  wire                               S_AXI_ACLK,
    input  wire                               S_AXI_ARESETN,  // active-low

    // Write address
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire [2:0]                         S_AXI_AWPROT,
    input  wire                               S_AXI_AWVALID,
    output reg                                S_AXI_AWREADY,

    // Write data
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                               S_AXI_WVALID,
    output reg                                S_AXI_WREADY,

    // Write response
    output reg  [1:0]                         S_AXI_BRESP,
    output reg                                S_AXI_BVALID,
    input  wire                               S_AXI_BREADY,

    // Read address
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire [2:0]                         S_AXI_ARPROT,
    input  wire                               S_AXI_ARVALID,
    output reg                                S_AXI_ARREADY,

    // Read data
    output reg  [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output reg  [1:0]                         S_AXI_RRESP,
    output reg                                S_AXI_RVALID,
    input  wire                               S_AXI_RREADY
);

    // =========================================================================
    // Sizing constants derived from the package - single source of truth
    // =========================================================================
    localparam integer NUM_IN  = MLP_CFG.FC1_N;  // 784
    localparam integer NUM_OUT = MLP_CFG.FC3_M;  //  10

    // Address map
    localparam [C_S_AXI_ADDR_WIDTH-1:0]
        CTRL_ADDR = 16'h0000,
        STAT_ADDR = 16'h0004,
        IN_BASE   = 16'h0008,
        IN_TOP    = IN_BASE  + (NUM_IN  - 1) * 4,   // 0x0C44
        OUT_BASE  = 16'h0C50,
        OUT_TOP   = OUT_BASE + (NUM_OUT - 1) * 4;   // 0x0C74

    // =========================================================================
    // Register file - plain 1D unpacked arrays (no 2D SV arrays at any port)
    // =========================================================================
    reg [7:0] input_ram  [0:NUM_IN-1];
    reg [7:0] output_ram [0:NUM_OUT-1];
    reg       ctrl_start;
    reg       stat_done;

    // =========================================================================
    // Flat buses connecting to mlp_flat_shim
    // =========================================================================
    wire [FEAT_BITS-1:0] features_flat;   // 6272 bits = 784 × 8
    wire [OUT_BITS-1:0]  out_flat;        //   80 bits =  10 × 8

    wire mlp_in_ready;
    wire mlp_out_valid;
    reg  mlp_in_valid;
    reg  mlp_out_ready;

    // Drive features_flat from input_ram - one assign per byte, fully parallel
    genvar gi;
    generate
        for (gi = 0; gi < NUM_IN; gi = gi + 1) begin : gen_feat_flat
            assign features_flat[gi * MLP_CFG.FC1_INPUT_PRECISION
                                  +: MLP_CFG.FC1_INPUT_PRECISION] = input_ram[gi];
        end
    endgenerate

    // =========================================================================
    // mlp_flat_shim - no parameters; it reads from mlp_pkg directly
    // =========================================================================
    mlp_flat_shim u_shim (
        .clk          (S_AXI_ACLK),
        .rst          (~S_AXI_ARESETN),   // active-high reset for mlp_top
        .ce           (1'b1),
        .in_valid     (mlp_in_valid),
        .in_ready     (mlp_in_ready),
        .out_valid    (mlp_out_valid),
        .out_ready    (mlp_out_ready),
        .features_flat(features_flat),
        .out_flat     (out_flat)
    );

    // =========================================================================
    // FSM - encoded as localparams (no SV enum = compatible everywhere)
    // =========================================================================
    localparam [2:0]
        FSM_IDLE     = 3'd0,
        FSM_SEND     = 3'd1,
        FSM_WAIT_OUT = 3'd2,
        FSM_LATCH    = 3'd3,
        FSM_WAIT_CLR = 3'd4;

    reg [2:0] fsm_state;
    integer   k;

    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            fsm_state     <= FSM_IDLE;
            mlp_in_valid  <= 1'b0;
            mlp_out_ready <= 1'b0;
            stat_done     <= 1'b0;
            for (k = 0; k < NUM_OUT; k = k + 1)
                output_ram[k] <= 8'h00;
        end else begin
            case (fsm_state)

                FSM_IDLE: begin
                    mlp_in_valid  <= 1'b0;
                    mlp_out_ready <= 1'b0;
                    if (ctrl_start) begin
                        mlp_in_valid <= 1'b1;
                        fsm_state    <= FSM_SEND;
                    end
                end

                // Hold in_valid until MLP handshakes it away with in_ready
                FSM_SEND: begin
                    if (mlp_in_ready) begin
                        mlp_in_valid <= 1'b0;
                        fsm_state    <= FSM_WAIT_OUT;
                    end
                end

                // Wait for the full pipeline to finish
                FSM_WAIT_OUT: begin
                    if (mlp_out_valid) begin
                        mlp_out_ready <= 1'b1;
                        fsm_state     <= FSM_LATCH;
                    end
                end

                // One clock: capture result bytes, assert DONE, drop out_ready
                FSM_LATCH: begin
                    mlp_out_ready <= 1'b0;
                    for (k = 0; k < NUM_OUT; k = k + 1)
                        output_ram[k] <= out_flat[k * MLP_CFG.FC3_OUTPUT_PRECISION
                                                   +: MLP_CFG.FC3_OUTPUT_PRECISION];
                    stat_done <= 1'b1;
                    fsm_state <= FSM_WAIT_CLR;
                end

                // Hold until PS acknowledges by writing START = 0
                FSM_WAIT_CLR: begin
                    if (!ctrl_start) begin
                        stat_done <= 1'b0;
                        fsm_state <= FSM_IDLE;
                    end
                end

                default: fsm_state <= FSM_IDLE;

            endcase
        end
    end

    // =========================================================================
    // AXI4-Lite Write Path
    // =========================================================================
    reg [C_S_AXI_ADDR_WIDTH-1:0] wr_addr_lat;
    reg                           wr_addr_pend;
    integer                       wi;

    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;
            wr_addr_lat   <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wr_addr_pend  <= 1'b0;
            ctrl_start    <= 1'b0;
            for (wi = 0; wi < NUM_IN; wi = wi + 1)
                input_ram[wi] <= 8'h00;
        end else begin

            // ── Accept write address ────────────────────────────────────────
            if (S_AXI_AWVALID && !S_AXI_AWREADY) begin
                S_AXI_AWREADY <= 1'b1;
                wr_addr_lat   <= S_AXI_AWADDR;
                wr_addr_pend  <= 1'b1;
            end else begin
                S_AXI_AWREADY <= 1'b0;
            end

            // ── Accept write data & commit ──────────────────────────────────
            if (S_AXI_WVALID && !S_AXI_WREADY && wr_addr_pend) begin
                S_AXI_WREADY <= 1'b1;
                wr_addr_pend <= 1'b0;

                if (wr_addr_lat == CTRL_ADDR) begin
                    // PS owns this register; hardware never auto-clears START
                    ctrl_start <= S_AXI_WDATA[0];
                end else if (wr_addr_lat >= IN_BASE && wr_addr_lat <= IN_TOP) begin
                    wi = (wr_addr_lat - IN_BASE) >> 2;
                    if (wi >= 0 && wi < NUM_IN)
                        input_ram[wi] <= S_AXI_WDATA[7:0];
                end
                // Writes to STAT or OUT regions silently ignored

            end else begin
                S_AXI_WREADY <= 1'b0;
            end

            // ── Write response ──────────────────────────────────────────────
            if (S_AXI_WREADY && !S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00;  // OKAY
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end

        end
    end

    // =========================================================================
    // AXI4-Lite Read Path
    // =========================================================================
    integer ri;

    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RDATA   <= {C_S_AXI_DATA_WIDTH{1'b0}};
            S_AXI_RRESP   <= 2'b00;
        end else begin

            if (S_AXI_ARVALID && !S_AXI_ARREADY && !S_AXI_RVALID) begin
                S_AXI_ARREADY <= 1'b1;
                S_AXI_RVALID  <= 1'b1;
                S_AXI_RRESP   <= 2'b00;

                if (S_AXI_ARADDR == CTRL_ADDR) begin
                    S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-1){1'b0}}, ctrl_start};

                end else if (S_AXI_ARADDR == STAT_ADDR) begin
                    S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-1){1'b0}}, stat_done};

                end else if (S_AXI_ARADDR >= IN_BASE && S_AXI_ARADDR <= IN_TOP) begin
                    ri = (S_AXI_ARADDR - IN_BASE) >> 2;
                    S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-8){1'b0}}, input_ram[ri]};

                end else if (S_AXI_ARADDR >= OUT_BASE && S_AXI_ARADDR <= OUT_TOP) begin
                    ri = (S_AXI_ARADDR - OUT_BASE) >> 2;
                    S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-8){1'b0}}, output_ram[ri]};

                end else begin
                    S_AXI_RDATA <= 32'hDEAD_BEEF;   // unmapped address
                end

            end else begin
                S_AXI_ARREADY <= 1'b0;
                if (S_AXI_RVALID && S_AXI_RREADY)
                    S_AXI_RVALID <= 1'b0;
            end

        end
    end

endmodule