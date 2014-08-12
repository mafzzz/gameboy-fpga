/**************************************************************************
*	"chipinterface.sv"
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

`define synthesis
`include "top.sv"

/* Module ChipInterface: Connects Cyclone V board ports to datapath
*
*	WIP
*
*/
module ChipInterface
	/* ------------------------------------------------------------*/
	/***  CHIP PORT DECLARATIONS ***/
	/* ------------------------------------------------------------*/
	(
	// buttons/leds
	input logic [3:0]	KEY,
	input logic [9:0]	SW,
	output logic [6:0]	HEX0, HEX1, HEX2, HEX3,
	
	// clocks
	input logic			CLOCK_50_B5B,
	
	// hdmi
	output logic		I2C_SCL,
	inout tri 			I2C_SDA,
	output logic [23:0] HDMI_TX_D,
	output logic 		HDMI_TX_CLK,
	output logic 		HDMI_TX_DE,
	output logic 		HDMI_TX_HS,
	output logic 		HDMI_TX_VS
	);
	
	/* ------------------------------------------------------------*/
	/***  ALTERA PLL CLOCKS ***/
	/* ------------------------------------------------------------*/

	logic cpu_clk, clk_out;
	logic clk_lock, video_clk;		
	logic rst;

	// Altera PLL module for 4.19 MHz clock
	clock ck (.refclk (CLOCK_50_B5B), .rst (rst), .outclk_0 (HDMI_TX_CLK), .outclk_1 (clk_out));

	assign cpu_clk = clk_out;

	
	/* ------------------------------------------------------------*/
	/***  CPU CORE INTANTIATION ***/
	/* ------------------------------------------------------------*/

	assign rst = ~KEY[0];
	
	logic [7:0]			regA, regB, regC, regD, regE, regF, regH, regL;
	logic [7:0] 		outa, outb;
	logic [15:0] 		PC;
	
	logic 		 joypad_up, joypad_down, joypad_right, joypad_left, joypad_a, joypad_b, joypad_start, joypad_select;
	
	assign joypad_up = SW[5];
	assign joypad_down = SW[4];
	assign joypad_left = SW[3];
	assign joypad_right = SW[2];
	assign joypad_b = SW[1];
	assign joypad_a = SW[0];
	assign joypad_start = KEY[3];
	assign joypad_select = KEY[2];
	
	reg [31:0] cycles;
	reg [15:0] cksm;
	always @(posedge cpu_clk, posedge rst) begin
		if (rst) begin
			cycles <= 32'b0;
			cksm <= 16'b0;
		end else begin
			cksm <= cksm + PC;
			cycles <= cycles + 1'b1;
		end
	end
	
	// 00: AF    01: BC    10: DE    11: HL
	assign outa = SW[6] ? PC[15:8] : SW[7] ? cksm[15:8] : ((~SW[9] & ~SW[8]) ? regA : ((~SW[9] & SW[8]) ? regB : ((SW[9] & ~SW[8]) ? regD : ((SW[9] & SW[8]) ? regH : 8'b0))));
	assign outb = SW[6] ? PC[7:0] : SW[7] ? cksm[7:0] : ((~SW[9] & ~SW[8]) ? regF : ((~SW[9] & SW[8]) ? regC : ((SW[9] & ~SW[8]) ? regE : ((SW[9] & SW[8]) ? regL : 8'b0))));
	
	sseg a_outh(outa[7:4], HEX3);
	sseg a_outl(outa[3:0], HEX2);
	sseg b_outh(outb[7:4], HEX1);
	sseg b_outl(outb[3:0], HEX0);

	top GameBoy (.*);
	
	/* ------------------------------------------------------------*/
	/***  HDMI I2C INSTANTIATION ***/
	/* ------------------------------------------------------------*/
	reg [7:0] outA;
	reg stop;

	reg [3:0] counter;
	reg clk_reduced;
	reg ack;
	// Divide 4.19 MHz clk by 11 to give 381 kHz I2C logic driver. 
	always @(posedge cpu_clk) begin
		counter = (counter == 4'hA) ? 4'h0 : counter + 4'h1;
		clk_reduced = (stop) ? 1'b0 : ((counter == 4'h0) ? ~clk_reduced : clk_reduced);
	end
	
	i2c bus(.stop (stop), .clk (clk_reduced), .rst (rst), .outA (outA), .SDA (I2C_SDA), .SCL (I2C_SCL), .ACK (ack));

endmodule: ChipInterface

module sseg 
	(input logic [3:0]	num,
	output logic [6:0]	out);
	
	logic [6:0] disp;
	assign out = ~disp;
	
	always_comb begin
	
		case(num)
			4'h0: 		disp = 7'b011_1111;
			4'h1: 		disp = 7'b000_0110;
			4'h2: 		disp = 7'b101_1011;
			4'h3: 		disp = 7'b100_1111;
			4'h4: 		disp = 7'b110_0110;
			4'h5: 		disp = 7'b110_1101;
			4'h6: 		disp = 7'b111_1101;
			4'h7: 		disp = 7'b000_0111;
			4'h8: 		disp = 7'b111_1111;
			4'h9: 		disp = 7'b110_0111;
			4'hA: 		disp = 7'b111_0111;
			4'hB: 		disp = 7'b111_1100;
			4'hC: 		disp = 7'b011_1001;
			4'hD: 		disp = 7'b101_1110;
			4'hE: 		disp = 7'b111_1001;
			4'hF: 		disp = 7'b111_0001;
			default:	disp = 7'b100_0000;
		endcase
	
	end
	
endmodule: sseg