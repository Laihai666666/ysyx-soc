module vga_top_apb(
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

  output [7:0]  vga_r,
  output [7:0]  vga_g,
  output [7:0]  vga_b,
  output        vga_hsync,
  output        vga_vsync,
  output        vga_valid
);


  parameter    h_frontporch = 96;
  parameter    h_active = 144;
  parameter    h_backporch = 784;
  parameter    h_total = 800;

  parameter    v_frontporch = 2;
  parameter    v_active = 35;
  parameter    v_backporch = 515;
  parameter    v_total = 525;

  // 帧缓冲SRAM (640x480x24bit)
  reg [23:0] frame_buffer[0:307199]; // 640*480-1

  //像素计数值
  reg [9:0]    x_cnt;
  reg [9:0]    y_cnt;
  wire         h_valid;
  wire         v_valid;

  // APB接口逻辑
  assign in_pready = 1'b1;
  assign in_pslverr = 1'b0;

  always @(posedge reset or posedge clock) //行像素计数
      if (reset == 1'b1)
        x_cnt <= 1;
      else
      begin
        if (x_cnt == h_total)
            x_cnt <= 1;
        else
            x_cnt <= x_cnt + 10'd1;
      end

  always @(posedge clock)  //列像素计数
      if (reset == 1'b1)
        y_cnt <= 1;
      else
      begin
        if (y_cnt == v_total & x_cnt == h_total)
            y_cnt <= 1;
        else if (x_cnt == h_total)
            y_cnt <= y_cnt + 10'd1;
      end

  //生成同步信号
  assign vga_hsync = (x_cnt > h_frontporch);
  assign vga_vsync = (y_cnt > v_frontporch);
  
  //生成消隐信号
  assign h_valid = (x_cnt > h_active) & (x_cnt <= h_backporch);
  assign v_valid = (y_cnt > v_active) & (y_cnt <= v_backporch);
  assign vga_valid = h_valid & v_valid;

  //计算当前有效像素地址
  wire [18:0] pixel_addr = ( {9'b0, y_cnt} - 19'd36 ) * 19'd640 + 
                          ( {9'b0, x_cnt} - 19'd145 );

  //像素数据读取
  wire [23:0] pixel_data = frame_buffer[pixel_addr];
  assign {vga_r, vga_g, vga_b} = vga_valid ? 
    {pixel_data[23:16], pixel_data[15:8], pixel_data[7:0]} : 24'b0;

  // APB写操作
  always @(posedge clock) begin
    if (in_psel && in_penable && in_pwrite) begin
      frame_buffer[in_paddr[18:0]] <= in_pwdata[23:0];
    end
  end

  // APB读操作
  assign in_prdata = {8'b0, frame_buffer[in_paddr[18:0]]};

endmodule
