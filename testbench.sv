/**************************************************************************
 *	"testbench.sv"
 *	GameBoy SystemVerilog reverse engineering project.
 *   Copyright (C) 2014 Sohil Shah
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program.
 *	
 *	Contact Sohil Shah at sohils@cmu.edu with all questions. 
 **************************************************************************/

`include "top.sv"

/* 	Module Testbench: Testing environment for the design
 *
 *	Generates clock, reset, peripheral signals. Testing for any individual modules. 
 *
 */
module testbench();

   logic	cpu_clk, video_clk;
   logic	rst;
   
   logic 	joypad_up, joypad_down, joypad_right, joypad_left, joypad_a, joypad_b, joypad_start, joypad_select;
   logic 	HDMI_TX_DE;
   logic 	HDMI_TX_VS;
   logic 	HDMI_TX_HS;
   logic [23:0] HDMI_TX_D;
   logic 	HDMI_TX_CLK;

   logic [7:0] 	regA, regB, regC, regD, regE, regF, regH, regL;

   top DUT (.*);
   vars	v ();

   assign video_clk = cpu_clk;
   
   initial begin
      rst <= '1;
      cpu_clk <= '0;
      HDMI_TX_CLK <= '0;
      #10;
      rst <= '0;
   end

   initial
     //	4.50 MHz cpu clock
     forever #111 cpu_clk <= ~cpu_clk;

   initial
     //  27.027 MHz hdmi clock
     forever #18.5 HDMI_TX_CLK <= ~HDMI_TX_CLK;
   
   initial
     forever @(posedge cpu_clk) $cast(v.instruc, DUT.dp.IR);
   
   initial
     forever @(posedge cpu_clk) v.cycles <= v.cycles + 1'b1;
   
   int mcd;
   string filename;
   int 	  frame;
   int 	  done;
   initial begin
      frame = 0;
      done = `FALSE;

      if ($test$plusargs("render")) begin
	 forever @(posedge HDMI_TX_CLK) begin
	    if (done == `TRUE && HDMI_TX_VS) begin
	       done = `FALSE;
	       $sformat(filename, "%0d", frame);
	       mcd = $fopen({"render/frame_", filename, ".bmp"}, "wb");
	       // BMP Header
	       $fwrite(mcd, "%u%u%u%u%u%u%u%u%u%u%u%u%u%c%c", 32'hc6c94D42, 32'h0000000F, 32'h00360000, 32'h00280000, 32'h02D00000, 32'hFE200000, 32'h0001FFFF, 
		       32'h00000018, 32'hC90C0000, 32'h0B130090, 32'h0B130000, 32'h00000000, 32'h00000000, 8'h00, 8'h00);
	       frame++;
	    end else if (HDMI_TX_DE) begin
	       $fwrite(mcd, "%c%c%c", HDMI_TX_D[7:0], HDMI_TX_D[15:8], HDMI_TX_D[23:16]);
	    end else if (~HDMI_TX_VS) begin
	       $fclose(mcd);
	       done = `TRUE;
	    end
	 end
      end
      
   end
   
   initial begin
      joypad_up = 1'b1;
      joypad_down = 1'b1;
      joypad_left = 1'b1;
      joypad_right = 1'b1;
      joypad_start = 1'b1;
      joypad_select = 1'b1;
      joypad_a = 1'b1;
      joypad_b = 1'b1;
      
      if ($test$plusargs("debug"))
	$monitor("State: %s			Iter: %d	| 	PC: %h 	IR: %s		(0x%h)	SP: %h	|Reset: %b \n	Registers {A B C D E H L} : {%h %h %h %h %h %h %h}   MAR: %h		MDR: %h	\n	Clock cycle (dec): %d    Condition codes {Z N H C} : {%b %b %b %b}\n\n", 
		 DUT.dp.cp.curr_state.name, DUT.dp.cp.iteration, DUT.dp.PC, v.instruc.name, DUT.dp.IR, DUT.dp.SP, rst,
		 DUT.dp.regA, DUT.dp.regB, DUT.dp.regC, DUT.dp.regD, DUT.dp.regE, DUT.dp.regH, DUT.dp.regL, DUT.dp.MAR, DUT.dp.MDR, v.cycles,
		 DUT.dp.regF[3], DUT.dp.regF[2], DUT.dp.regF[1], DUT.dp.regF[0]);
      
      repeat(20)
	#700000000;
      
      joypad_start <= 1'b0;
      #100000000;
      joypad_start <= 1'b1;
      #1000000000;
      joypad_start <= 1'b0;
      #100000000;
      joypad_start <= 1'b1;
      #1000000000;
      joypad_start <= 1'b0;
      #100000000;
      joypad_start <= 1'b1;
      #1000000000;
      joypad_start <= 1'b1;
      #100000000;
      joypad_start <= 1'b0;
      #1000000000;
      joypad_down <= 1'b0;
      #1000000000;
      #1000000000;
      joypad_down <= 1'b1;
      #100000000;
      joypad_down <= 1'b0;
      #1000000000;
      #1000000000;
      joypad_down <= 1'b1;
      #100000000;
      joypad_down <= 1'b0;
      #1000000000;
      #1000000000;
      joypad_down <= 1'b1;
      #100000000;
      joypad_down <= 1'b0;
      #1000000000;
      #1000000000;
      joypad_down <= 1'b1;
      #100000000;
      joypad_down <= 1'b0;
      #2000000000;
      $stop;
      
   end
   
endmodule: testbench

// To be accessible from anywhere in design for debugging
module vars();
   std_instruction_t	instruc;
   int cycles;
   reg [15:0] cksm;
endmodule: vars