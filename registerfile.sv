/**************************************************************************
 *	"registerfile.sv"
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

`include "constants.sv"

/* 	Module RegisterFile: Contains registers of processor
 *
 *  	Registers:
 *	A, B, C, D, E, H, L --> GPRs
 *	F --> Flags
 *	A --> Accumulator
 */
module register_file
  (input logic [7:0] 	reg_input,
   input logic [15:0]	addr_input,
   input logic [1:0]	load_en,
   input reg_sel_t     	reg_selA,
   input reg_sel_t     	reg_selB,
   input logic 		rst,
   input logic 		clk, 
   input logic	[3:0]	flags_in,
   output logic [63:0]	window,
   output logic [7:0]	reg_outA,
   output logic [7:0]	reg_outB,
   output logic [3:0]	flags);

   reg [7:0] 		A, B, C, D, E, H, L;
   
   reg [3:0] 		F;
   assign flags = F;
   
   assign window = {L, H, {4'b0, F}, E, D, C, B, A};
   
   always_ff @(posedge clk, posedge rst) begin
      // Reset all registers to 0
      if (rst) begin
	 A <= 8'b0;
	 B <= 8'b0;
	 C <= 8'b0;
	 D <= 8'b0;
	 E <= 8'b0;
	 F <= 8'b0;
	 H <= 8'b0;
	 L <= 8'b0;
      end
      
      else begin

	 F <= flags_in;

	 if (load_en[0]) 
	   case (reg_selA)
	     reg_A: A <= reg_input;
	     reg_B: B <= reg_input;
	     reg_C: C <= reg_input;
	     reg_D: D <= reg_input;
	     reg_E: E <= reg_input;
	     reg_H: H <= reg_input;
	     reg_L: L <= reg_input;
	     default: /* Do Nothing */;
	   endcase
	 else if (load_en[1])
	   case (reg_selA)
	     reg_B: {B, C} <= addr_input;
	     reg_D: {D, E} <= addr_input;
	     reg_H: {H, L} <= addr_input;
	     default: /* Do Nothing */;
	   endcase
	 /* Do Nothing */;
      end
   end

   // Output reg A, B output based on A, B select lines
   always_comb begin
      case(reg_selA)
	reg_A: reg_outA = A;
	reg_B: reg_outA = B;
	reg_C: reg_outA = C;
	reg_D: reg_outA = D;
	reg_E: reg_outA = E;
	reg_H: reg_outA = H;
	reg_L: reg_outA = L;
	default:	reg_outA = 'x;
      endcase
      
      case(reg_selB)
	reg_A: reg_outB = A;
	reg_B: reg_outB = B;
	reg_C: reg_outB = C;
	reg_D: reg_outB = D;
	reg_E: reg_outB = E;
	reg_H: reg_outB = H;
	reg_L: reg_outB = L;
	default:	reg_outB = 'x;
      endcase
   end
   
endmodule: register_file