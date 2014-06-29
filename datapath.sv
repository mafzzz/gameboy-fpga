/**************************************************************************
*	"datapath.sv"
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
`include "registerfile.sv"
`include "alu.sv"
`include "controlpath.sv"

/* Module Datapath: Defines the core CPU
*
*	Connects RegisterFile, ALU, and Controlpath to create CPU.
*	
*/
module datapath
	(input logic			clk,
	input logic				rst,
	
	// Memory datapath bus
	output logic			WE,
	output logic			RE,
	inout tri 	 [7:0]		databus,
	output reg   [15:0]		MAR,
	
	// Interrupt lines
	input logic			vblank_int,
	input logic			lcdc_int,
	input logic			timer_int,
	input logic 		serial_int,
	input logic			joypad_int,
	
	// Register window (for debugging)
	output logic [7:0]		regA,
	output logic [7:0]		regB,
	output logic [7:0]		regC,
	output logic [7:0]		regD,
	output logic [7:0]		regE,
	output logic [7:0]		regF,
	output logic [7:0]		regH,
	output logic [7:0]		regL);
	
	reg [15:0] 			SP, PC;
	reg [7:0]  			IR, MDR;
	
	logic [15:0]		SP_next, PC_next, MAR_next;
	logic [7:0]			IR_next, MDR_next;
		
	logic [15:0]		addr_out;
		
	logic [3:0]			alu_flags, flags_in, flags_out;
	
	logic [7:0]			outA, outB;
		
	// {MEMAH, FLAGS, MEMA_h, MEMA_l, SP, REGA, PC, MEMA, MEMD, PCH, PCL, SPH, SPL, REG}
	logic [13:0]		dest_en;
		
	control_code_t		controls;
	
	logic [7:0]			alu_output;
			
	logic [63:0]		window;

	logic [7:0] 		inA, inB;
		
	logic				PC_dec_h, PC_inc_h, SP_dec_h, SP_inc_h;
	
	control_reg_t		regin, regout;
	
	assign RE = controls.read_en | controls.load_op_code; 
	assign WE = controls.write_en;
	
	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			SP 	<= 16'b0;
			PC 	<= 16'b0;
			MAR <= 16'b0;
			IR  <=  8'b0;
			MDR <=  8'b0;
		end else begin
			SP 	<=  SP_next;
			PC 	<=  PC_next;
			MAR <=  (controls.fetch) ? PC : MAR_next;
			IR  <=  IR_next;
			MDR <=  MDR_next;
		end
	end
	
	/*
	*	ALU destination 1-hot decoder
	*/
	always_comb begin
		case (controls.alu_dest)
			dest_NONE:  	dest_en = 14'b00_0000_0000_0000;
			dest_REG:   	dest_en = 14'b00_0000_0000_0001;
			dest_SP_l:  	dest_en = 14'b00_0000_0000_0010;
			dest_SP_h:  	dest_en = 14'b00_0000_0000_0100;
			dest_PC_l:  	dest_en = 14'b00_0000_0000_1000;
			dest_PC_h:  	dest_en = 14'b00_0000_0001_0000;
			dest_MEMD:  	dest_en = 14'b00_0000_0010_0000;
			dest_MEMA:  	dest_en = 14'b00_0000_0100_0000;
			dest_PC:		dest_en = 14'b00_0000_1000_0000;
			dest_REGA:  	dest_en = 14'b00_0001_0000_0000;
			dest_SP:		dest_en = 14'b00_0010_0000_0000;
			dest_MEMA_l:	dest_en = 14'b00_0100_0000_0000;
			dest_MEMA_h:	dest_en = 14'b00_1000_0000_0000;
			dest_FLAGS:		dest_en = 14'b01_0000_0000_0000;
			dest_MEMAH:		dest_en	= 14'b10_0000_0000_0000;
			default:		dest_en = 14'bxx_xxxx_xxxx_xxxx;
		endcase
	end
	
	assign flags_in = 	(dest_en[12]) ? alu_output[7:4] : ((controls.ld_flags) ? alu_flags : flags_out);
	
	assign databus = (controls.write_en) ? MDR : 8'bz;
	
	assign IR_next			= (controls.load_op_code) ? databus : IR;
	
	always_comb 
		if (dest_en[9])
			SP_next			= addr_out;
		else begin
			SP_next[7:0] 	= (dest_en[1]) ? alu_output : SP[7:0];
			SP_next[15:8]	= (SP_dec_h) ? SP[15:8] - 1: ((SP_inc_h) ? SP[15:8] + 1 : ((dest_en[2]) ? alu_output : SP[15:8]));
		end
	
	always_comb begin
		if (controls.fetch)
			PC_next = PC + 1;
		else if (dest_en[7])
			PC_next = addr_out;
		else begin
			PC_next[7:0] 	= (dest_en[3]) ? alu_output : PC[7:0];
			PC_next[15:8]	= (PC_dec_h) ? PC[15:8] - 1 : ((PC_inc_h) ? PC[15:8] + 1 : ((dest_en[4]) ? alu_output : PC[15:8]));
		end
	end
	
	assign MDR_next		 	= (controls.read_en) ? databus : ((dest_en[5]) ? alu_output : MDR);
		
	register_file	rf 	(.reg_input (alu_output), .reg_selA (controls.reg_selA), .reg_selB (controls.reg_selB), .rst (rst), .addr_input (addr_out),
		.clk (clk), .load_en ({dest_en[8], dest_en[0]}), .flags_in (flags_in), .reg_outA (outA), .reg_outB (outB), .flags (flags_out), .window (window));
	
	assign regA = window[7:0];
	assign regB = window[15:8];
	assign regC = window[23:16];
	assign regD = window[31:24];
	assign regE = window[39:32];
	assign regF = window[47:40];
	assign regH = window[55:48];
	assign regL = window[63:56];
	
	always_comb begin
		case (controls.alu_srcA)
			src_NONE: inA = 8'bx;
			src_REGA: inA = outA;
			src_REGB: inA = outB;
			src_SP_l: inA = SP[7:0];
			src_SP_h: inA = SP[15:8];
			src_PC_l: inA = PC[7:0];
			src_PC_h: inA = PC[15:8];
			src_MEMD: inA = MDR;
			src_MEMA: inA = MAR[15:8];
			src_FLAGS:inA = {flags_out, 4'b0};
			default:  inA = 8'bx;
		endcase
	end
	
	always_comb begin
		case (controls.alu_srcB)
			src_NONE: inB = 8'bx;
			src_REGA: inB = outA;
			src_REGB: inB = outB;
			src_SP_l: inB = SP[7:0];
			src_SP_h: inB = SP[15:8];
			src_PC_l: inB = PC[7:0];
			src_PC_h: inB = PC[15:8];
			src_MEMD: inB = MDR;
			src_MEMA: inB = MAR[7:0];
			src_FLAGS:inB = {flags_out, 4'b0};
			default:  inB = 8'bx;
		endcase
	end
	
	alu				al	(.op_A (inA), .op_B (inB), .op_code (controls.alu_op), .curr_flags (flags_out), .next_flags (alu_flags), .alu_result (alu_output),
		.addr_result (addr_out), .PC_inc_h (PC_inc_h), .PC_dec_h (PC_dec_h), .SP_inc_h (SP_inc_h), .SP_dec_h (SP_dec_h), .bit_num (controls.bit_num));
	
	assign MAR_next = (dest_en[13]) ? {8'hFF, alu_output} : ((dest_en[6]) ? addr_out : ((dest_en[10]) ? {MAR[15:8], alu_output[7:0]} : 
					  ((dest_en[11]) ? {alu_output, MAR[7:0]} : MAR)));
	
	control_path	cp	(.op_code (IR), .rst (rst), .clk (clk), .flags (flags_out), .control (controls));
	
endmodule: datapath