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
	
	logic			vblank_int, lcdc_int, timer_int, serial_int, joypad_int, int_clear;
	
	control_reg_t regin, regout;
	
	datapath	dp(.clk (clk), .rst (rst), .databus (memd), .MAR (mema), .RE (RE), .WE (WE), .regA (regA), .regB (regB), 
					.vblank_int (regout.interrupt_st[0]), .lcdc_int (regout.interrupt_st[1]), .timer_int (regout.interrupt_st[2]), 
					.serial_int (regout.interrupt_st[3]), .joypad_int (regout.interrupt_st[4]), .int_en (regout.interrupt_en), 
					.int_clear (int_clear), .regC (regC), .regD (regD), .regE (regE), .regF (regF), .regH (regH), .regL (regL));
	
	memoryunit	mu(.clk (clk), .rst(rst), .address (mema), .databus (memd), .OE (RE), .WE (WE), .regin (regin), .regout (regout));
	
	display		lcdc();
	
	// Timer clock divide
	logic div_16, div_64, div_256, div_1024;
	logic [9:0] counter;
	
	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			div_16 <= 1'b0;
			div_64 <= 1'b0;
			div_256 <= 1'b0;
			div_1024 <= 1'b0;
			counter <= 10'b1;
		end else begin
			div_16 <= counter[3:0] == 4'b0;
			div_64 <= counter[5:0] == 6'b0;
			div_256 <= counter[7:0] == 8'b0;
			div_1024 <= counter[9:0] == 10'b0;
			counter <= counter + 1;
		end
	end
	
	// Interrupts
	assign timer_int = (int_clear) ? 1'b0 : (regin.timer_count == 8'b0 && regout.timer_count == 8'hFF) | regout.interrupt_st[2];
	
	// Control register next state
	always_comb begin
		
		regin.joypad = regout.joypad;
		
		regin.serial_data = regout.serial_data;
		regin.serial_control = regout.serial_control;
		
		regin.timer_divide = (div_256) ? regout.timer_divide + 1 : regout.timer_divide;
		case (regout.timer_control[1:0])
			2'b00: regin.timer_count = (div_1024) ? regout.timer_count + 1 : regout.timer_count;
			2'b01: regin.timer_count = (div_16) ? regout.timer_count + 1 : regout.timer_count;
			2'b10: regin.timer_count = (div_64) ? regout.timer_count + 1 : regout.timer_count;
			2'b11: regin.timer_count = (div_256) ? regout.timer_count + 1 : regout.timer_count;
		endcase
		regin.timer_control = regout.timer_control;
		regin.timer_modulo = regout.timer_modulo;
		
		regin.interrupt_st = {3'b0, joypad_int, serial_int, timer_int, lcdc_int, vblank_int};
		
		regin.lcd_control = regout.lcd_control;
		regin.lcd_status = regout.lcd_status;
		
		regin.scroll_y = regout.scroll_y;
		regin.scroll_x = regout.scroll_x;
		regin.lcd_v = regout.lcd_v;
		regin.lcd_v_cp = regout.lcd_v_cp;
		
		regin.bg_pal = regout.bg_pal;
		regin.obj_pal0 = regout.obj_pal0;
		regin.obj_pal1 = regout.obj_pal1;
		regin.win_y = regout.win_y;
		regin.win_x = regout.win_x;
		
		regin.dma = 8'b0;
		regin.interrupt_en = regout.interrupt_en;
	end
	
endmodule: top