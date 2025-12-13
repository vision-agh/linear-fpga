module unit_test #(
  parameter int PRECISION   = 8,
  parameter int BIAS_PRECISION = 32,
  parameter int NUM_FEATURES = 2, //number of parallel features
  parameter int N = 10,
  parameter int M = 12,
  parameter int  M_MUL = 12345,
  parameter int  Z_WEIGHTS = 5
) (
);

logic [PRECISION-1:0] features [N][NUM_FEATURES];

endmodule
