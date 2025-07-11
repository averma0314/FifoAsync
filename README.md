_**Async FIFO parameterized design in SystemVerilog**_

**Asynchronous FIFO:**

FIFO stands for First In First Out. A FIFO is a buffer memory element that is used to safely pass data from one clock domain to another asynchronous clock domain. It is commonly used in designs to safely pass multi-bit data words from one clock domain to another. Data words are placed into a FIFO buffer memory array by control signals in one clock domain, and the data words are removed from another port of the same FIFO buffer memory array by control signals from a second clock domain. Such FIFO buffer memories are called asynchronous FIFOs.

The other category of FIFOs are synchronous FIFOs where writes to and reads from the FIFO buffer are conducted in the same clock domain. Such kinds of FIFO buffer memories are used as temporary storage while the receiver is busy with other tasks. This document is talking primarily about asynchronous FIFO buffer memories.  

**FIFO pointers:**

For correct FIFO operation pointers are used to keep track of the write and read addresses of the FIFO buffer.
The write pointer always points to the next word to be written. On a FIFO-write operation, the memory location that is pointed to by the write pointer is written, and then the write pointer is incremented to point to the next location to be written. Note that the write pointer is clocked by the writer's clock.

The read pointer always points to the current FIFO word to be read. Once the first data word is written to the FIFO, the write pointer increments, the empty flag is cleared, and the read pointer immediately drives that first valid word onto the FIFO data output port, to be read by the receiver logic. Note that there should be no flop on the read data output port. The receiver logic does not have to use two clock periods to read the data word. Note that the read pointer is clocked by the reader’s clock.

**Full and Empty conditions:**

The FIFO is empty when the read and write pointers are both equal. This condition happens when both pointers are reset to zero during a reset operation, or when the read pointer catches up to the write pointer, having read the last word from the FIFO. 
A FIFO is full when the pointers are again equal, that is, when the write pointer has wrapped around and caught up to the read pointer. 
In order to distinguish between Full and Empty we will add an extra bit to each pointer (n + 1 bits). When the write pointer increments past the final FIFO address, the write pointer will increment the unused MSB while setting the rest of the bits back to zero. The same is done with the read pointer. 

FifoAsync_v1.sv contains parameterized RTL for async FIFO in SystemVerilog. The number of entries in the FIFO are determined by the parameter DEPTH which should be a power of 2. The data width is determinded by parameter DATA_WIDTH. 
