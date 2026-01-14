module unit_test (
);

//`include "params.txt"
localparam int TEMP           = -2;
localparam int NUM_EXAMPLES   = 1;
localparam int PRECISION      = 8;
localparam int BIAS_PRECISION = 32;
localparam int NUM_FEATURES   = 1;
localparam int MUL_PER_FEATURE= 1;
localparam int N              = 24;
localparam int M              = 16;
localparam int M_MUL          = 7900041;
localparam int Z_WEIGHTS      = 128;

logic [PRECISION-1:0] raw_examples [N*NUM_FEATURES*NUM_EXAMPLES];
logic [PRECISION-1:0] examples [NUM_EXAMPLES][NUM_FEATURES][N];
logic [PRECISION-1:0] features [NUM_FEATURES][N];
logic [PRECISION-1:0] out [NUM_FEATURES][M];
logic [PRECISION-1:0] latched_out [NUM_FEATURES][M];
logic clk = 1;
logic ce = 1;
logic rst = 1;

integer ex, fea, n, i;

initial begin
  $readmemh("features.txt", raw_examples);
  // unflatten
  for (i = 0; i < NUM_EXAMPLES*NUM_FEATURES*N; i = i + 1) begin
      ex = i / (NUM_FEATURES * N);
      fea = (i / N) % NUM_FEATURES;
      n = i % N;
      examples[ex][fea][n] = raw_examples[i];
  end
end

always #1 clk = ~clk;

logic out_ready;
logic out_valid = 0;
logic in_ready;
logic in_valid = 0;

top_module #(
  .TEMP(TEMP),
  .PRECISION(PRECISION),
  .BIAS_PRECISION(BIAS_PRECISION),
  .NUM_FEATURES(NUM_FEATURES),
  .N(N),
  .M(M),
  .M_MUL(M_MUL),
  .Z_WEIGHTS(Z_WEIGHTS)
) dut
(
    .out_valid(in_valid),
    .in_ready(out_ready),
    .in_valid(out_valid),
    .out_ready(in_ready),
    .clk(clk),
    .rst(rst),
    .ce(ce),
    .features(features),
    .out(out)
);

typedef enum logic [3:0] {
  LOAD,
  SEND,
  RECEIVE,
  SAVE,
  FINISHED
} state_t;

state_t stan = LOAD;
logic [31:0] index = 0;

string filename; // 64-char filename buffer
integer file;
integer f, m;

always_ff @(posedge clk) begin : StateMachine
  unique case (stan)
    LOAD: begin
      if (index < NUM_EXAMPLES) begin
        features <= examples[index];
        rst <= 0;
        stan <= SEND;
        index += 1;
      end else begin
        $display("FINISHED");
        stan <= FINISHED;
      end
    end
    SEND: begin
      out_valid <= 1;
      if (out_valid && out_ready) begin
        out_valid <= 0;
        stan <= RECEIVE;
      end
    end
    RECEIVE: begin
      in_ready <= 1;
      if (in_ready && in_valid) begin
        in_ready <= 0;
        stan <= SAVE;
        latched_out <= out;
      end
    end
    SAVE: begin
      filename = $sformatf("output_example_%0d.bin", index);

      // Open file for writing
      file = $fopen(filename, "wb");
      if (file) begin
        // Write latched_out to file
        for (int f = 0; f < NUM_FEATURES; f++) begin
          for (int m = 0; m < M; m++) begin
            $fwrite(file, "%0d\n", latched_out[f][m]);
          end
        end
        $fclose(file);
        $display("Saved example %0d to %s", index, filename);
      end else begin
        $display("ERROR: Could not open file %s", filename);
      end
      stan <= LOAD;
    end
    FINISHED: begin
      $finish;
    end
  endcase
end

endmodule