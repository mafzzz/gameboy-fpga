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
module MemoryTester
	(input logic [3:0]	KEY,
	input logic [9:0]	SW,
	input logic			CLOCK_50_B5B,
	output logic [6:0]	HEX0, HEX1, HEX2, HEX3);
	
	logic clk, rst;
	
	assign clk = (SW[9]) ? ~KEY[1] : CLOCK_50_B5B;
	assign rst = ~KEY[0];
	
	reg [7:0]			regA, regB;
	sseg A_outh(regA[7:4], HEX3);
	sseg A_outl(regA[3:0], HEX2);
	sseg B_outh(regB[7:4], HEX1);
	sseg B_outl(regB[3:0], HEX0);

	tri [7:0] data;

	always_ff @(posedge clk) begin
		regA <= SW[7:0];
		regB <= (~KEY[2]) ? data : regB;
	end
	
	assign data = (~KEY[3] && KEY[2]) ? SW[8] : 8'bz;
	
	sram ram (.clk (clk), .databus (data), .address ({8'h00, regA}), .RE (~KEY[2]), .WE (~KEY[3]));
	
endmodule: MemoryTester