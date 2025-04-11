package ysyx

import chisel3._
import chisel3.util._

import freechips.rocketchip.amba.apb._
import org.chipsalliance.cde.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.util._

class PS2IO extends Bundle {
  val clk = Input(Bool())
  val data = Input(Bool())
}

class PS2CtrlIO extends Bundle {
  val clock = Input(Clock())
  val reset = Input(Bool())
  val in = Flipped(new APBBundle(APBBundleParameters(addrBits = 32, dataBits = 32)))
  val ps2 = new PS2IO
}

class ps2_top_apb extends BlackBox {
  val io = IO(new PS2CtrlIO)
}

class ps2Chisel extends Module {
  val io = IO(new PS2CtrlIO)
  
  io.in.pready := true.B
  io.in.pslverr := false.B
  io.in.prdata := 0.U

  val ps2_clk_sync = Reg(Vec(3, Bool()))
  ps2_clk_sync(0) := io.ps2.clk
  ps2_clk_sync(1) := ps2_clk_sync(0) 
  ps2_clk_sync(2) := ps2_clk_sync(1)
   
  val sampling = ps2_clk_sync(2) && !ps2_clk_sync(1) 

  val count = RegInit(0.U(4.W))
  val shift_reg = RegInit(0.U(10.W))
  val fifo = Reg(Vec(8, UInt(8.W)))
  val wr_ptr = RegInit(0.U(3.W))
  val rd_ptr = RegInit(0.U(3.W))
  val empty = (wr_ptr === rd_ptr)


  when (sampling) {
    when (count === 10.U) {
      when (!shift_reg(0) && io.ps2.data && shift_reg(9,1).xorR) {
          fifo(wr_ptr) := shift_reg(8,1)
          wr_ptr := Mux(wr_ptr === 7.U, 0.U, wr_ptr + 1.U)
      }
      count := 0.U
    }.otherwise {
      shift_reg := (shift_reg >> 1) | (io.ps2.data << 9)
      count := count + 1.U
    }
  }

  when (io.in.psel && io.in.penable && !io.in.pwrite) {
    when (io.in.paddr(2,0) === 0x0.U) {
      when (!empty) {
        io.in.prdata := Cat(0.U(24.W), fifo(rd_ptr))
        rd_ptr := Mux(rd_ptr === 7.U, 0.U, rd_ptr + 1.U)
      }.otherwise {
        io.in.prdata := 0.U
      }
    }
  }
}

class APBKeyboard(address: Seq[AddressSet])(implicit p: Parameters) extends LazyModule {
  val node = APBSlaveNode(Seq(APBSlavePortParameters(
    Seq(APBSlaveParameters(
      address       = address,
      executable    = true,
      supportsRead  = true,
      supportsWrite = true)),
    beatBytes  = 4)))

  lazy val module = new Impl
  class Impl extends LazyModuleImp(this) {
    val (in, _) = node.in(0)
    val ps2_bundle = IO(new PS2IO)

    val mps2 = Module(new ps2Chisel)
    mps2.io.clock := clock
    mps2.io.reset := reset
    mps2.io.in <> in
    ps2_bundle <> mps2.io.ps2
  }
}
