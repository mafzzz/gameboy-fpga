/**************************************************************************
*	"HDMI.sv"
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

module hdmi
	(input logic clk,
	input logic rst,
	output logic [23:0] data,
	output logic hsync,
	output logic vsync,
	output logic de);
	
	// 10'd000 to 10'd858 (exclusive)
	reg [9:0] horiz_count;
	// 10'd000 to 10'd525 (exclusive
	reg [9:0] vert_count;
	
	always @(posedge clk, posedge rst) begin
		if (rst) begin
			horiz_count <= 10'd000;
			vert_count <= 10'd003;
		end else begin
			horiz_count <= (horiz_count == 10'd857) ? 10'd000 : horiz_count + 10'd001;
			vert_count <= (vert_count == 10'd524) ? 10'd000 : ((horiz_count == 10'd857) ? vert_count + 10'd001 : vert_count);
		end
	end
	
	always_comb begin
		if (horiz_count < 10'd138 || vert_count < 10'd045) 
			de = 1'b0;
		else
			de = 1'b1;
	end
	
	always_comb begin
		if (horiz_count < 10'd078 && horiz_count > 10'd015)
			hsync = 1'b0;
		else
			hsync = 1'b1;
	end
	
	always_comb begin
		if (vert_count > 10'd009 && vert_count < 10'd015)
			vsync = 1'b0;
		else
			vsync = 1'b1;
	end
	
	always_comb begin
		if (horiz_count < 10'd378 && vert_count < 10'd281)
			data = {8'hFF, 8'h00, 8'h00};
		else if (horiz_count < 10'd618 && vert_count < 10'd281)
			data = {8'h00, 8'hFF, 8'h00};
		else if (vert_count < 10'd281)
			data = {8'h00, 8'h00, 8'hFF};
		else if (horiz_count < 10'd378)
			data = {8'hF0, 8'h90, 8'h30};
		else if (horiz_count < 10'd618)
			data = {8'h30, 8'hF0, 8'h90};
		else
			data = {8'h90, 8'h30, 8'hF0};
	end
	
endmodule: hdmi