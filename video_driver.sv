/**************************************************************************
*	"video_driver.sv"
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
`include "HDMI.sv"

/* 	Module display: Display driver
*
*	Translates VRAM, lcd control regs, and OAM to data signals for HDMI driver
*
*/
module display
	(
	// CLOCK/RST
	input logic clk_hdmi,
	input logic rst,
		
	// READ GAMEBOY MEM SIGNALS
	output logic [12:0] rd_address,
	output logic oe_oam,
	output logic oe_vram,
	input logic [7:0] read_data,
	
	// CONTROL REGISTERS
	input control_reg_t control,
	
	// HDMI SIGNALS
	input logic HDMI_DE,
	input logic HDMI_VSYNC,
	input logic HDMI_HSYNC,
	output logic [23:0] HDMI_DO,
	);
	
	
	
endmodule: display