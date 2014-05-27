/**************************************************************************
*	"chipinterface.sv"
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

/* Module ChipInterface: Connects Cyclone V board ports to datapath
*
*	WIP
*
*/
module ChipInterface
	(input logic [1:0]	KEY,
	input logic [0:0]	SW,
	input logic			CLOCK_50_B5B,
	output logic [6:0]	HEX0, HEX1, HEX2, HEX3);
	
	logic clk, rst;
	
	assign clk = (SW[0]) ? ~KEY[1] : CLOCK_50_B5B;
	assign rst = ~KEY[0];
	
	logic [7:0]			regA, regB;
	sseg A_outh(regA[7:4], HEX3);
	sseg A_outl(regA[3:0], HEX2);
	sseg B_outh(regB[7:4], HEX1);
	sseg B_outl(regB[3:0], HEX0);
	
	datapath dp(.*);
	
endmodule: ChipInterface

module sseg 
	(input logic [3:0]	num,
	output logic [6:0]	out);
	
	logic [6:0] disp;
	assign out = ~disp;
	
	always_comb begin
	
		case(num)
			4'h0: disp = 7'b011_1111;
			4'h1: disp = 7'b000_0110;
			4'h2: disp = 7'b101_1011;
			4'h3: disp = 7'b100_1111;
			4'h4: disp = 7'b110_0110;
			4'h5: disp = 7'b110_1101;
			4'h6: disp = 7'b111_1101;
			4'h7: disp = 7'b000_0111;
			4'h8: disp = 7'b111_1111;
			4'h9: disp = 7'b110_0111;
			4'hA: disp = 7'b111_0111;
			4'hB: disp = 7'b111_1100;
			4'hC: disp = 7'b011_1001;
			4'hD: disp = 7'b101_1110;
			4'hE: disp = 7'b111_1001;
			4'hF: disp = 7'b111_0001;
			default:	disp = 7'b100_0000;
		endcase
	
	end
	
endmodule: sseg