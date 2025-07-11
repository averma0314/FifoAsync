// Async FIFO parameterized design

//------------------------------------------------------------------------------
// WRITE POINTER
//------------------------------------------------------------------------------
// The write pointer always points to the next word to be written. 
// On a FIFO-write operation, the memory location that is pointed to by the write pointer is written, and then the write pointer is incremented to point to the next location to be written. 

//------------------------------------------------------------------------------
// READ POINTER
//------------------------------------------------------------------------------
// The read pointer always points to the current FIFO word to be read. 
// Once the first data word is written to the FIFO, the write pointer increments, the empty flag is cleared, and the read pointer, immediately drives that first valid word onto the FIFO data output port, to be read by the receiver logic. Note that there should be no flop on read data output port. 
// The receiver logic does not have to use two clock periods to read the data word. I

//------------------------------------------------------------------------------
// FULL and EMPTY CONDITIONS
//------------------------------------------------------------------------------
// The FIFO is empty when the read and write pointers are both equal. This condition happens when both pointers are reset to zero during a reset operation, or when the read pointer catches up to the write pointer, having read the last word from the FIFO. 
// A FIFO is full when the pointers are again equal, that is, when the write pointer has wrapped around and caught up to the read pointer. 
// In order to distinguish between Full and Empty we will add an extra bit to each pointers (n + 1 bits). When the write pointer increments past the final FIFO address, the write pointer will increment the unused MSB while setting the rest of the bits back to zero. The same is done with the read pointer. 
// If the MSBs of the two pointers are different, it means that the write pointer has wrapped one more time than the read pointer (Full Condition). If the MSBs of the two pointers are the same, it means that both pointers have wrapped the same number of times (Empty Condition). 

//------------------------------------------------------------------------------
// RESETs
//------------------------------------------------------------------------------
// Both the writer and reader side should have the resets long enough for both the sides to see the reset at the same time before de-asserting the same. For example, if writer is working on a fast clock and the synchronous reset is de-asserted after a few WClks (less than reader's clock width), then we might have a situation that reader might not have seen the synchronous reset yet.
// In this situation, the writer is out of reset where as the reader has not yet seen the reset. This might cause incorrect behavior of FIFO.

`timescale 1ns/1ps
`include "rtl_sync_w_rst.sv"

module FifoAsync # (
   parameter DATA_WIDTH = 8,  // Width of data per location in the FIFO
   parameter DEPTH = 8        // Number of locations in the FIFO. Should be an exponent of 2
)
(
   input logic Wclk,
   input logic Wrstb,
   input logic Wen,
   input logic [DATA_WIDTH-1:0] WrData,

   input logic Rclk,
   input logic Rrstb,
   input logic Ren,
   output logic [DATA_WIDTH-1:0] RdData,

   output logic Full,
   output logic Empty
);

// n+1 bit points
parameter POINTER_WIDTH = $clog2(DEPTH) + 1;  // The system function $clog2 shall return the ceiling of the log base 2 of the argument (the log rounded up to an integer value). 

logic [POINTER_WIDTH-1:0] WrPtr;
logic [POINTER_WIDTH-1:0] WrPtr_Bin_RCLK;
logic [POINTER_WIDTH-1:0] WrPtr_Gray;
logic [POINTER_WIDTH-1:0] WrPtr_Gray_d1;
logic [POINTER_WIDTH-1:0] WrPtr_Gray_RCLK;
logic [POINTER_WIDTH-1:0] RdPtr;
logic [POINTER_WIDTH-1:0] RdPtr_Bin_WCLK;
logic [POINTER_WIDTH-1:0] RdPtr_Gray;
logic [POINTER_WIDTH-1:0] RdPtr_Gray_d1;
logic [POINTER_WIDTH-1:0] RdPtr_Gray_WCLK;
logic [POINTER_WIDTH-1:0] Depth_Wr; 
logic [POINTER_WIDTH-1:0] Depth_Rd; 
logic                     WenQ;
logic                     RenQ;
logic [DEPTH-1:0][DATA_WIDTH-1:0] ARRAY; // Packed Array


assign WenQ = Wen & ~Full;
assign RenQ = Ren & ~Empty;  // TODO: Do we need a feedback to write and read side if FIFO is full or empty respectively. Both side should be able to re-try.


///////////////////////////////////////////////////
// Writer's Interface
///////////////////////////////////////////////////

// Write Pointer Calculation
always_ff @(posedge Wclk) begin : WrPtr_calculation
   if (!Wrstb) begin
       WrPtr <= {POINTER_WIDTH{1'b0}};
   end
   else begin
       WrPtr <= (WenQ) ? WrPtr+1'b1 : WrPtr;
   end
end

// Binary to Gray Conversion : Writer
always_comb begin : WrPtr_Binary_to_Gray
   for(int i=POINTER_WIDTH-1; i>=0; i--) begin   
   	if (i == (POINTER_WIDTH-1)) begin
              WrPtr_Gray[i] = WrPtr[i];
           end
   	else begin
              WrPtr_Gray[i] = WrPtr[i] ^ WrPtr[i+1];
           end
   end
end

// Gray to Binary Conversion : Writer
always_comb begin : WrPtr_Gray_to_Binary
   for(int i=POINTER_WIDTH-1; i>=0; i--) begin   
   	if (i == (POINTER_WIDTH-1)) begin
              WrPtr_Bin_RCLK[i] = WrPtr_Gray_RCLK[i];
           end
   	else begin
              WrPtr_Bin_RCLK[i] = WrPtr_Bin_RCLK[i+1] ^ WrPtr_Gray_RCLK[i];
           end
   end
end

// Synchronization: Writer
SYNC #(.DATA_WIDTH(POINTER_WIDTH)) fifo_write_sync(
   .DataIn   (WrPtr_Gray),
   .Clk      (Rclk),
   .Rstb     (Rrstb),
   .DataOut  (WrPtr_Gray_RCLK) 
);

// Write to FIFO
// Array should not be reset. WrPtr should take care of the same.
always_ff @(posedge Wclk) begin: Write_to_FIFO
       //ARRAY[WrPtr[POINTER_WIDTH-2:0]] <=  (WenQ)?WrData:ARRAY[WrPtr[POINTER_WIDTH-2:0]]; // This line unnecessarily writes back the same value when WenQ == 0, which creates a mux on write port. Bad for synthesis — leads to unnecessary logic.// Replace with write-enable conditional:
       if (WenQ)
         ARRAY[WrPtr[POINTER_WIDTH-2:0]] <=  WrData;
         
end



///////////////////////////////////////////////////
// Reader's Interface
///////////////////////////////////////////////////

// Read Pointer Calculation
always_ff @(posedge Rclk) begin : RdPtr_calculation
   if (!Rrstb) begin
       RdPtr <= {POINTER_WIDTH{1'b0}};
   end
   else begin
       RdPtr <= (RenQ)?RdPtr+1'b1:RdPtr;
   end
end

// Binary to Gray Conversion : Reader
always_comb begin : RdPtr_Binary_to_Gray
   for(int i=POINTER_WIDTH-1; i>=0; i--) begin   
   	if (i == (POINTER_WIDTH-1)) begin
              RdPtr_Gray[i] = RdPtr[i];
           end
   	else begin
              RdPtr_Gray[i] = RdPtr[i] ^ RdPtr[i+1];
           end
   end
end


// Gray to Binary Conversion : Reader
always_comb begin : RdPtr_Gray_to_Binary
   for(int i=POINTER_WIDTH-1; i>=0; i--) begin   
   	if (i == (POINTER_WIDTH-1)) begin
              RdPtr_Bin_WCLK[i] = RdPtr_Gray_WCLK[i];
           end
   	else begin
              RdPtr_Bin_WCLK[i] = RdPtr_Bin_WCLK[i+1] ^ RdPtr_Gray_WCLK[i];
           end
   end
end

SYNC #(.DATA_WIDTH(POINTER_WIDTH)) fifo_read_sync(
   .DataIn   (RdPtr_Gray),
   .Clk      (Wclk),
   .Rstb     (Wrstb),   
   .DataOut  (RdPtr_Gray_WCLK) 
);

// Read from FIFO
// Read data output port should immediately read the data (no need of a flop for least latency).
// No need for reset here as RdPtr will be reset to 0 and ARRAY itself is reset. 
always_comb begin
    RdData = ARRAY[RdPtr[POINTER_WIDTH-2:0]]; // TODO: Do we need RenQ?
end

///////////////////////////////////////////////////
// Full and Empty Calculations
///////////////////////////////////////////////////
assign Depth_Wr = WrPtr - RdPtr_Bin_WCLK;
assign Depth_Rd = WrPtr_Bin_RCLK - RdPtr;

always_comb begin : Full_calculation
    Full = (Depth_Wr[POINTER_WIDTH-1] == 1'b1) && (Depth_Wr[POINTER_WIDTH-2:0] == {POINTER_WIDTH-1{1'b0}});
end
always_comb begin : Empty_calculation 
    Empty = (Depth_Rd[POINTER_WIDTH-1] == 1'b0) && (Depth_Rd[POINTER_WIDTH-2:0] == {POINTER_WIDTH-1{1'b0}});
end

// TODO: Need overflow and underflow assertions?
endmodule
