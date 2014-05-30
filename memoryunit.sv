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

`include "constants.sv"

/* 	Module sram: simulation model of memory
*
*	WIP
*
*/
module sram
	(inout	 	[7:0]	databus,
	input logic [15:0]	address,
	input logic			RE,
	input logic			WE,
	input logic			clk);
	
	reg [7:0]			mem [16'hFFFF : 16'h0000];
	
	always_ff @(posedge clk)
		if (WE & ~RE)
			mem[address] <= databus;
	
	assign databus = (RE) ? mem[address] : 8'bz;
	
	initial $readmemh("memory.hex", mem);
	
endmodule: sram