package ysyx

import chisel3._
import chisel3.util._

import org.chipsalliance.cde.config.Parameters
import freechips.rocketchip.amba._
import freechips.rocketchip.amba.apb._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.util._

class APBDelayerIO extends Bundle {
  val clock = Input(Clock())
  val reset = Input(Reset())
  val in = Flipped(new APBBundle(APBBundleParameters(addrBits = 32, dataBits = 32)))
  val out = new APBBundle(APBBundleParameters(addrBits = 32, dataBits = 32))
}

class apb_delayer extends BlackBox {
  val io = IO(new APBDelayerIO)
}

class APBDelayerChisel extends Module {
  val io = IO(new APBDelayerIO)

  // 时钟频率比：318.858MHz/100MHz ≈ 51/16 = 3.1875 
  // r=2.1875
  val CLK_RATIO_NUM = 85.U
  val CLK_RATIO_DEN = 32.U

  // 延迟控制状态
  val idle :: sAccum :: sCountDown :: Nil = Enum(3)
  val state = RegInit(idle)
  
  // 计数器
  val count = RegInit(0.U(32.W))
  val data = RegInit(0.U(32.W))
  val finsh =RegInit(false.B)
  // 输出信号
  io.out.psel    := Mux(finsh,0.U,io.in.psel)
  io.out.penable := Mux(finsh,0.U,io.in.penable)
  io.out.pwrite  := io.in.pwrite
  io.out.paddr   := io.in.paddr
  io.out.pwdata  := io.in.pwdata
  io.out.pprot   := io.in.pprot
  io.out.pstrb   := io.in.pstrb 

  // 延迟控制逻辑
  switch(state) {
    is(idle) {
      when(io.in.psel && io.in.penable) {
        state := sAccum
        count := CLK_RATIO_NUM + CLK_RATIO_DEN 
      }
    }
    is(sAccum) {
      count := count + CLK_RATIO_NUM
      when(io.out.pready) {
        state := sCountDown
        data := io.out.prdata
        count := count/CLK_RATIO_DEN
        finsh := true.B
      }
    }
    is(sCountDown) {
      count := count - 1.U
      when(count === 0.U) {
        state := idle
        finsh := false.B
      }
    }
  }
  io.in.pready := (state === sCountDown) && (count === 0.U)
  io.in.prdata := data
  io.in.pslverr := io.out.pslverr
}

class APBDelayerWrapper(implicit p: Parameters) extends LazyModule {
  val node = APBIdentityNode()

  lazy val module = new Impl
  class Impl extends LazyModuleImp(this) {
    (node.in zip node.out) foreach { case ((in, edgeIn), (out, edgeOut)) =>
      val delayer = Module(new APBDelayerChisel)
      delayer.io.clock := clock
      delayer.io.reset := reset
      delayer.io.in <> in
      out <> delayer.io.out
    }
  }
}

object APBDelayer {
  def apply()(implicit p: Parameters): APBNode = {
    val apbdelay = LazyModule(new APBDelayerWrapper)
    apbdelay.node
  }
}
