// define this macro to enable fast behavior simulation
// for flash by skipping SPI transfers
//`define FAST_FLASH

module spi_top_apb #(
  parameter flash_addr_start = 32'h30000000,
  parameter flash_addr_end   = 32'h3fffffff,
  parameter spi_ss_num       = 8
) (
  input         clock,
  input         reset,
  input  [31:0] in_paddr,
  input         in_psel,
  input         in_penable,
  input  [2:0]  in_pprot,
  input         in_pwrite,
  input  [31:0] in_pwdata,
  input  [3:0]  in_pstrb,
  output        in_pready,
  output [31:0] in_prdata,
  output        in_pslverr,

  output                  spi_sck,
  output [spi_ss_num-1:0] spi_ss,
  output                  spi_mosi,
  input                   spi_miso,
  output                  spi_irq_out
);

`ifdef FAST_FLASH

wire [31:0] data;
parameter invalid_cmd = 8'h0;
flash_cmd flash_cmd_i(
  .clock(clock),
  .valid(in_psel && !in_penable),
  .cmd(in_pwrite ? invalid_cmd : 8'h03),
  .addr({8'b0, in_paddr[23:2], 2'b0}),
  .data(data)
);
assign spi_sck    = 1'b0;
assign spi_ss     = 8'b0;
assign spi_mosi   = 1'b1;
assign spi_irq_out= 1'b0;
assign in_pslverr = 1'b0;
assign in_pready  = in_penable && in_psel && !in_pwrite;
assign in_prdata  = data[31:0];

`else
wire [4:0] paddr; 
wire [31:0] pwdata;
wire pwrite;
wire [3:0] pstrb;
wire pready;
wire [31:0] prdata;
wire [31:0] prdata_r={prdata[7:0], prdata[15:8], prdata[23:16], prdata[31:24]};
wire pslverr;
wire irq_out;
typedef enum [2:0] { idle,xip_tx,xip_div,xip_ss,xip_csr,xip_r,xip_f,spi_master_t} state_t;
reg [2:0]  state;
always@(posedge clock ) begin
    if (reset) state <= idle;
    else begin
      case (state)
        idle:  state <= (in_psel) ? ((in_paddr<=32'h10001fff&&in_paddr>=32'h10001000)?spi_master_t:xip_tx): state;
        xip_tx: state <=pready?xip_div:state;
        xip_div: state <=pready?xip_ss:state;
        xip_ss: state <=pready?xip_csr:state;
        xip_csr: state <=pready?xip_r:state;
        xip_r:  state <=irq_out?xip_f:state;
        xip_f: state <=pready?idle:state;
        spi_master_t:  state<= pready?idle:state;
      endcase
    end
end 

assign paddr=(state==xip_tx)?5'h4:
            (state==xip_div)?5'h8:
            (state==xip_ss)?5'h18:
            (state==xip_csr)?5'h10:
            (state==xip_r)?5'h0:
            (state==xip_f)?5'h0:
            (state==spi_master_t)?in_paddr[4:0]:5'h0;

assign pwdata=(state==xip_tx)?(32'h03000000|{8'b0,in_paddr[23:0]}):
            (state==xip_div)?32'h1:
            (state==xip_ss)?32'h1:
            (state==xip_csr)?32'h3140:
            (state==spi_master_t)?in_pwdata:32'h0;
assign pwrite=(state==xip_tx)?1'b1:
            (state==xip_div)?1'b1:
            (state==xip_ss)?1'b1:
            (state==xip_csr)?1'b1:
            (state==spi_master_t)?in_pwrite:1'b0;
assign pstrb=(state==xip_tx)?4'hf:
            (state==xip_div)?4'hf:
            (state==xip_ss)?4'hf:
            (state==xip_csr)?4'hf:
            (state==spi_master_t)?in_pstrb:0;
assign in_pready=(state==xip_f)?pready:
            (state==spi_master_t)?pready:1'b0;
assign in_prdata=(state==xip_f)?prdata_r:
            (state==spi_master_t)?prdata:32'b0;
assign spi_irq_out=(state==spi_master_t)?irq_out:1'b0;
assign in_pslverr= ((state==xip_tx)&&in_pwrite)|pslverr;
spi_top u0_spi_top (
  .wb_clk_i(clock),
  .wb_rst_i(reset),
  .wb_adr_i(paddr),
  .wb_dat_i(pwdata),
  .wb_dat_o(prdata),
  .wb_sel_i(pstrb),
  .wb_we_i (pwrite),
  .wb_stb_i(in_psel),
  .wb_cyc_i(in_penable),
  .wb_ack_o(pready),
  .wb_err_o(pslverr),
  .wb_int_o(irq_out),

  .ss_pad_o(spi_ss),
  .sclk_pad_o(spi_sck),
  .mosi_pad_o(spi_mosi),
  .miso_pad_i(spi_miso)
);

`endif // FAST_FLASH

endmodule
