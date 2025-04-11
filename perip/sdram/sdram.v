
module sdram(
  input        clk,
  input        cke,
  input        cs,
  input        ras,
  input        cas,
  input        we,
  input [12:0] a,
  input [ 2:0] ba,
  input [3:0] dqm,
  inout [31:0] dq
);

wire [15:0] dq1=dq[15:0];
wire [15:0] dq2=dq[31:16];
wire [15:0] dq1_o,dq2_o;
wire [31:0] dq_l={dq2_o,dq1_o};
sdram_o sdram_a(
  .clk(clk),
  .cke(cke),
  .cs(cs),
  .ras(ras),
  .cas(cas),
  .we(we),
  .a(a),
  .ba(ba[1:0]),
  .dqm(dqm[1:0]),
  .dq(dq1),
  .dq_o(dq1_o),
  .req(!ba[2])
);
sdram_o sdram_b(
  .clk(clk),
  .cke(cke),
  .cs(cs),
  .ras(ras),
  .cas(cas),
  .we(we),
  .a(a),
  .ba(ba[1:0]),
  .dqm(dqm[3:2]),
  .dq(dq2)  ,
  .dq_o(dq2_o),
  .req(!ba[2])
);

wire [15:0] dq3=dq[15:0];
wire [15:0] dq4=dq[31:16];
wire [15:0] dq3_o,dq4_o;
wire [31:0] dq_h={dq4_o,dq3_o};
sdram_o sdram_c(
  .clk(clk),
  .cke(cke),
  .cs(cs),
  .ras(ras),
  .cas(cas),
  .we(we),
  .a(a),
  .ba(ba[1:0]),
  .dqm(dqm[1:0]),
  .dq(dq3),
  .dq_o(dq3_o),
  .req(ba[2])
);
sdram_o sdram_d(
  .clk(clk),
  .cke(cke),
  .cs(cs),
  .ras(ras),
  .cas(cas),
  .we(we),
  .a(a),
  .ba(ba[1:0]),
  .dqm(dqm[3:2]),
  .dq(dq4)  ,
  .dq_o(dq4_o),
  .req(ba[2])
);
assign dq=ba[2]?dq_h:dq_l;
endmodule







module sdram_o(
  input        clk,
  input        cke,
  input        cs,
  input        ras,
  input        cas,
  input        we,
  input [12:0] a,
  input [ 1:0] ba,
  input [1:0] dqm,
  input [15:0] dq,
  output [15:0] dq_o,
  input        req
);
  reg [15:0] memory[0:((1<<24)-1)];
 
  reg [2:0] cas_latency;
  reg [2:0] burst_length;
  reg [12:0] mode_reg;

  wire load_mode_reg = ~cs & ~ras & ~cas & ~we;
  wire precharge     = ~cs & ~ras &  cas & ~we;
  wire auto_refresh  = ~cs & ~ras & ~cas &  we;
  wire active        = ~cs & ~ras &  cas &  we;
  wire read          = ~cs &  ras & ~cas &  we;
  wire write         = ~cs &  ras & ~cas & ~we;
  wire burst_term    = ~cs &  ras &  cas & ~we;
  wire nop           = ~cs & (ras & cas & we);
  always @(posedge clk) begin
    if (load_mode_reg) begin
      cas_latency <= a[6:4];
      burst_length <= a[2:0];
    end
  end
  reg [12:0] active_row[3:0];
  reg [3:0]  bank_active;
  reg [1:0]  ba_r;
  
  reg [15:0] read_data;
  reg        read_valid;
  reg [2:0]    read_counter;
  reg [2:0]  burst_counter;
  reg [8:0] burst_address;
  reg        burst_read;
  reg        burst_write;
  always @(posedge clk) begin
    if (~cke) begin
      read_valid <= 1'b0;
      burst_read <= 1'b0;
      burst_write <= 1'b0;
    end
    else if (precharge || auto_refresh) begin
    end
    else if (active) begin
      active_row[ba] <= a;
      bank_active[ba] <= 1'b1;
    end
    else if (read) begin
      if (bank_active[ba]) begin
        read_counter <= cas_latency;
        burst_counter <= burst_length;
        burst_address <= a[8:0];
        burst_read <= 1'b1;
        burst_write <= 1'b0;
        ba_r<=ba;
      end
    end
    else if (write && req) begin
      if (bank_active[ba]) begin
        memory[{active_row[ba], ba, a[8:0]}] <= (dq & ~{{8{dqm[1]}},{8{dqm[0]}}}) |
                                                (memory[{active_row[ba], ba, a[8:0]}]
                                                 & {{8{dqm[1]}},{8{dqm[0]}}});
        burst_counter <= burst_length;
        burst_address <= a[8:0];
        burst_read <= 1'b0;
        burst_write <= 1'b1;
      end
    end
    else if (burst_term) begin
      read_valid <= 1'b0;
      burst_read <= 1'b0;
      burst_write <= 1'b0;
    end
    if (read_counter > 0) begin
      read_counter <= read_counter - 1;
      if (read_counter == 1) begin
        read_data <= memory[{active_row[ba_r],ba_r,  burst_address}];
        read_valid <= 1'b1;
      end
    end     
    /* if  (read_valid)begin
      $display("read_data=%h",read_data);
    end */
    if (burst_read && read_valid && burst_counter > 0) begin
      read_data <= memory[{active_row[ba_r],ba_r,  burst_address}];
      burst_counter <= burst_counter - 1;
      burst_address <= burst_address + 1;
    end
    if (read_counter==0) begin
      read_valid <= 1'b0;
    end  

    if (burst_write && burst_counter > 0) begin
      burst_counter <= burst_counter - 1;
      burst_address <= burst_address + 1;
      memory[{ active_row[ba],ba, burst_address + 1'b1}] <= (dq & ~{{8{dqm[1]}},{8{dqm[0]}}})|
                                                            ( memory[{active_row[ba],ba,  a[8:0]}]
                                                            & {{8{dqm[1]}},{8{dqm[0]}}});
      
    end
  end
  assign dq_o = (cke && read_valid) ? read_data : 16'bz;

endmodule
