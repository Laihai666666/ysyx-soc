module psram(
  input sck,
  input ce_n,
  inout [3:0] dio
);

  wire reset = ce_n;

  typedef enum [2:0] { cmd_t, addr_t, rdata_t, wdata_t,err_t } state_t;
  reg [2:0]  state;
  reg [7:0]  counter;
  reg [7:0]  cmd;
  reg [23:0] addr;
  reg [31:0] data;
  reg [31:0] wdata;
  reg qpi_flag;
  wire rvalid = (state == addr_t)&&(cmd==8'hEB)&&(counter == 8'd5);
  wire wvalid=(state==wdata_t)&&((counter==8'd1)|(counter==8'd3)|(counter==8'd7));
  
  wire [31:0] rdata;
  wire [31:0] raddr = {8'b0, addr[19:0], dio[3:0]};
  wire [31:0] waddr =  {8'b0, addr};
  wire [31:0] wdata_r={wdata[27:0],dio};
  wire [31:0] wdata_bswap_h = {wdata_r[31:16],wdata_r[7:0], wdata_r[15:8]};
  wire [31:0] wdata_bswap_w = {wdata_r[7:0], wdata_r[15:8], wdata_r[23:16], wdata_r[31:24]};
  wire [31:0] wdata_s=!wvalid?32'b0:
                (counter==8'd1)?wdata_r<<(addr[1:0]*8):
                (counter==8'd3)?wdata_bswap_h<<(addr[1:0]*8):
                wdata_bswap_w;
  wire [3:0] wmask=!wvalid?4'b0:
                  (counter==8'd1)?4'b1<<addr[1:0]:
                  (counter==8'd3)?4'b11<<addr[1:0]:
                  4'b1111;
  psram_cmd psram_cmd_i(
    .clock(sck),
    .rvalid(rvalid),
    .wvalid(wvalid),
    .cmd(cmd),
    .raddr(raddr),
    .waddr(waddr),
    .wdata(wdata_s),
    .wmask(wmask),
    .data(rdata)
  );

  always@(posedge sck or posedge reset) begin
    if (reset) state <= cmd_t;
    else begin
      case (state)
        cmd_t:  state <= (qpi_flag&&counter == 8'd1 ) ? addr_t :
                         (!qpi_flag&&counter == 8'd7 )?addr_t:state;
        addr_t: state <= ((cmd != 8'hEB )&&(cmd != 8'h38 )&&(cmd != 8'h35 )) ? err_t  :
                         ((counter == 8'd5)&&(cmd == 8'hEB)) ? rdata_t : 
                         ((counter == 8'd5)&&(cmd == 8'h38))?wdata_t:state;
        rdata_t: state <= state;
        wdata_t:state<=state;
        default: begin
          state <= state;
          $fwrite(32'h80000002, "Assertion failed: addr:`%x` Unsupported command `%xh`",addr, cmd);
          $fatal;
        end
      endcase
    end
  end
  always@(posedge sck)begin
    if(state==addr_t&&cmd==8'h35)
     qpi_flag<=1'b1;
  end
  always@(posedge sck or posedge reset) begin
    if (reset) counter <= 8'd0;
    else begin
      case (state)
        cmd_t:   counter <= (qpi_flag&&(counter < 8'd1 )) ? counter + 8'd1 :
                             (!qpi_flag&&(counter<8'd7))?counter+8'd1:8'd0;
        addr_t:  counter <= (counter < 8'd5) ? counter + 8'd1 : 8'd0;
        default: counter <= counter + 8'd1;
      endcase
    end
  end
  
  always@(posedge sck or posedge reset) begin
    if (reset)               cmd <= 8'd0;
    else if (state == cmd_t) cmd <= qpi_flag?{cmd[3:0],dio}:{ cmd[6:0], dio[0] };
  end

  always@(posedge sck or posedge reset) begin
    if (reset) addr <= 24'd0;
    else if (state == addr_t && counter < 8'd6) 
      addr <= { addr[19:0], dio };
  end

  wire [31:0] rdata_bswap = {rdata[7:0], rdata[15:8], rdata[23:16], rdata[31:24]};
  always@(posedge sck or posedge reset) begin
    if (reset) begin
      data <= 32'd0;
      wdata<=32'd0;
    end
    else if (state == rdata_t) begin
      data <= { {counter == 8'd7 ? rdata_bswap : data}[27:0], 4'b0 };
    end
    else if (state==wdata_t)begin
      wdata<={wdata[27:0],dio};
    end
  end

  assign dio = ce_n ? 4'b1111 : ({(state == rdata_t && counter == 8'd7) ? rdata_bswap : data}[31:28]);

endmodule

import "DPI-C" function void psram_read(input int addr, output int data);
import "DPI-C" function void psram_write(input int addr, input int data,input int wmask);

module psram_cmd(
  input             clock,
  input             rvalid,
  input             wvalid,
  input       [7:0] cmd,
  input      [31:0] raddr,
  input      [31:0] waddr,
  input       [31:0] wdata,
  input       [3:0] wmask,
  output reg [31:0] data
);
 wire [31:0] wmask_a = {{8{wmask[3]}},{8{wmask[2]}},{8{wmask[1]}},{8{wmask[0]}}};
  always@(posedge clock) begin
    if (rvalid)
      if (cmd == 8'hEB) psram_read(raddr, data);
      else begin
        $fwrite(32'h80000002, "Assertion failed: Unsupport command `%xh`\n", cmd);
        $fatal;
      end
    if (wvalid)
      if(cmd== 8'h38) begin 
        //$fwrite(32'h80000002, "Assertion failed: `%xh` `%xh`\n", waddr,wdata);
        psram_write(waddr, wdata,wmask_a);
      end
      else begin
        $fwrite(32'h80000002, "Assertion failed: Unsupport command `%xh`\n", cmd);
        $fatal;
      end
  end
endmodule
