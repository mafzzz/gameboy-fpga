/**************************************************************************
*	"memoryunit.sv"
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
`define synthesis

module memoryunit 
	(inout 		[7:0]	databus,
	input logic [15:0]	address,
	input logic 		OE,
	input logic 		WE,
	input logic 		clk);
	
	logic CS_rom0, CS_rom1, CS_vram, CS_ram0, CS_ram1, CS_oam, CS_io, CS_ramh;
	logic [7:0] CS_decoder;
	assign {CS_ramh, CS_io, CS_oam, CS_ram1, CS_ram0, CS_vram, CS_rom1, CS_rom0} = CS_decoder;
	
	// Chip select decoder
	always_comb begin
		// 0x0000 <= address < 0x4000  [ROM_BANK_0]
		if (address < 16'h4000)
			CS_decoder = 8'b0000_0001;
			
		// 0x4000 <= address < 0x8000  [ROM_BANK_1]
		else if (address < 16'h8000)
			CS_decoder = 8'b0000_0010;
			
		// 0x8000 <= address < 0xA000  [VRAM]
		else if (address < 16'hA000)
			CS_decoder = 8'b0000_0100;
			
		// 0xA000 <= address < 0xC000  [RAM_BANK_0]
		else if (address < 16'hC000)
			CS_decoder = 8'b0000_1000;
			
		// 0xC000 <= address < 0xE000  [RAM_BANK_1]
		else if (address < 16'hE000)
			CS_decoder = 8'b0001_0000;
			
		// 0xFE00 <= address < 0xFEA0  [OAM]
		else if (address >= 16'hFE00 && address < 16'hFEA0)
			CS_decoder = 8'b0010_0000;
			
		// 0xFF4C <= address < 0xFF80  [CONTROL_REGS]
		else if ((address >= 16'hFF4C && address < 16'hFF80) || address == 16'hFFFF)
			CS_decoder = 8'b0100_0000;
			
		// 0xFF80 <= address < 0xFFFF  [HIGH_RAM]
		else if (address >= 16'hFF80 && address < 16'hFFFF)
			CS_decoder = 8'b1000_0000;
		
		// UNUSABLE MEMORY LOCATIONS
		else
			CS_decoder = 8'b0000_0000;
	end
	
	/*** MEMORY BANKS ***/
	
	// ROM
	SRAM_BANK #(.start (16'h0000), .size (16'h4000), .init ("ROM0.hex")) romb0(.databus (databus), .address (address[13:0]), .CS (CS_rom0), .OE (OE), .WE (WE), .clk (clk));
	SRAM_BANK #(.start (16'h4000), .size (16'h4000), .init ("ROM1.hex")) romb1(.databus (databus), .address (address[13:0]), .CS (CS_rom1), .OE (OE), .WE (WE), .clk (clk));
	
	// VRAM
	SRAM_BANK #(.start (16'h8000), .size (16'h2000), .init ("")) vram(.databus (databus), .address (address[12:0]), .CS (CS_vram), .OE (OE), .WE (WE), .clk (clk));
	
	// INTERNAL RAM
	SRAM_BANK #(.start (16'hA000), .size (16'h2000), .init ("")) ramb0(.databus (databus), .address (address[12:0]), .CS (CS_ram0), .OE (OE), .WE (WE), .clk (clk));
	SRAM_BANK #(.start (16'hC000), .size (16'h2000), .init ("")) ramb1(.databus (databus), .address (address[12:0]), .CS (CS_ram1), .OE (OE), .WE (WE), .clk (clk));
	
	// OAM
	SRAM_BANK #(.start (16'hFE00), .size (16'h0100), .init ("")) oam(.databus (databus), .address (address[7:0]), .CS (CS_oam), .OE (OE), .WE (WE), .clk (clk));
	
	// HIGH RAM
	SRAM_BANK #(.start (16'hFF80), .size (16'h0080), .init ("")) ramh(.databus (databus), .address (address[6:0]), .CS (CS_ramh), .OE (OE), .WE (WE), .clk (clk));

	
	/*** CONTROL REGISTER BANK ***/
	IO_CONTROL_REGS #(.start (16'hFF00), .size (16'h0100), .init ("")) io(.databus (databus), .address (address[7:0]), .CS (CS_io), .OE (OE), .WE (WE), .clk (clk));
	
endmodule: memoryunit

module SRAM_BANK
	#(parameter start  = 16'h0000,
	  parameter size   = 16'h4000,
	  parameter init   = "")
	
	(inout  	[7:0]				databus,
	input logic [$clog2(size)-1:0]	address,
	input logic						CS,
	input logic						OE,
	input logic						WE,
	input logic						clk);
	
	reg [7:0]			mem [16'h0000 : size - 1];
	
	always @(posedge clk)
		if (WE && CS)
			mem[address] <= databus;
	
	assign databus = (OE && CS && ~WE) ? mem[address] : 8'bz;
	
	initial
		if (init != "")
			$readmemh(init, mem);
			
endmodule: SRAM_BANK

module IO_CONTROL_REGS
	#(parameter start  = 16'h0000,
	  parameter size   = 16'h4000,
	  parameter init   = "")

	(inout  	[7:0]				databus,
	input logic [$clog2(size)-1:0]	address,
	input logic						CS,
	input logic						OE,
	input logic						WE,
	input logic						clk);

	reg [7:0]			mem [16'h0000 : size - 1];
	
	always @(posedge clk)
		if (WE && CS)
			mem[address] <= databus;
	
	assign databus = (OE && CS && ~WE) ? mem[address] : 8'bz;
	
	initial
		if (init != "")
			$readmemh(init, mem);
	
endmodule: IO_CONTROL_REGS