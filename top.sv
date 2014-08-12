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
	(input logic cpu_clk,
	input logic rst,
	
	// Joypad signals (asserted low)
	input logic joypad_up,
	input logic joypad_down,
	input logic joypad_left,
	input logic joypad_right,
	input logic joypad_a,
	input logic joypad_b,
	input logic joypad_start,
	input logic joypad_select,
	
	// HDMI signals
	output logic [23:0] HDMI_TX_D,
	input logic 		HDMI_TX_CLK,
	output logic 		HDMI_TX_DE,
	output logic 		HDMI_TX_HS,
	output logic 		HDMI_TX_VS,
	
	// Debug registers
	output logic [7:0]		regA,
	output logic [7:0]		regB,
	output logic [7:0]		regC,
	output logic [7:0]		regD,
	output logic [7:0]		regE,
	output logic [7:0]		regF,
	output logic [7:0]		regH,
	output logic [7:0]		regL
	);
	
	logic clk;
	assign clk = cpu_clk;
	
	logic [15:0] mema;
	tri [7:0] memd;
	logic RE, WE;
	
	logic [7:0] 	disp_address_oam;
	logic [12:0] 	disp_address_vram;
	logic 			oe_oam, oe_vram;
	logic [7:0] 	disp_data_oam;
	logic [7:0] 	disp_data_vram;
	logic 			ld_disp_address_vram;
	logic 			ld_disp_address_oam;
	
	logic			vblank_int, lcdc_int, timer_int, serial_int, joypad_int, int_clear;
	
	logic [7:0] 	lcd_v;
	logic [1:0]		mode;
			
	// To detect joypad edges
	reg				prev_up, prev_down, prev_left, prev_right, prev_a, prev_b, prev_start, prev_select;
	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			prev_up <= 1'b1;
			prev_down <= 1'b1;
			prev_left <= 1'b1;
			prev_right <= 1'b1;
			prev_a <= 1'b1;
			prev_b <= 1'b1;
			prev_start <= 1'b1;
			prev_select <= 1'b1;
		end else begin
			prev_up <= joypad_up;
			prev_down <= joypad_down;
			prev_left <= joypad_left;
			prev_right <= joypad_right;
			prev_a <= joypad_a;
			prev_b <= joypad_b;
			prev_start <= joypad_start;
			prev_select <= joypad_select;
		end
	end
	
	control_reg_t regin, regout;

	datapath	dp (.clk (clk), .rst (rst), .databus (memd), .address (mema), .RE (RE), .WE (WE), .regA (regA), .regB (regB), 
					.vblank_int (regout.interrupt_st[0]), .lcdc_int (regout.interrupt_st[1]), .timer_int (regout.interrupt_st[2]), 
					.serial_int (regout.interrupt_st[3]), .joypad_int (regout.interrupt_st[4]), .int_en (regout.interrupt_en), .int_clear (int_clear), 
					.regC (regC), .regD (regD), .regE (regE), .regF (regF), .regH (regH), .regL (regL));
	
	memoryunit	mu (.clk (clk), .rst(rst), .cpu_address (mema), .data (memd), .OE (RE), .WE (WE), .regin (regin), .regout (regout), 
					.disp_address_oam (disp_address_oam), .disp_address_vram (disp_address_vram), .oe_oam (oe_oam), .oe_vram (oe_vram), 
					.disp_data_oam (disp_data_oam), .disp_data_vram (disp_data_vram), .ld_disp_address_oam (ld_disp_address_oam), 
					.ld_disp_address_vram (ld_disp_address_vram));
	
	display		lcdc 	(.clk_hdmi (HDMI_TX_CLK), .clk_cpu (clk), .rst (rst), .rd_address_oam (disp_address_oam), .rd_address_vram (disp_address_vram),
						.oe_oam (oe_oam), .oe_vram (oe_vram), .read_data_oam (disp_data_oam), .read_data_vram (disp_data_vram), .HDMI_VSYNC (HDMI_TX_VS), 
						.HDMI_HSYNC (HDMI_TX_HS), .HDMI_DE (HDMI_TX_DE), .HDMI_DO (HDMI_TX_D), .control (regout), .lcd_v (lcd_v), .mode (mode), 
						.ld_address_vram (ld_disp_address_vram), .ld_address_oam (ld_disp_address_oam));
	
	hdmi		hdmi_driver (.clk (HDMI_TX_CLK), .rst (rst), .hsync (HDMI_TX_HS), .vsync (HDMI_TX_VS), .de (HDMI_TX_DE));
	
	// Timer clock divide
	logic div_16, div_64, div_256, div_1024;
	logic [9:0] counter;
	
	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			div_16 <= 1'b0;
			div_64 <= 1'b0;
			div_256 <= 1'b0;
			div_1024 <= 1'b0;
			counter <= 10'b0;
		end else begin
			div_16 <= counter[3:0] == 4'b0;
			div_64 <= counter[5:0] == 6'b0;
			div_256 <= counter[7:0] == 8'b0;
			div_1024 <= counter[9:0] == 10'b0;
			counter <= counter + 1;
		end
	end

	// Interrupts
	assign timer_int 	= (int_clear) ? 1'b0 : (regin.timer_count == regout.timer_modulo && regout.timer_count == 8'hFF) | regout.interrupt_st[2];
	
	assign joypad_int	= (int_clear) ? 1'b0 : regout.interrupt_st[4] | 
							((~joypad_up & prev_up) 	| (~joypad_down & prev_down) 	| (~joypad_left & prev_left) 	| (~joypad_right & prev_right) | 
							 (~joypad_b & prev_b) 		| (~joypad_a & prev_a) 			| (~joypad_start & prev_start) 	| (~joypad_select & prev_select));

	assign lcdc_int		= (int_clear) ? 1'b0 : regout.interrupt_st[1] | 
							((regout.lcd_status[6]) ? ~regout.lcd_status[2] && regin.lcd_status[2] : 1'b0) | 
							((regout.lcd_status[5]) ? ~(regout.lcd_status[1:0] == 2'b10) && mode == 2'b10 : 1'b0) |
							((regout.lcd_status[4]) ? ~(regout.lcd_status[1:0] == 2'b01) && mode == 2'b01 : 1'b0) |
							((regout.lcd_status[3]) ? ~(regout.lcd_status[1:0] == 2'b00) && mode == 2'b00 : 1'b0);
							
	assign vblank_int	= (int_clear) ? 1'b0 : regout.interrupt_st[0] | (regout.lcd_status[1:0] != 2'b01 && mode == 2'b01);
	
	assign serial_int	= 1'b0;
	
	// Control register next state
	always_comb begin

		regin.joypad[7:6] = 2'b0;
		regin.joypad[5:4] = regout.joypad[5:4];
		regin.joypad[3] = (regout.joypad[5] | joypad_start) & (regout.joypad[4] | joypad_down);
		regin.joypad[2] = (regout.joypad[5] | joypad_select) & (regout.joypad[4] | joypad_up);
		regin.joypad[1] = (regout.joypad[5] | joypad_b) & (regout.joypad[4] | joypad_left);
		regin.joypad[0] = (regout.joypad[5] | joypad_a) & (regout.joypad[4] | joypad_right);

		regin.serial_data = regout.serial_data;
		regin.serial_control = regout.serial_control;
		
		regin.timer_divide = (div_256) ? regout.timer_divide + 1 : regout.timer_divide;
		case (regout.timer_control[1:0])
			2'b00: regin.timer_count = (div_1024 && regout.timer_control[2]) ? 
					((regout.timer_count == 8'hFF) ? regout.timer_modulo : (regout.timer_count + 1)) : regout.timer_count;
			2'b01: regin.timer_count = (div_16 && regout.timer_control[2]) ? 
					((regout.timer_count == 8'hFF) ? regout.timer_modulo : (regout.timer_count + 1)) : regout.timer_count;
			2'b10: regin.timer_count = (div_64 && regout.timer_control[2]) ? 
					((regout.timer_count == 8'hFF) ? regout.timer_modulo : (regout.timer_count + 1)) : regout.timer_count;
			2'b11: regin.timer_count = (div_256 && regout.timer_control[2]) ? 
					((regout.timer_count == 8'hFF) ? regout.timer_modulo : (regout.timer_count + 1)) : regout.timer_count;
		endcase
		regin.timer_control = regout.timer_control;
		regin.timer_modulo = regout.timer_modulo;
		
		regin.interrupt_st = {3'b0, joypad_int, serial_int, timer_int, lcdc_int, vblank_int};
		
		regin.lcd_control = regout.lcd_control;
		regin.lcd_status = {1'b0, regout.lcd_status[6:3], regout.lcd_v == regout.lcd_v_cp, mode};
		
		regin.scroll_y = regout.scroll_y;
		regin.scroll_x = regout.scroll_x;
		regin.lcd_v = lcd_v;
		regin.lcd_v_cp = regout.lcd_v_cp;
		
		regin.bg_pal = regout.bg_pal;
		regin.obj_pal0 = regout.obj_pal0;
		regin.obj_pal1 = regout.obj_pal1;
		regin.win_y = regout.win_y;
		regin.win_x = regout.win_x;
		
		regin.dma = 8'b0;
		
		regin.dmg_disable = regout.dmg_disable;
		regin.interrupt_en = regout.interrupt_en;
	end
	
endmodule: top