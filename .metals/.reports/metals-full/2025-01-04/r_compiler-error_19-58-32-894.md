file://<WORKSPACE>/src/device/BitRev.scala
### java.lang.IndexOutOfBoundsException: -1

occurred in the presentation compiler.

presentation compiler configuration:


action parameters:
offset: 318
uri: file://<WORKSPACE>/src/device/BitRev.scala
text:
```scala
package ysyx

import chisel3._
import chisel3.util._

class bitrev extends BlackBox {
  val io = IO(Flipped(new SPIIO(1)))
}

class bitrevChisel extends RawModule { // we do not need clock and reset
  val io = IO(Flipped(new SPIIO(1)))
  val rst=io.ss(6)
  withReset(rst.asAsyncReset){
    val count=withClock(io.sck)(@@RegInit(0.U(3.W))
    val reg=withClock(io.sck)RegInit(0.U(8.W))
    when(count<8.U){
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

```



#### Error stacktrace:

```
scala.collection.LinearSeqOps.apply(LinearSeq.scala:129)
	scala.collection.LinearSeqOps.apply$(LinearSeq.scala:128)
	scala.collection.immutable.List.apply(List.scala:79)
	dotty.tools.dotc.util.Signatures$.applyCallInfo(Signatures.scala:244)
	dotty.tools.dotc.util.Signatures$.computeSignatureHelp(Signatures.scala:101)
	dotty.tools.dotc.util.Signatures$.signatureHelp(Signatures.scala:88)
	dotty.tools.pc.SignatureHelpProvider$.signatureHelp(SignatureHelpProvider.scala:47)
	dotty.tools.pc.ScalaPresentationCompiler.signatureHelp$$anonfun$1(ScalaPresentationCompiler.scala:422)
```
#### Short summary: 

java.lang.IndexOutOfBoundsException: -1