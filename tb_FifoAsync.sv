`timescale 1ns/1ps

module tb_FifoAsync #(
	parameter DEPTH      = 8,
    parameter DATA_WIDTH = 32,
	parameter RMULT = 5.5,
	parameter WMULT = 5.1,
    parameter BURST_SIZE = 200
       )();

parameter CLK_PERIOD = 0.5;

integer cnt;
integer i;

logic Wclk;
logic Wen;
logic [DATA_WIDTH-1:0] WrData;

logic Rclk;
logic Ren;
logic [DATA_WIDTH-1:0] RdData;

logic rstb;
logic Full;
logic Empty;

logic Wrstb_S;
logic Wrstb_SS;
logic Rrstb_S;
logic Rrstb_SS;

logic [BURST_SIZE-1:0][DATA_WIDTH-1:0] WrData_chk;
logic [BURST_SIZE-1:0] error_cnt;
logic [DATA_WIDTH-1:0] MaxValue = 2**DATA_WIDTH-1;

FifoAsync #(
  .DEPTH(DEPTH),
  .DATA_WIDTH(DATA_WIDTH)  
) FifoAsync_Inst (
    .Wclk,
    .Wen,
    .WrData,
    .Rclk,
    .Ren,
    .RdData,
    .Wrstb(Wrstb_SS),
    .Rrstb(Rrstb_SS),
    .Full,
    .Empty
);

///////////////////////////////////////////////////
// Clock Generation
///////////////////////////////////////////////////
initial begin
        Wclk = 1'b0;
        forever begin
      	  #(CLK_PERIOD*WMULT) Wclk = ~Wclk;
        end
end

initial begin
        Rclk = 1'b0;
        forever begin
      	  #(CLK_PERIOD*RMULT) Rclk = ~Rclk;
        end
end

///////////////////////////////////////////////////
// Reset Synchronization 
///////////////////////////////////////////////////
// TODO: abhiverm: Need to test async resets.
always_ff @(posedge Wclk or negedge rstb) begin
   if (!rstb) begin
      Wrstb_S  <= 1'b0;
      Wrstb_SS <= 1'b0;
   end
   else begin
      Wrstb_S  <= 1'b1;
      Wrstb_SS <= Wrstb_S;
   end
end

always_ff @(posedge Rclk or negedge rstb) begin
   if (!rstb) begin
      Rrstb_S  <= 1'b0;
      Rrstb_SS <= 1'b0;
   end
   else begin
      Rrstb_S  <= 1'b1;
      Rrstb_SS <= Rrstb_S;
   end
end

///////////////////////////////////////////////////
// Test Initialization 
///////////////////////////////////////////////////
initial begin
   rstb = 1'b0;
   Wen = 1'b0;
   Ren = 1'b0;

   #(1000*CLK_PERIOD);
   rstb = 1'b1;
   //#(1000*CLK_PERIOD);

   cnt = 0;
   $display ("%t : Test Start : Burst Size = %d", $time, BURST_SIZE); 

   // Writer's interface
   @(posedge Wrstb_SS); // Wait for writer's reset to de-assert before sending transactions. 
   repeat(BURST_SIZE) begin
     if (Full == 1) begin
       $display ("%t : WAIT: FIFO is FULL!", $time);
     end  
       wait (Full == 0);
       @(posedge Wclk); // New data is sent on negative edge of Wclk to make sure setup time is met.
       WrData = $urandom_range(MaxValue,0);
       WrData_chk[cnt] = WrData;
       Wen = 1'b1;
       Ren = 1'b1;
       cnt++;
       #(WMULT);
   end

   Wen = 1'b0;

   @(posedge Empty) ;
   Ren = 1'b0;

   if (error_cnt > 0) 
       $display ("%t : FAIL: FIFO Checker Failed!", $time);
   else
       $display ("%t : PASS: FIFO Checker Passed!", $time);

   #(1000*CLK_PERIOD);
   $finish;
end
  


///////////////////////////////////////////////////
// FIFO Checker 
///////////////////////////////////////////////////
always_ff @(posedge Rclk or negedge Rrstb_SS) begin
   if (!Rrstb_SS) begin
      i <= 0;
      error_cnt <= 0;
   end
   if (Ren && ~Empty && (i <= BURST_SIZE+1)) begin
      if ((RdData != WrData_chk[i-1]) && (i != 0)) begin
           $display ("%t : FAIL: WrData[%d] = %h did not match RdData[%d] = %h",$time, i-1, WrData_chk[i-1], i-1, RdData);
           error_cnt <= error_cnt + 1;
      end
      else if (i !=0) 
        $display ("%t : PASS: WrData[%d] = %h match RdData[%d] = %h",$time, i-1, WrData_chk[i-1], i-1, RdData);
      i <= i + 1;
   end
end

///////////////////////////////////////////////////
// Waveform
///////////////////////////////////////////////////
initial begin
  $dumpfile("dump.vcd");
  $dumpvars();
end

endmodule
