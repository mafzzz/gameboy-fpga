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
	output reg [7:0] 	rd_address_oam,
	output reg [12:0] 	rd_address_vram,
	output logic 		oe_oam,
	output logic 		oe_vram,
	output logic 		ld_address_oam,
	output logic		ld_address_vram,
	input reg [7:0] 	read_data_oam,
	input reg [7:0]		read_data_vram,
	
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
	reg [7:0] col;
	reg [4:0] render_col;
	
	reg [1:0] row_repeat, col_repeat;
		
	// Double line draw buffers
	reg [0:15] output_buffer [31:0];
	reg [0:15] render_buffer [31:0];
		
	// OAM data line buffer
	reg [13:0] oam_data_buffer [9:0];
	
	reg render_enable;
	
	draw_state_t draw_state;
		
	always_comb begin
		if (row == 8'd144 || col == 8'd159)
			HDMI_DO = 24'h202020; 
		else if (row > 8'd144 || col > 8'd159)
			HDMI_DO = 24'h236467; 
		else begin
			if (~render_enable) 
				HDMI_DO = 24'hC0B0B0;
			else begin
				case ({output_buffer[col[7:3]][{1'b1,col[2:0]}], output_buffer[col[7:3]][{1'b0,col[2:0]}]})
					2'b00: HDMI_DO = 24'hC0B0B0;
					2'b01: HDMI_DO = 24'h908080;
					2'b10: HDMI_DO = 24'h605050;
					2'b11: HDMI_DO = 24'h302020;
					default: HDMI_DO = 24'h981254;
				endcase
			end
		end
	end

	always_ff @(posedge clk_hdmi) begin
		if (col == 8'd159 && col_repeat == 2'b10 && row_repeat == 2'b10)
			output_buffer <= render_buffer;
		else
			output_buffer <= output_buffer;
	end
	
	always_ff @(posedge clk_cpu, posedge rst) begin
		if (rst) begin
			oe_vram <= `FALSE;
			oe_oam <= `FALSE;
			ld_address_oam <= `FALSE;
			ld_address_vram <= `FALSE;
			render_col <= 5'b0;
			rd_address_oam <= 8'b0;
			rd_address_vram <= 13'b0;
			draw_state <= s_WAIT;
		end else begin

			case (draw_state)
				// IDLE STATE
				s_WAIT: begin
					oe_vram <= `FALSE;
					oe_oam <= `FALSE;
					ld_address_oam <= `FALSE;
					ld_address_vram <= `FALSE;
					render_col <= 5'b0;
					rd_address_vram <= 13'b0;
					rd_address_oam <= 8'h00;
					draw_state <= (col == 8'b00 & HDMI_HSYNC & render_enable && row_repeat == 2'b00) ? 
									((control.lcd_control[1]) ? s_OAM_LD_ADDR : s_BACK_LD_ADDR) : s_WAIT;
				end
				
				// OAM SEARCH
				s_OAM_LD_ADDR: begin
					rd_address_oam <= 8'h9C;
					ld_address_oam <= `TRUE;
					draw_state <= s_OAM_READ_BLK;
				end
				s_OAM_READ_BLK: begin
					oe_oam <= `TRUE;
					ld_address_oam <= `TRUE;
					rd_address_oam <= rd_address_oam + 1'b1;
					draw_state <= s_OAM_INSPECT_BLK;
				end
				s_OAM_INSPECT_BLK: begin
					oe_oam <= `TRUE;
					ld_address_oam <= `TRUE;
					rd_address_oam <= rd_address_oam - 3'h5;
					
					// y-coordinate read
					draw_state <= (((read_data_oam - 5'd16) >> 2'd3) == row[7:3]) ? s_OAM_BUFF_BLK : ((rd_address_oam == 8'h01) ? s_BACK_LD_ADDR : s_OAM_READ_BLK);
				end
				s_OAM_BUFF_BLK: begin
					oe_oam <= `FALSE;
					ld_address_oam <= `FALSE;
					render_col <= (render_col == 5'h9 || rd_address_oam == 8'h9C) ? 5'h0 : render_col + 1;
					
					// x-coordinate read
					oam_data_buffer[render_col] <= {read_data_oam - 5'd8, rd_address_oam[7:2]};
					draw_state <= (rd_address_oam == 8'h9C) ? s_BACK_LD_ADDR : s_OAM_READ_BLK;
				end
				
				// BACKGROUND RENDER
				s_BACK_LD_ADDR: begin
					oe_oam <= `FALSE;
					ld_address_oam <= `FALSE;
					
					rd_address_vram[9:0] <= control.scroll_x[7:3] + render_col + {{control.scroll_y + row} >> 2'd3, 5'b0};
					rd_address_vram[12:10] <= ((control.lcd_control[3]) ? 3'h7 : 3'h6);
					ld_address_vram <= `TRUE;
					draw_state <= s_BACK_READ_INDEX;
				end
				s_BACK_READ_INDEX: begin
					oe_vram <= `TRUE;
					ld_address_vram <= `FALSE;
					draw_state <= s_BACK_LD_INDEX;
				end
				s_BACK_LD_INDEX: begin
					oe_vram <= `FALSE;
					ld_address_vram <= `TRUE;
					rd_address_vram <= ((control.lcd_control[4]) ? 13'h0000 : 13'h0800) + {read_data_vram, row[2:0] + control.scroll_y[2:0], 1'b0};
					draw_state <= s_BACK_READ_PIXELS;
				end
				s_BACK_READ_PIXELS: begin
					oe_vram <= `TRUE;
					ld_address_vram <= `TRUE;
					rd_address_vram <= rd_address_vram + 1;
					draw_state <= s_BACK_LD_PIXELS1;
				end
				s_BACK_LD_PIXELS1: begin
					oe_vram <= `TRUE;
					ld_address_vram <= `FALSE;
					render_buffer[render_col][8:15] <= read_data_vram;
					draw_state <= s_BACK_LD_PIXELS2;
				end
				s_BACK_LD_PIXELS2: begin
					oe_vram <= `FALSE;
					render_buffer[render_col][0:7] <= read_data_vram;
					render_col <= render_col + 1;
					draw_state <= (render_col == 5'h13) ? s_WAIT : s_BACK_LD_ADDR;
				end
				
				default: begin
					draw_state <= s_WAIT;
				end
			endcase
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
			render_enable <= `FALSE;
		end else if (~HDMI_VSYNC) begin
			col_repeat <= 2'b0;
			row_repeat <= 2'b0;
			col <= 8'b0;
			row <= 8'b0;
			render_enable <= control.lcd_control[7];
		end else if (~HDMI_HSYNC) begin
			col_repeat <= 2'b0;
			row_repeat <= row_repeat;
			col <= 8'b0;
			row <= row;
		end else if (HDMI_DE) begin

			col_repeat <= (col_repeat == 2'b10) ? 2'b00 : col_repeat + 1;
			row_repeat <= (col == 8'd159 && col_repeat == 2'b10) ? ((row_repeat == 2'b10) ? 2'b00 : row_repeat + 1) : row_repeat;

			col <= (col_repeat == 2'b10) ? ((col == 8'd160) ? col : col + 1) : col;
			row <= (col_repeat == 2'b10 && row_repeat == 2'b10 && col == 8'd159) ? ((row == 8'd153) ? row : row + 1) : row;

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
		if (~render_enable | row > 8'd143 | ~HDMI_VSYNC)
			mode = 2'b01;
		else if (draw_state == s_WAIT)
			mode = 2'b00;
		else if (draw_state == s_OAM_LD_ADDR || draw_state == s_OAM_READ_BLK || draw_state == s_OAM_INSPECT_BLK || draw_state == s_OAM_BUFF_BLK)
			mode = 2'b10;
		else
			mode = 2'b11;
	end
	
endmodule: display