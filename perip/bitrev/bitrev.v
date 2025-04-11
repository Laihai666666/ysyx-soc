module bitrev (
  input  sck,
  input  ss,
  input  mosi,
  output miso
);

    wire rst = ss;
    reg [4:0] count;
    reg [7:0] reg1;
    always @(posedge sck or posedge rst) begin
        if (rst) begin
            count <= 5'b0;
            reg1 <= 8'b0;
        end else begin
            count <= count + 1;
            if (count < 8) begin
                reg1 <=  {reg1[6:0], mosi};
            end  else begin
                reg1 <= reg1 >> 1;
            end
        end
    end
    assign miso=(ss)?1'b1:(count<8?1'b0:reg1[0]);
endmodule
