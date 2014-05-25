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
*	Contact Sohil Shah at sohils@cmu.edu for information or questions. 
**************************************************************************/

`include "constants.sv"

module register_file
	(input logic [7:0] 	reg_input,
	input logic 		load_en,
	input logic [2:0]	reg_selA,
	input logic [2:0]	reg_selB,
	input logic 		rst,
	input logic 		clk, 
	input logic			flags_in,
	input logic			load_flags,
	output logic [7:0]	reg_outA,
	output logic [7:0]	reg_outB,
	output logic [3:0]	flags);

	reg [7:0]	A, B, C, D, E, H, L;
	
	reg [3:0]	F;
	assign flags = F;
	
	always_ff @(posedge clk, posedge rst) begin
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
			if (load_flags)
				F <= flags_in;
			if (load_en) 
				case (reg_selA)
					3'b000:	A <= reg_input;
					3'b001: B <= reg_input;
					3'b010: C <= reg_input;
					3'b011: D <= reg_input;
					3'b100: E <= reg_input;
					3'b101: H <= reg_input;
					3'b110: L <= reg_input;
					default: /* Do Nothing */;
				endcase
			else
				/* Do Nothing */;
		end
	end

	always_comb begin
		case(reg_selA)
			3'b000: reg_outA = A;
			3'b001: reg_outA = B;
			3'b010: reg_outA = C;
			3'b011: reg_outA = D;
			3'b100:	reg_outA = E;
			3'b101: reg_outA = H;
			3'b110: reg_outA = L;
		endcase
		
		case(reg_selB)
			3'b000: reg_outB = A;
			3'b001: reg_outB = B;
			3'b010: reg_outB = C;
			3'b011: reg_outB = D;
			3'b100: reg_outB = E;
			3'b101: reg_outB = H;
			3'b110: reg_outB = L;
		endcase
	end
	
endmodule: register_file	