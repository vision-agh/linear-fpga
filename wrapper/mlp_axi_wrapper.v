// =============================================================================
// mlp_axi_wrapper.v   -   Strict Verilog-2001  (.v, no SystemVerilog)
//
// ─── PURPOSE ─────────────────────────────────────────────────────────────────
// Vivado's "Add Module" / RTL Module Reference parser inspects ONLY this file's
// port boundary.  Any SystemVerilog token here (logic, enum, 2D arrays, etc.)
// causes the module to be flagged incompatible and hidden from the Add Module
// dialog.  This file is therefore written in strict Verilog-2001: every port is
// "input wire" or "output wire", nothing else.
//
// All implementation lives in the .sv files below; Vivado elaborates those
// normally - it only rejects SV at the RTL Reference boundary.
//
// ─── PARAMETER NOTE ──────────────────────────────────────────────────────────
// MLP network parameters (TEMP, N, M, quantization constants, etc.) are NOT
// listed here.  They live exclusively in mlp_pkg.sv.  This wrapper exposes
// only the two AXI bus-width parameters that the Vivado BD might need to
// configure the AXI Interconnect/SmartConnect widths.
//
// ─── VIVADO USAGE ────────────────────────────────────────────────────────────
//  1. Add to project (Design Sources):
//       mlp_pkg.sv          ← compile FIRST (package must precede importers)
//       mlp_top.sv
//       mlp_flat_shim.sv
//       mlp_dummy_axi.sv
//       mlp_axi_wrapper.v   ← top of hierarchy visible to Block Design
//
//  2. Open Block Design → right-click → Add Module → search "mlp_axi_wrapper"
//     It will appear and be addable because this file has zero SV constructs.
//
//  3. Vivado recognises the uppercase S_AXI_ prefix and auto-groups all
//     signals into a single AXI4-Lite slave interface for one-click connection
//     to an AXI Interconnect or SmartConnect master port.
//
//  4. Connect S_AXI_ACLK to your 100 MHz processing-system clock output.
//     Connect S_AXI_ARESETN to the peripheral_aresetn output of a
//     Processor System Reset block driven by the same clock.
//
// ─── ADDRESS SPACE (for the Vivado Address Editor) ───────────────────────────
//  Assign a 64 KB (0x10000) window.  The used range is 0x0000-0x0C74:
//    0x0000  Control register  (R/W)
//    0x0004  Status  register  (RO)
//    0x0008-0x0C44  Input  RAM - 784 × 32-bit words, 8 LSBs used
//    0x0C50-0x0C74  Output RAM -  10 × 32-bit words, 8 LSBs valid
// =============================================================================
`timescale 1ns / 1ps

module mlp_axi_wrapper #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 16
)(
    // ── Clock & Reset ─────────────────────────────────────────────────────────
    input  wire                               S_AXI_ACLK,
    input  wire                               S_AXI_ARESETN,

    // ── Write Address Channel ─────────────────────────────────────────────────
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire [2:0]                         S_AXI_AWPROT,
    input  wire                               S_AXI_AWVALID,
    output wire                               S_AXI_AWREADY,

    // ── Write Data Channel ────────────────────────────────────────────────────
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                               S_AXI_WVALID,
    output wire                               S_AXI_WREADY,

    // ── Write Response Channel ────────────────────────────────────────────────
    output wire [1:0]                         S_AXI_BRESP,
    output wire                               S_AXI_BVALID,
    input  wire                               S_AXI_BREADY,

    // ── Read Address Channel ──────────────────────────────────────────────────
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire [2:0]                         S_AXI_ARPROT,
    input  wire                               S_AXI_ARVALID,
    output wire                               S_AXI_ARREADY,

    // ── Read Data Channel ─────────────────────────────────────────────────────
    output wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output wire [1:0]                         S_AXI_RRESP,
    output wire                               S_AXI_RVALID,
    input  wire                               S_AXI_RREADY
);

    // No logic. Pure structural pass-through.
    mlp_dummy_axi #(
        .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH)
    ) u_mlp_dummy_axi (
        .S_AXI_ACLK    (S_AXI_ACLK),
        .S_AXI_ARESETN (S_AXI_ARESETN),

        .S_AXI_AWADDR  (S_AXI_AWADDR),
        .S_AXI_AWPROT  (S_AXI_AWPROT),
        .S_AXI_AWVALID (S_AXI_AWVALID),
        .S_AXI_AWREADY (S_AXI_AWREADY),

        .S_AXI_WDATA   (S_AXI_WDATA),
        .S_AXI_WSTRB   (S_AXI_WSTRB),
        .S_AXI_WVALID  (S_AXI_WVALID),
        .S_AXI_WREADY  (S_AXI_WREADY),

        .S_AXI_BRESP   (S_AXI_BRESP),
        .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),

        .S_AXI_ARADDR  (S_AXI_ARADDR),
        .S_AXI_ARPROT  (S_AXI_ARPROT),
        .S_AXI_ARVALID (S_AXI_ARVALID),
        .S_AXI_ARREADY (S_AXI_ARREADY),

        .S_AXI_RDATA   (S_AXI_RDATA),
        .S_AXI_RRESP   (S_AXI_RRESP),
        .S_AXI_RVALID  (S_AXI_RVALID),
        .S_AXI_RREADY  (S_AXI_RREADY)
    );

endmodule