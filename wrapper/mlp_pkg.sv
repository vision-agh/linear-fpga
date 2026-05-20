// =============================================================================
// mlp_pkg.sv  -  Single source of truth for all MLP configuration parameters.
//
// Import with:  import mlp_pkg::*;
//
// =============================================================================
`timescale 1ns / 1ps

package mlp_pkg;

    typedef struct packed {
        int NUM_FEATURES;
        int FC1_TEMP;  int FC1_INPUT_PRECISION;  int FC1_WEIGHT_PRECISION;
        int FC1_OUTPUT_PRECISION; int FC1_BIAS_PRECISION; int FC1_MUL_PER_FEATURE;
        int FC1_N; int FC1_M;
        int FC1_IN_ZP; int FC1_W_ZP; int FC1_OUT_ZP;
        int FC1_M_MUL; int FC1_M_SHIFT;
        int FC2_TEMP;  int FC2_INPUT_PRECISION;  int FC2_WEIGHT_PRECISION;
        int FC2_OUTPUT_PRECISION; int FC2_BIAS_PRECISION; int FC2_MUL_PER_FEATURE;
        int FC2_N; int FC2_M;
        int FC2_IN_ZP; int FC2_W_ZP; int FC2_OUT_ZP;
        int FC2_M_MUL; int FC2_M_SHIFT;
        int FC3_TEMP;  int FC3_INPUT_PRECISION;  int FC3_WEIGHT_PRECISION;
        int FC3_OUTPUT_PRECISION; int FC3_BIAS_PRECISION; int FC3_MUL_PER_FEATURE;
        int FC3_N; int FC3_M;
        int FC3_IN_ZP; int FC3_W_ZP; int FC3_OUT_ZP;
        int FC3_M_MUL; int FC3_M_SHIFT;
    } mlp_cfg_t;

 
    // =========================================================================
    
    localparam mlp_cfg_t MLP_CFG = '{
        NUM_FEATURES        : 1,

        // FC1  (784 -> 128, serial split = 8) 
        FC1_TEMP            : -8,
        FC1_INPUT_PRECISION : 8,
        FC1_WEIGHT_PRECISION: 8,
        FC1_OUTPUT_PRECISION: 8,
        FC1_BIAS_PRECISION  : 32,
        FC1_MUL_PER_FEATURE : 1,
        FC1_N               : 784,
        FC1_M               : 128,
        FC1_IN_ZP           : 128,
        FC1_W_ZP            : 133,
        FC1_OUT_ZP          : 131,
        FC1_M_MUL           : 1616892571,
        FC1_M_SHIFT         : 43,

        // FC2  (128 -> 128, serial split = 2)
        FC2_TEMP            : -2,
        FC2_INPUT_PRECISION : 8,
        FC2_WEIGHT_PRECISION: 8,
        FC2_OUTPUT_PRECISION: 8,
        FC2_BIAS_PRECISION  : 32,
        FC2_MUL_PER_FEATURE : 1,
        FC2_N               : 128,
        FC2_M               : 128,
        FC2_IN_ZP           : 131,
        FC2_W_ZP            : 151,
        FC2_OUT_ZP          : 146,
        FC2_M_MUL           : 1256414064,
        FC2_M_SHIFT         : 39,

        // FC3  (128 -> 10, serial split = 2)
        FC3_TEMP            : -2,
        FC3_INPUT_PRECISION : 8,
        FC3_WEIGHT_PRECISION: 8,
        FC3_OUTPUT_PRECISION: 8,
        FC3_BIAS_PRECISION  : 32,
        FC3_MUL_PER_FEATURE : 1,
        FC3_N               : 128,
        FC3_M               : 10,
        FC3_IN_ZP           : 146,
        FC3_W_ZP            : 168,
        FC3_OUT_ZP          : 168,
        FC3_M_MUL           : 1342371887,
        FC3_M_SHIFT         : 40
    };

    // Flat bus widths derived from MLP_CFG - used in mlp_flat_shim port declarations
    localparam int FEAT_BITS =
        MLP_CFG.NUM_FEATURES * MLP_CFG.FC1_N * MLP_CFG.FC1_INPUT_PRECISION;  // 6272
    localparam int OUT_BITS  =
        MLP_CFG.NUM_FEATURES * MLP_CFG.FC3_M * MLP_CFG.FC3_OUTPUT_PRECISION; //   80

endpackage