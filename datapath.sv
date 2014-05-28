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
`include "controlpath.sv"
`include "memoryunit.sv"
`include "registerfile.sv"
`include "alu.sv"

/* Module Datapath: Connects RegisterFile, ALU, Controlpath, and Memory units together.
*
*	WIP
*
*/
module datapath
	(input logic		clk,
	input logic			rst,
	output logic [7:0]	regA,
	output logic [7:0]	regB);
	
	reg [15:0] 			SP, PC, MAR;
	reg [7:0]  			IR, MDR;
	
	logic [15:0]		SP_next, PC_next, MAR_next;
	logic [7:0]			IR_next, MDR_next;
	
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
			MAR <=  MAR_next;
			IR  <=  IR_next;
			MDR <=  MDR_next;
		end
	end

	logic [7:0]			alu_output;
	control_code_t		controls;
		
	logic [3:0]			alu_flags, flags_in, flags_out;
	assign flags_in = 	(controls.ld_flags) ? alu_flags : flags_out;
		
	logic 				fetch;
	logic [7:0]			outA, outB;

	// {REGA, PC, MEMA, MEMD, PCH, PCL, SPH, SPL, REG}
	logic [8:0]			dest_en;
	
	always_comb begin
		case (controls.alu_dest)
			dest_NONE:  dest_en = 9'b00000_0000;
			dest_REG:   dest_en = 9'b00000_0001;
			dest_SP_l:  dest_en = 9'b00000_0010;
			dest_SP_h:  dest_en = 9'b00000_0100;
			dest_PC_l:  dest_en = 9'b00000_1000;
			dest_PC_h:  dest_en = 9'b00001_0000;
			dest_MEMD:  dest_en = 9'b00010_0000;
			dest_MEMA:  dest_en = 9'b00100_0000;
			dest_PC:	dest_en = 9'b01000_0000;
			dest_REGA:  dest_en = 9'b10000_0000;
			default:	dest_en = 9'bxxxx_xxxx;
		endcase
	end
	
	tri [7:0] 			databus;
	assign databus = (controls.write_en) ? MDR : 8'bz;
	
	assign IR_next			= (fetch) ? databus : IR;
	
	assign SP_next[7:0] 	= (dest_en[1]) ? alu_output : SP[7:0];
	assign SP_next[15:8]	= (dest_en[2]) ? alu_output : SP[15:8];
	
	always_comb begin
		if (fetch)
			PC_next = PC + 1;
		else if (dest_en[7])
			PC_next = MAR_next;
		else begin
			PC_next[7:0] 	= (dest_en[3]) ? alu_output : PC[7:0];
			PC_next[15:8]	= (dest_en[4]) ? alu_output : PC[15:8];
		end
	end
	
	assign MDR_next		 	= (controls.read_en) ? databus : ((dest_en[5]) ? alu_output : MDR);
	
	logic [63:0]			window;
	
	register_file	rf 	(.reg_input (alu_output), .reg_selA (controls.reg_selA), .reg_selB (controls.reg_selB), .rst (rst), .addr_input (MAR_next),
		.clk (clk), .load_en ({dest_en[8], dest_en[0]}), .flags_in (flags_in), .reg_outA (outA), .reg_outB (outB), .flags (flags_out), .window (window));
	
	assign regA = window[7:0];
	assign regB = window[15:8];
	
	logic [7:0] 		inA, inB;
	
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
			src_MEMA: inA = MAR;
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
			src_MEMA: inB = MAR;
			default:  inB = 8'bx;
		endcase
	end
	
	alu				al	(.op_A (inA), .op_B (inB), .op_code (controls.alu_op), .curr_flags (flags_out), .next_flags (alu_flags), .alu_result (alu_output),
		.addr_result (MAR_next));
	
	control_path		cp	(.op_code (IR), .rst (rst), .clk (clk), .flags (flags_out), .control (controls), .fetch_op_code (fetch));
	
	logic [15:0]	address;
	assign address = (fetch) ? PC : MAR;
	
	sram			mu	(.clk (clk), .address (address), .databus (databus), .RE (controls.read_en | fetch), .WE (controls.write_en));
	
endmodule: datapath