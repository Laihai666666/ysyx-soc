package ysyx

import chisel3._
import chisel3.util._

class bitrev extends BlackBox {
  val io = IO(Flipped(new SPIIO(1)))
}

class bitrevChisel extends RawModule { // we do not need clock and reset
  val io = IO(Flipped(new SPIIO(1)))
  val rst=io.ss.asBool.asAsyncReset
  withClockAndReset(io.sck.asClock,rst){
    val count=RegInit(0.U(3.W))
    val reg=RegInit(0.U(8.W))
    when(count<=7.U){
      count:=count+1.U
      reg:=reg<<1|io.mosi
      io.miso:=true.B
    }.otherwise{
      count:=count
      reg:=reg>>1
      io.miso := reg(0)
    }
  }
}
