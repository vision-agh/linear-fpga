// =============================================================================
// mlp_flat_shim.sv
//
// The ONLY module that touches SystemVerilog 2D unpacked arrays.
// Imports mlp_pkg - no parameter list required.
// Port widths are derived from package constants (FEAT_BITS, OUT_BITS).
// =============================================================================
`timescale 1ns / 1ps

import mlp_pkg::*;

module mlp_flat_shim (
    input  logic                 clk,
    input  logic                 rst,       // active-high
    input  logic                 ce,
    input  logic                 in_valid,
    output logic                 in_ready,
    output logic                 out_valid,
    input  logic                 out_ready,
    input  logic [FEAT_BITS-1:0] features_flat,
    output logic [OUT_BITS-1:0]  out_flat
);

    logic [MLP_CFG.FC1_INPUT_PRECISION-1:0]
        features_2d [MLP_CFG.NUM_FEATURES-1:0][MLP_CFG.FC1_N-1:0];

    logic [MLP_CFG.FC3_OUTPUT_PRECISION-1:0]
        out_2d      [MLP_CFG.NUM_FEATURES-1:0][MLP_CFG.FC3_M-1:0];

    genvar f, i;
    generate
        for (f = 0; f < MLP_CFG.NUM_FEATURES; f = f + 1) begin : gen_unpack_f
            for (i = 0; i < MLP_CFG.FC1_N; i = i + 1) begin : gen_unpack_i
                assign features_2d[f][i] =
                    features_flat[(f * MLP_CFG.FC1_N + i) * MLP_CFG.FC1_INPUT_PRECISION
                                  +: MLP_CFG.FC1_INPUT_PRECISION];
            end
        end
    endgenerate

    genvar g, j;
    generate
        for (g = 0; g < MLP_CFG.NUM_FEATURES; g = g + 1) begin : gen_pack_g
            for (j = 0; j < MLP_CFG.FC3_M; j = j + 1) begin : gen_pack_j
                assign out_flat[(g * MLP_CFG.FC3_M + j) * MLP_CFG.FC3_OUTPUT_PRECISION
                                +: MLP_CFG.FC3_OUTPUT_PRECISION] = out_2d[g][j];
            end
        end
    endgenerate

    mlp_top #(
        .NUM_FEATURES        (MLP_CFG.NUM_FEATURES),
        .FC1_TEMP            (MLP_CFG.FC1_TEMP),
        .FC1_INPUT_PRECISION (MLP_CFG.FC1_INPUT_PRECISION),
        .FC1_WEIGHT_PRECISION(MLP_CFG.FC1_WEIGHT_PRECISION),
        .FC1_OUTPUT_PRECISION(MLP_CFG.FC1_OUTPUT_PRECISION),
        .FC1_BIAS_PRECISION  (MLP_CFG.FC1_BIAS_PRECISION),
        .FC1_MUL_PER_FEATURE (MLP_CFG.FC1_MUL_PER_FEATURE),
        .FC1_N               (MLP_CFG.FC1_N),
        .FC1_M               (MLP_CFG.FC1_M),
        .FC1_IN_ZP           (MLP_CFG.FC1_IN_ZP),
        .FC1_W_ZP            (MLP_CFG.FC1_W_ZP),
        .FC1_OUT_ZP          (MLP_CFG.FC1_OUT_ZP),
        .FC1_M_MUL           (MLP_CFG.FC1_M_MUL),
        .FC1_M_SHIFT         (MLP_CFG.FC1_M_SHIFT),
        .FC1_MEMORY_FILE     ("fc1_weights.mem"),
        .FC2_TEMP            (MLP_CFG.FC2_TEMP),
        .FC2_INPUT_PRECISION (MLP_CFG.FC2_INPUT_PRECISION),
        .FC2_WEIGHT_PRECISION(MLP_CFG.FC2_WEIGHT_PRECISION),
        .FC2_OUTPUT_PRECISION(MLP_CFG.FC2_OUTPUT_PRECISION),
        .FC2_BIAS_PRECISION  (MLP_CFG.FC2_BIAS_PRECISION),
        .FC2_MUL_PER_FEATURE (MLP_CFG.FC2_MUL_PER_FEATURE),
        .FC2_N               (MLP_CFG.FC2_N),
        .FC2_M               (MLP_CFG.FC2_M),
        .FC2_IN_ZP           (MLP_CFG.FC2_IN_ZP),
        .FC2_W_ZP            (MLP_CFG.FC2_W_ZP),
        .FC2_OUT_ZP          (MLP_CFG.FC2_OUT_ZP),
        .FC2_M_MUL           (MLP_CFG.FC2_M_MUL),
        .FC2_M_SHIFT         (MLP_CFG.FC2_M_SHIFT),
        .FC2_MEMORY_FILE     ("fc2_weights.mem"),
        .FC3_TEMP            (MLP_CFG.FC3_TEMP),
        .FC3_INPUT_PRECISION (MLP_CFG.FC3_INPUT_PRECISION),
        .FC3_WEIGHT_PRECISION(MLP_CFG.FC3_WEIGHT_PRECISION),
        .FC3_OUTPUT_PRECISION(MLP_CFG.FC3_OUTPUT_PRECISION),
        .FC3_BIAS_PRECISION  (MLP_CFG.FC3_BIAS_PRECISION),
        .FC3_MUL_PER_FEATURE (MLP_CFG.FC3_MUL_PER_FEATURE),
        .FC3_N               (MLP_CFG.FC3_N),
        .FC3_M               (MLP_CFG.FC3_M),
        .FC3_IN_ZP           (MLP_CFG.FC3_IN_ZP),
        .FC3_W_ZP            (MLP_CFG.FC3_W_ZP),
        .FC3_OUT_ZP          (MLP_CFG.FC3_OUT_ZP),
        .FC3_M_MUL           (MLP_CFG.FC3_M_MUL),
        .FC3_M_SHIFT         (MLP_CFG.FC3_M_SHIFT),
        .FC3_MEMORY_FILE     ("fc3_weights.mem")
    ) u_mlp_top (
        .clk      (clk),
        .rst      (rst),
        .ce       (ce),
        .in_valid (in_valid),
        .in_ready (in_ready),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .features (features_2d),
        .out      (out_2d)
    );

endmodule