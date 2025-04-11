package ysyx

import chisel3._
import chisel3.util._

import freechips.rocketchip.amba.apb._
import org.chipsalliance.cde.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.util._

class GPIOIO extends Bundle {
  val out = Output(UInt(16.W))
  val in = Input(UInt(16.W))
  val seg = Output(Vec(8, UInt(8.W)))
}

class GPIOCtrlIO extends Bundle {
  val clock = Input(Clock())
  val reset = Input(Reset())
  val in = Flipped(new APBBundle(APBBundleParameters(addrBits = 32, dataBits = 32)))
  val gpio = new GPIOIO
}

class gpio_top_apb extends BlackBox {
  val io = IO(new GPIOCtrlIO)
}

class gpioChisel extends Module {
  val io = IO(new GPIOCtrlIO)
  
  io.in.pready := true.B  
  io.in.pslverr := false.B 
  io.in.prdata := 0.U    
  
  val led_reg = RegInit(0.U(16.W))    
  val seg_reg = RegInit(0.U(32.W))    
  val switch_reg = RegInit(0.U(16.W))
 
  when (io.in.psel && io.in.penable) {
    when (io.in.pwrite) {
      switch (io.in.paddr(3,0)) {
        is (0x0.U) { led_reg := io.in.pwdata(15,0) }
        is (0x8.U) { seg_reg := io.in.pwdata }
      }
    }.otherwise {
      io.in.prdata := MuxCase(0.U, Seq(
        (io.in.paddr(3,0) === 0x0.U) -> Cat(0.U(16.W), led_reg),
        (io.in.paddr(3,0) === 0x4.U) -> Cat(0.U(16.W), switch_reg), 
        (io.in.paddr(3,0) === 0x8.U) -> seg_reg
      ))
    }
  }
  io.gpio.out := led_reg

  switch_reg := io.gpio.in

  val seg_map = VecInit(Seq(
    "b11111100".U, // 0
    "b01100000".U, // 1 
    "b11011010".U, // 2
    "b11110010".U, // 3
    "b01100110".U, // 4
    "b10110110".U, // 5
    "b10111110".U, // 6
    "b11100000".U,  // 7
    "b11111110".U, // 8
    "b11110110".U // 9
  ))
  io.gpio.seg := VecInit(Seq.tabulate(8)(i => {
    ~(seg_map(seg_reg(4*i+3, 4*i))) 
  }))
  
}

class APBGPIO(address: Seq[AddressSet])(implicit p: Parameters) extends LazyModule {
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
    val gpio_bundle = IO(new GPIOIO)

    val mgpio = Module(new gpioChisel)
    mgpio.io.clock := clock
    mgpio.io.reset := reset
    mgpio.io.in <> in
    gpio_bundle <> mgpio.io.gpio
  }
}
