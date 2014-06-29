/**************************************************************************
*	"top.sv"
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
`include "datapath.sv"
`include "memoryunit.sv"
`include "video_driver.sv"

/* 	Module top: Top level design entity
*
*	Holds connections to all sub-modules
*
*/
module top
	(input logic clk,
	input logic rst);
	
	logic [7:0] regA, regB, regC, regD, regE, regF, regH, regL;
	logic [15:0] mema;
	tri [7:0] memd;
	logic RE, WE;
	
	control_reg_t regin, regout;
	
	datapath	dp(.clk (clk), .rst (rst), .databus (memd), .MAR (mema), .RE (RE), .WE (WE), .regA (regA), .regB (regB), 
					.regC (regC), .regD (regD), .regE (regE), .regF (regF), .regH (regH), .regL (regL));
	
	memoryunit	mu(.clk (clk), .address (mema), .databus (memd), .OE (RE), .WE (WE), .regin (regin), .regout (regout));
	
	display		lcdc();
	
endmodule: top