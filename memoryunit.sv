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
	(
	// CPU MEMORY OPERATIONS
	inout 		[7:0]		databus,
	input logic [15:0]		address,
	input logic 			OE,
	input logic 			WE,
	
	// CONTROL REGISTERS
	input control_reg_t		regin, 
	output control_reg_t	regout,
	
	// DISPLAY MEMORY
	input logic [12:0] disp_address,
	input logic oe_oam,
	input logic oe_vram,
	output logic [7:0] disp_data,
	
	input logic 			clk,
	input logic				rst);
	
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
			
		// 0xFF00 <= address < 0xFF4C  [CONTROL_REGS]
		else if ((address >= 16'hFF00 && address < 16'hFF4C) || address == 16'hFFFF)
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
	SRAM_BANK #(.start (16'h0000), .size (16'h4000), .init ("bootstrap.hex")) romb0(.databus (databus), .address (address[13:0]), .CS (CS_rom0), .OE (OE), .WE (WE), .clk (clk));
	SRAM_BANK #(.start (16'h4000), .size (16'h4000), .init ("ROM1.hex")) romb1(.databus (databus), .address (address[13:0]), .CS (CS_rom1), .OE (OE), .WE (WE), .clk (clk));
	
	// VRAM
	SRAM_BANK #(.start (16'h8000), .size (16'h2000), .init ("")) vram(.databus (databus), .address ((13{~oe_vram} & address[12:0]) | (13{oe_vram} & disp_address)),
				.CS (CS_vram | oe_vram), .data_out (disp_data), .OE (OE | oe_vram), .WE (WE & ~oe_vram), .clk (clk));

	// INTERNAL RAM
	SRAM_BANK #(.start (16'hA000), .size (16'h2000), .init ("")) ramb0(.databus (databus), .address (address[12:0]), .CS (CS_ram0), .OE (OE), .WE (WE), .clk (clk));
	SRAM_BANK #(.start (16'hC000), .size (16'h2000), .init ("")) ramb1(.databus (databus), .address (address[12:0]), .CS (CS_ram1), .OE (OE), .WE (WE), .clk (clk));
	
	// OAM
	SRAM_BANK #(.start (16'hFE00), .size (16'h0100), .init ("")) oam(.databus (databus), .address ((13{~oe_oam} & address[7:0]) | (13{oe_oam} & disp_address[7:0])),
				.CS (CS_oam | oe_oam), .data_out (disp_data), .OE (OE | oe_oam), .WE (WE & ~oe_oam), .clk (clk));
	
	// HIGH RAM
	SRAM_BANK #(.start (16'hFF80), .size (16'h0080), .init ("")) ramh(.databus (databus), .address (address[6:0]), .CS (CS_ramh), .OE (OE), .WE (WE), .clk (clk));

	
	/*** CONTROL REGISTER BANK ***/
	
	IO_CONTROL_REGS #(.start (16'hFF00), .size (16'h0100)) io(.databus (databus), .address (address[7:0]), .regout (regout), .regin (regin),
		.CS (CS_io), .OE (OE), .WE (WE), .clk (clk), .rst (rst));
	

endmodule: memoryunit

module SRAM_BANK
	#(parameter start  = 16'h0000,
	  parameter size   = 16'h4000,
	  parameter init   = "")
	
	(inout tri	[7:0]				databus,
	output logic [7:0]				data_out,
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
	assign data_out = (OE && CS && ~WE) ? mem[address] : 8'b0;
	
	initial
		if (init != "")
			$readmemh(init, mem);
			
endmodule: SRAM_BANK

module IO_CONTROL_REGS
	#(parameter start  = 16'hFF00,
	  parameter size   = 16'h0100)

	(inout tri [7:0]				databus,
	input logic [$clog2(size)-1:0]	address,
	input control_reg_t				regin,
	output control_reg_t			regout,
	input logic						CS,
	input logic						OE,
	input logic						WE,
	input logic						clk,
	input logic						rst);

	control_reg_t	control_regs;
	logic [7:0]		data;
	
	// Output register window
	assign regout = control_regs;
	
	// Address decoder for writes
	always_ff @(posedge clk, posedge rst) begin
		if (rst)
			control_regs <= '0;
			
		else if (WE && CS) begin
			// Update registers not being written
			control_regs <= regin;

			// Next value by default is regin, set from peripheral components outside CPU
			// For CPU controlled regs, set by address MUX:
			case (address)
			
				8'h00: 
					control_regs.joypad <= {2'b0, databus[5:4], regin[3:0]};
				8'h01: 
					control_regs.serial_data <= databus;
				8'h02: 
					control_regs.serial_control <= databus;
				8'h04: 
					control_regs.timer_divide <= 8'b0;
				8'h05: 
					control_regs.timer_count <= 8'b0;
				8'h06: 
					control_regs.timer_modulo <= databus;
				8'h07: 
					control_regs.timer_control <= {5'b0, databus[2:0]};
				8'h0F: 
					control_regs.interrupt_st <= regin;
				8'h40: 
					control_regs.lcd_control <= databus;
				8'h41: 
					control_regs.lcd_status <= {1'b0, databus[6:3], regin[2:0]};
				8'h42: 
					control_regs.scroll_y <= databus;
				8'h43: 
					control_regs.scroll_x <= databus;
				8'h44: 
					control_regs.lcd_v <= regin;
				8'h45: 
					control_regs.lcd_v_cp <= databus;
				8'h46: 
					control_regs.dma <= databus;
				8'h47: 
					control_regs.bg_pal <= databus;
				8'h48: 
					control_regs.obj_pal0 <= databus;
				8'h49: 
					control_regs.obj_pal1 <= databus;
				8'h4A: 
					control_regs.win_y <= databus;
				8'h4B: 
					control_regs.win_x <= databus;
				8'hFF: 
					control_regs.interrupt_en <= databus;
				
				default: begin
					control_regs <= regin;
				end
			endcase
			
		end else begin
			// If not writing, use regin values.
			control_regs <= regin;
		end	
	end

	// Address decoder for reads
	always_comb begin
		if (CS) begin
			case (address)
				8'h00: 
					data = control_regs.joypad;
				8'h01: 
					data = control_regs.serial_data;
				8'h02: 
					data = control_regs.serial_control;				
				8'h04: 
					data = control_regs.timer_divide;				
				8'h05: 
					data = control_regs.timer_count;				
				8'h06: 
					data = control_regs.timer_modulo;				
				8'h07: 
					data = control_regs.timer_control;
				8'h0F: 
					data = control_regs.interrupt_st;		
				8'h40: 
					data = control_regs.lcd_control;				
				8'h41: 
					data = control_regs.lcd_status;
				8'h42: 
					data = control_regs.scroll_y;				
				8'h43: 
					data = control_regs.scroll_x;	
				8'h44: 
					data = control_regs.lcd_v;
				8'h45: 
					data = control_regs.lcd_v_cp;				
				8'h46: 
					data = 8'b0;			
				8'h47: 
					data = control_regs.bg_pal;	
				8'h48: 
					data = control_regs.obj_pal0;
				8'h49: 
					data = control_regs.obj_pal1;			
				8'h4A: 
					data = control_regs.win_y;			
				8'h4B: 
					data = control_regs.win_x;				
				8'hFF: 
					data = control_regs.interrupt_en;
				
				default: begin
					data = 8'bx;
				end
			endcase
		end else begin
			data = 8'bx;
		end
	end
	
	assign databus = (~WE && OE && CS) ? data : 8'bz;
	
endmodule: IO_CONTROL_REGS