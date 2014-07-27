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
	input logic 		clk_hdmi,
	input logic			clk_cpu,
	input logic 		rst,
	
	// READ GAMEBOY MEM SIGNALS
	output reg [12:0] 	rd_address,
	output logic 		oe_oam,
	output logic 		oe_vram,
	input reg [7:0] 	read_data,
	
	// CONTROL REGISTERS
	input control_reg_t control,
	output logic [1:0]	mode,
	output logic [7:0]	lcd_v,
	
	// HDMI SIGNALS
	input logic 		HDMI_DE,
	input logic 		HDMI_VSYNC,
	input logic 		HDMI_HSYNC,
	output logic [23:0] HDMI_DO
	);
	
	reg [7:0] row;
	reg [8:0] col;
	
	reg [1:0] row_repeat, col_repeat;
		
	// Double line buffers
	reg [1:0] output_buffer [159:0];
	reg [1:0] render_buffer [159:0];
	
	always_comb begin
		if (row == 8'd144 || col == 9'd159)
			HDMI_DO = 24'h202020; 
		else if (row > 8'd144 || col > 9'd159)
			HDMI_DO = 24'h236467; 
		else begin
			if (~control.lcd_control[7]) 
				HDMI_DO = 24'h000000;
			else begin
				case (output_buffer[col])
					2'b00: HDMI_DO = 24'hC0B0B0;
					2'b01: HDMI_DO = 24'h908080;
					2'b10: HDMI_DO = 24'h605050;
					2'b11: HDMI_DO = 24'h302020;
					default: HDMI_DO = 24'h000000;
				endcase
			end
		end
	end

	always_ff @(posedge clk_hdmi) begin
		if (col == 9'd159 && col_repeat == 2'b10 && row_repeat == 2'b10)
			output_buffer <= render_buffer;
		else
			output_buffer <= output_buffer;
	end
	
	always_ff @(posedge clk_hdmi, posedge rst) begin
		if (rst) begin
			oe_vram <= `FALSE;
			oe_oam <= `FALSE;
			rd_address <= 13'b0;
		end else if (row > (control.scroll_y - 8'd10) && row < (control.scroll_y + 8'd10) && col > 9'd30 && col < 9'd130) begin
			render_buffer[col] = 2'b11;
		end else begin
			render_buffer[col] = 2'b00;
		end
	end

	// Vertical line currently being drawn
	assign lcd_v = row;
	
	// Current row/columns to be drawn
	// Repeat is repeat number of current row/column: repeats 3 times
	always_ff @(posedge clk_hdmi, posedge rst) begin
		if (rst) begin
			row <= 8'b0;
			col <= 9'b0;
			row_repeat <= 2'b0;
			col_repeat <= 2'b0;
		end else if (~control.lcd_control[7]) begin
			row <= 8'd144;
			col <= 9'd160;
			row_repeat <= 2'b0;
			col_repeat <= 2'b0;
		end else if (~HDMI_VSYNC) begin
			col_repeat <= 2'b0;
			row_repeat <= 2'b0;
			col <= 9'b0;
			row <= 8'b0;
		end else if (~HDMI_HSYNC) begin
			col_repeat <= 2'b0;
			row_repeat <= row_repeat;
			col <= 9'b0;
			row <= row;
		end else if (HDMI_DE) begin

			col_repeat <= (col_repeat == 2'b10) ? 2'b00 : col_repeat + 1;
			row_repeat <= (col == 9'd159 && col_repeat == 2'b10) ? ((row_repeat == 2'b10) ? 2'b00 : row_repeat + 1) : row_repeat;

			col <= (col_repeat == 2'b10) ? ((col == 9'd160) ? col : col + 1) : col;
			row <= (col_repeat == 2'b10 && row_repeat == 2'b10 && col == 9'd159) ? ((row == 8'd153) ? row : row + 1) : row;

		end else begin
			col_repeat <= col_repeat;
			row_repeat <= row_repeat;
			col <= col;
			row <= row;
		end
	end
	
	// Video driver current mode:
	// 		* 00 -> HSYNC
	//		* 01 -> VSYNC
	//		* 10 -> OE_OAM
	//		* 11 -> OE_VRAM/OE_OAM
	always_comb begin
		if (row > 8'd143)
			mode = 2'b01;
		else if (col > 8'd159 && row_repeat == 2'b00)
			mode = 2'b00;

		else 
			mode = 2'b11;
	end
	
endmodule: display