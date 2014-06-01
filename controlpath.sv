/**************************************************************************
*	"controlpath.sv"
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

/* 	Module Controlpath: Contains instructions on modifying datapath control
*						signals according to OP Code
*
*	The Controlpath contains an FSM that runs through FETCH, DECODE, EXECUTE, 
*	and WRITE states and operates on all OP Codes. 
*/
module control_path
	(input op_code_t		op_code,
	input logic [3:0]		flags,
	input logic 			rst,
	input logic				clk,
	output control_code_t 	control);
	
	// Whether the current instruction is a CB prefix instruction
	logic				prefix_CB, next_prefix;
	
	// How many iterations of FETCH, DECODE, EXECUTE, WRITE current instruction 
	// 		has gone through
	logic [2:0]			iteration, next_iteration;
	
	// FSM states
	control_state_t		curr_state, next_state;
	
	always_ff @(posedge clk, posedge rst) begin
		// Reset into FETCH state, first instruction iteration, no prefix
		if (rst) begin
			curr_state <= s_FETCH;
			iteration <= 3'b0;
			prefix_CB <= `FALSE;
		end
		
		// Next state
		else begin
			iteration <= next_iteration;
			prefix_CB <= next_prefix;
			curr_state <= next_state;
		end
	end
			
	always_comb begin
		
		unique case (curr_state)
		
			/*	State = FETCH
			*
			*	Tells Datapath to retrieve next instruction from memory and increment
			*	the PC if on first iteration. 
			*
			*	Does nothing if not first iteration. 
			*/
			s_FETCH: begin
				
				control.reg_selA 		= reg_UNK;
				control.reg_selB 		= reg_UNK;
				control.alu_op   		= alu_UNK;
				control.alu_srcA		= src_UNK;
				control.alu_srcB		= src_UNK;	
				control.alu_dest		= dest_NONE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.ld_flags		= `FALSE;
				control.load_op_code 	= `FALSE;
				control.fetch 			= `FALSE;
				next_prefix	  			= prefix_CB;
				next_iteration			= iteration;
				next_state				= s_DECODE;
				
				if (iteration == 3'b0)
					control.fetch 		= `TRUE;

			end
			
			/*	State = DECODE
			*
			*	Writes to Instruction Register to read instruction from. 
			*
			*/
			s_DECODE: begin
				control.reg_selA 		= reg_UNK;
				control.reg_selB 		= reg_UNK;
				control.alu_op   		= alu_UNK;
				control.alu_srcA		= src_UNK;
				control.alu_srcB		= src_UNK;	
				control.alu_dest		= dest_NONE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.ld_flags		= `FALSE;
				control.load_op_code 	= `FALSE;
				control.fetch 			= `FALSE;
				next_prefix	  			= prefix_CB;
				next_iteration			= iteration;
				next_state				= s_EXECUTE;
				
				if (iteration == 3'b0)
					control.load_op_code	= `TRUE;
				
			end
			
			/*	State = EXECUTE
			*
			*	Executes ALU operation or memory read based on iteration and instruction. 
			*/
			s_EXECUTE: begin
				control.reg_selA 		= reg_UNK;
				control.reg_selB 		= reg_UNK;
				control.alu_op   		= alu_UNK;
				control.alu_srcA		= src_UNK;
				control.alu_srcB		= src_UNK;	
				control.alu_dest		= dest_NONE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.ld_flags		= `FALSE;
				control.load_op_code 	= `FALSE;
				control.fetch 			= `FALSE;
				next_prefix	  			= prefix_CB;
				next_iteration			= iteration;
				next_state				= s_WRITE;
				
				if (iteration != 3'b1) begin
					case (op_code)
						// REGISTER LOAD OPERATIONS
						LD_A_D: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_D;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_A_B: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_B;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_A_C: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_C;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_A_E: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_E;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_A_H: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_H;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_A_L: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_L;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_A_A: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_A;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_B_A: begin
							control.reg_selA = reg_B;
							control.reg_selB = reg_A;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_B_B: begin
							control.reg_selA = reg_B;
							control.reg_selB = reg_B;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_B_C: begin
							control.reg_selA = reg_B;
							control.reg_selB = reg_C;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_B_D: begin
							control.reg_selA = reg_B;
							control.reg_selB = reg_D;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_B_E: begin
							control.reg_selA = reg_B;
							control.reg_selB = reg_E;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_B_H: begin
							control.reg_selA = reg_B;
							control.reg_selB = reg_H;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_B_L: begin
							control.reg_selA = reg_B;
							control.reg_selB = reg_L;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_C_A: begin
							control.reg_selA = reg_C;
							control.reg_selB = reg_A;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_C_B: begin
							control.reg_selA = reg_C;
							control.reg_selB = reg_B;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_C_C: begin
							control.reg_selA = reg_C;
							control.reg_selB = reg_C;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_C_D: begin
							control.reg_selA = reg_C;
							control.reg_selB = reg_D;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_C_E: begin
							control.reg_selA = reg_C;
							control.reg_selB = reg_E;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_C_H: begin
							control.reg_selA = reg_C;
							control.reg_selB = reg_H;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_C_L: begin
							control.reg_selA = reg_C;
							control.reg_selB = reg_L;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_D_A: begin
							control.reg_selA = reg_D;
							control.reg_selB = reg_A;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_D_B: begin
							control.reg_selA = reg_D;
							control.reg_selB = reg_B;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_D_C: begin
							control.reg_selA = reg_D;
							control.reg_selB = reg_C;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_D_D: begin
							control.reg_selA = reg_D;
							control.reg_selB = reg_D;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_D_E: begin
							control.reg_selA = reg_D;
							control.reg_selB = reg_E;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_D_H: begin
							control.reg_selA = reg_D;
							control.reg_selB = reg_H;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_D_L: begin
							control.reg_selA = reg_D;
							control.reg_selB = reg_L;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_E_A: begin
							control.reg_selA = reg_E;
							control.reg_selB = reg_A;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_E_B: begin
							control.reg_selA = reg_E;
							control.reg_selB = reg_B;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_E_C: begin
							control.reg_selA = reg_E;
							control.reg_selB = reg_C;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_E_D: begin
							control.reg_selA = reg_E;
							control.reg_selB = reg_D;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_E_E: begin
							control.reg_selA = reg_E;
							control.reg_selB = reg_E;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_E_H: begin
							control.reg_selA = reg_E;
							control.reg_selB = reg_H;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_E_L: begin
							control.reg_selA = reg_E;
							control.reg_selB = reg_L;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_H_A: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_A;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_H_B: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_B;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_H_C: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_C;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_H_D: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_D;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_H_E: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_E;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_H_H: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_H;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_H_L: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_L_A: begin
							control.reg_selA = reg_L;
							control.reg_selB = reg_A;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_L_B: begin
							control.reg_selA = reg_L;
							control.reg_selB = reg_B;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_L_C: begin
							control.reg_selA = reg_L;
							control.reg_selB = reg_C;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_L_D: begin
							control.reg_selA = reg_L;
							control.reg_selB = reg_D;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_L_E: begin
							control.reg_selA = reg_L;
							control.reg_selB = reg_E;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_L_H: begin
							control.reg_selA = reg_L;
							control.reg_selB = reg_H;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						LD_L_L: begin
							control.reg_selA = reg_L;
							control.reg_selB = reg_L;
							control.alu_op   = alu_B;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
						end
						
						
						// LOAD REGISTER IMMEDIATE
						LD_A_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						LD_B_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						LD_C_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						LD_D_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						LD_E_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						LD_H_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						LD_L_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						
						// LOAD MEMORY
						LD_BCA_A: begin
							control.reg_selA = reg_A;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						LD_DEA_A: begin
							control.reg_selA = reg_A;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						LD_HLA_A: begin
							control.reg_selA = reg_A;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						LD_HLP_A: begin
							control.reg_selA = reg_A;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						LD_HLN_A: begin
							control.reg_selA = reg_A;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						LD_HLA_B: begin
							control.reg_selA = reg_B;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						LD_HLA_C: begin
							control.reg_selA = reg_C;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						LD_HLA_D: begin
							control.reg_selA = reg_D;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						LD_HLA_E: begin
							control.reg_selA = reg_E;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						LD_HLA_H: begin
							control.reg_selA = reg_H;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						LD_HLA_L: begin
							control.reg_selA = reg_L;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							control.alu_op	 = alu_B;
						end
						
						// READ MEMORY
						LD_A_BCA: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_B;
							control.reg_selB = reg_C;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						LD_A_DEA: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_D;
							control.reg_selB = reg_E;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						LD_A_HLA: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						LD_A_HLP: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						LD_A_HLN: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						LD_B_HLA: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						LD_C_HLA: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						LD_D_HLA: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						LD_E_HLA: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						LD_H_HLA: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						LD_L_HLA: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
						end
						
						// LOAD MEMORY IMMEDIATE
						LD_N16A_A: begin
							if (iteration == 3'b0) begin
								control.alu_op	 = alu_AB;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_MEMA;
							end else if (iteration == 3'd2) begin
								control.alu_op	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_MEMA_h;
							end else if (iteration == 3'd3) begin
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_PC;		
								control.write_en = `TRUE;
							end
						end
						
						LD_HLA_N8: begin
							if (iteration == 3'b0) begin
								control.alu_op	 = alu_AB;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_MEMA;
							end
						end
						
						// READ MEMORY IMMEDIATE
						LD_A_N16A: begin
							if (iteration == 3'b0) begin
								control.alu_op	 = alu_AB;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_MEMA;
							end else if (iteration == 3'd2) begin
								control.alu_op	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_MEMA_h;
							end else if (iteration == 3'd3) begin
								control.alu_op	 = alu_B;
								control.reg_selA = reg_A;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_REG;
							end
						end
						
						// ADD INSTRUCTIONS
						ADD_A_A: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_A;
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_A_B: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_B;
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_A_C: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_C;
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_A_D: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_D;
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_A_E: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_E;
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_A_H: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_H;
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_A_L: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_A_HLA: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_MEMA;
						end
						ADD_A_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						
						// ADD CARRY
						ADC_A_A: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_A;
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADC_A_B: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_B;
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADC_A_C: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_C;
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADC_A_D: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_D;
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADC_A_E: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_E;
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADC_A_H: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_H;
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADC_A_L: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADC_A_HLA: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_MEMA;
						end
						ADC_A_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						
						// SUBTRACT
						SUB_A_A: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_A;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SUB_A_B: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_B;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SUB_A_C: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_C;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SUB_A_D: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_D;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SUB_A_E: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_E;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SUB_A_H: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_H;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SUB_A_L: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SUB_A_HLA: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_MEMA;
						end
						SUB_A_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end

						// SUBTRACT CARRY
						SBC_A_A: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_A;
							control.alu_op	 = alu_SBC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SBC_A_B: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_B;
							control.alu_op	 = alu_SBC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SBC_A_C: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_C;
							control.alu_op	 = alu_SBC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SBC_A_D: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_D;
							control.alu_op	 = alu_SBC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SBC_A_E: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_E;
							control.alu_op	 = alu_SBC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SBC_A_H: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_H;
							control.alu_op	 = alu_SBC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SBC_A_L: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_SBC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SBC_A_HLA: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_MEMA;
						end
						SBC_A_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end

						// AND OPERATIONS
						AND_A_A: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_A;
							control.alu_op	 = alu_AND;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						AND_A_B: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_B;
							control.alu_op	 = alu_AND;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						AND_A_C: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_C;
							control.alu_op	 = alu_AND;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						AND_A_D: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_D;
							control.alu_op	 = alu_AND;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						AND_A_E: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_E;
							control.alu_op	 = alu_AND;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						AND_A_H: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_H;
							control.alu_op	 = alu_AND;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						AND_A_L: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AND;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						AND_A_HLA: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_MEMA;
						end
						AND_A_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end

						// OR OPERATIONS
						OR_A_A: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_A;
							control.alu_op	 = alu_OR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						OR_A_B: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_B;
							control.alu_op	 = alu_OR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						OR_A_C: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_C;
							control.alu_op	 = alu_OR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						OR_A_D: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_D;
							control.alu_op	 = alu_OR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						OR_A_E: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_E;
							control.alu_op	 = alu_OR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						OR_A_H: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_H;
							control.alu_op	 = alu_OR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						OR_A_L: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_OR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						OR_A_HLA: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_MEMA;
						end
						OR_A_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end

						// XOR OPERATIONS
						XOR_A_A: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_A;
							control.alu_op	 = alu_XOR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						XOR_A_B: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_B;
							control.alu_op	 = alu_XOR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						XOR_A_C: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_C;
							control.alu_op	 = alu_XOR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						XOR_A_D: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_D;
							control.alu_op	 = alu_XOR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						XOR_A_E: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_E;
							control.alu_op	 = alu_XOR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						XOR_A_H: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_H;
							control.alu_op	 = alu_XOR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						XOR_A_L: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_XOR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						XOR_A_HLA: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_MEMA;
						end
						XOR_A_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						
						// COMPARE OPERATIONS
						CP_A_A: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_A;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_NONE;
							control.ld_flags = `TRUE;
						end
						CP_A_B: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_B;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_NONE;
							control.ld_flags = `TRUE;
						end
						CP_A_C: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_C;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_NONE;
							control.ld_flags = `TRUE;
						end
						CP_A_D: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_D;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_NONE;
							control.ld_flags = `TRUE;
						end
						CP_A_E: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_E;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_NONE;
							control.ld_flags = `TRUE;
						end
						CP_A_H: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_H;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_NONE;
							control.ld_flags = `TRUE;
						end
						CP_A_L: begin
							control.reg_selA = reg_A;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_NONE;
							control.ld_flags = `TRUE;
						end
						CP_A_HLA: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_MEMA;
						end
						CP_A_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						
						// INCREMENT OPERATIONS
						INC_A: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_INC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						INC_B: begin
							control.reg_selA = reg_B;
							control.alu_op	 = alu_INC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						INC_C: begin
							control.reg_selA = reg_C;
							control.alu_op	 = alu_INC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						INC_D: begin
							control.reg_selA = reg_D;
							control.alu_op	 = alu_INC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						INC_E: begin
							control.reg_selA = reg_E;
							control.alu_op	 = alu_INC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						INC_H: begin
							control.reg_selA = reg_H;
							control.alu_op	 = alu_INC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						INC_L: begin
							control.reg_selA = reg_L;
							control.alu_op	 = alu_INC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						
						// DECREMENT OPERATIONS
						DEC_A: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_DEC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						DEC_B: begin
							control.reg_selA = reg_B;
							control.alu_op	 = alu_DEC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						DEC_C: begin
							control.reg_selA = reg_C;
							control.alu_op	 = alu_DEC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						DEC_D: begin
							control.reg_selA = reg_D;
							control.alu_op	 = alu_DEC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						DEC_E: begin
							control.reg_selA = reg_E;
							control.alu_op	 = alu_DEC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						DEC_H: begin
							control.reg_selA = reg_H;
							control.alu_op	 = alu_DEC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						DEC_L: begin
							control.reg_selA = reg_L;
							control.alu_op	 = alu_DEC;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						
						// INCREMENT 16-BIT
						INC_BC: begin
							control.reg_selA = reg_B;
							control.reg_selB = reg_C;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REGA;
						end
						INC_DE: begin
							control.reg_selA = reg_D;
							control.reg_selB = reg_E;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REGA;
						end
						INC_HL: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REGA;
						end
						INC_SP: begin
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_SP_l;
							control.alu_srcB = src_SP_h;
							control.alu_dest = dest_SP;
						end

						// DECREMENT 16-BIT
						DEC_BC: begin
							control.reg_selA = reg_B;
							control.reg_selB = reg_C;
							control.alu_op	 = alu_DECL;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REGA;
						end
						DEC_DE: begin
							control.reg_selA = reg_D;
							control.reg_selB = reg_E;
							control.alu_op	 = alu_DECL;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REGA;
						end
						DEC_HL: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_DECL;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_REGA;
						end
						DEC_SP: begin
							control.alu_op	 = alu_DECL;
							control.alu_srcA = src_SP_l;
							control.alu_srcB = src_SP_h;
							control.alu_dest = dest_SP;
						end
						
						// JUMPS ABSOLUTE
						JP_HLA: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_dest = dest_PC;
						end
						JP_N16: begin
							if (iteration == 3'b0) begin 
								control.alu_op	 = alu_AB;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_MEMA;

							end else if (iteration == 3'd2) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_h;
							end
						end
						JP_Z_N16: begin
							if (iteration == 3'b0) begin 
								control.alu_op	 = alu_AB;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_MEMA;
							end else if (iteration == 3'd2) begin
								if (flags[3]) begin
									control.alu_op 	 = alu_B;
									control.alu_srcB = src_MEMD;
									control.alu_dest = dest_PC_h;
								end
							end
						end
						JP_C_N16: begin
							if (iteration == 3'b0) begin 
								control.alu_op	 = alu_AB;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_MEMA;
							end else if (iteration == 3'd2) begin
								if (flags[0]) begin
									control.alu_op 	 = alu_B;
									control.alu_srcB = src_MEMD;
									control.alu_dest = dest_PC_h;
								end
							end
						end
						JP_NZ_N16: begin
							if (iteration == 3'b0) begin 
								control.alu_op	 = alu_AB;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_MEMA;
							end else if (iteration == 3'd2) begin
								if (~flags[3]) begin
									control.alu_op 	 = alu_B;
									control.alu_srcB = src_MEMD;
									control.alu_dest = dest_PC_h;
								end
							end
						end
						JP_NC_N16: begin
							if (iteration == 3'b0) begin 
								control.alu_op	 = alu_AB;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_MEMA;
							end else if (iteration == 3'd2) begin
								if (~flags[0]) begin
									control.alu_op 	 = alu_B;
									control.alu_srcB = src_MEMD;
									control.alu_dest = dest_PC_h;
								end
							end
						end
						
						JP_HLA: begin
							control.alu_op		= alu_AB;
							control.alu_srcA	= src_REGA;
							control.alu_srcB	= src_REGB;
							control.reg_selA	= reg_H;
							control.reg_selB	= reg_L;
							control.alu_dest	= dest_PC;
						end
						
						PREFIX: begin
							next_prefix = `TRUE;
						end
						STOP: begin
							next_state = s_EXECUTE;
							
							// For simulation purposes
							$stop;
						end
						NOP: begin
							// DO NOTHING
						end
						
						default: begin
							// DO NOTHING
						end
					endcase
					
				end else if (iteration == 3'd1) begin
				
					case (op_code) 
						// LOAD REGISTER IMMEDIATE
						LD_A_N8: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_A;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						LD_B_N8: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						LD_C_N8: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_C;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						LD_D_N8: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_D;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						LD_E_N8: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_E;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						LD_H_N8: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_H;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						LD_L_N8: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_L;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						
						// LOAD MEMORY
						LD_BCA_A: begin
							control.write_en = `TRUE;
						end
						LD_DEA_A: begin
							control.write_en = `TRUE;
						end
						LD_HLA_A: begin
							control.write_en = `TRUE;
						end
						LD_HLP_A: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_INCL;
							control.alu_dest = dest_REGA;
							control.write_en = `TRUE;
						end
						LD_HLN_A: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_DECL;
							control.alu_dest = dest_REGA;
							control.write_en = `TRUE;
						end
						LD_HLA_B: begin
							control.write_en = `TRUE;
						end
						LD_HLA_C: begin
							control.write_en = `TRUE;
						end
						LD_HLA_D: begin
							control.write_en = `TRUE;
						end
						LD_HLA_E: begin
							control.write_en = `TRUE;
						end
						LD_HLA_H: begin
							control.write_en = `TRUE;
						end
						LD_HLA_L: begin
							control.write_en = `TRUE;
						end
						
						// READ MEMORY
						LD_A_BCA: begin
							control.reg_selA = reg_A;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end
						LD_A_DEA: begin
							control.reg_selA = reg_A;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end
						LD_A_HLA: begin
							control.reg_selA = reg_A;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end
						LD_A_HLP: begin
							control.reg_selA = reg_A;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end
						LD_A_HLN: begin
							control.reg_selA = reg_A;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end
						LD_B_HLA: begin
							control.reg_selA = reg_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end
						LD_C_HLA: begin
							control.reg_selA = reg_C;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end
						LD_D_HLA: begin
							control.reg_selA = reg_D;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end
						LD_E_HLA: begin
							control.reg_selA = reg_E;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end
						LD_H_HLA: begin
							control.reg_selA = reg_H;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end
						LD_L_HLA: begin
							control.reg_selA = reg_L;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.alu_op	 = alu_B;
						end						
						LD_HLA_N8: begin
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_op	 = alu_AB;
							control.alu_dest = dest_MEMA;
						end
						
						// LOAD MEMORY IMMEDIATE
						LD_N16A_A: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end

						// READ MEMORY IMMEDIATE
						LD_A_N16A: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						
						// ARITHMATIC OPERATIONS
						ADD_A_HLA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADC_A_HLA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SUB_A_HLA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SBC_A_HLA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_SBC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						AND_A_HLA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_AND;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						OR_A_HLA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_OR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						XOR_A_HLA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_XOR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						CP_A_HLA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_NONE;
							control.ld_flags = `TRUE;
						end

						ADD_A_N8: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADC_A_N8: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SUB_A_N8: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SBC_A_N8: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_SBC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						AND_A_N8: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_AND;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						OR_A_N8: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_OR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						XOR_A_N8: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_XOR;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						CP_A_N8: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_SUB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_NONE;
							control.ld_flags = `TRUE;
						end

						// JUMP ABSOLUTE
						JP_N16: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						JP_Z_N16: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						JP_NZ_N16: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						JP_C_N16: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						JP_NC_N16: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						
						default: begin
							// DO NOTHING
						end
					endcase
				end
			end

			/*	State = WRITE
			*
			*	Writes back to registers, increments iteration if more iterations necessary. 
			*	Resets iteration if operation done based on instruction. 
			*/
			s_WRITE: begin
				control.reg_selA 		= reg_UNK;
				control.reg_selB 		= reg_UNK;
				control.alu_op   		= alu_UNK;
				control.alu_srcA		= src_UNK;
				control.alu_srcB		= src_UNK;	
				control.alu_dest		= dest_NONE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.ld_flags		= `FALSE;
				control.load_op_code 	= `FALSE;
				control.fetch 			= `FALSE;
				next_prefix	  			= prefix_CB;
				next_iteration			= iteration;
				next_state				= s_FETCH;

				if (iteration == 3'b0) begin
					case (op_code)
						// LOAD REGISTER IMMEDIATE
						LD_A_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							control.read_en  = `TRUE;
							next_iteration	 = 3'b1;
						end
						LD_B_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							
							control.read_en  = `TRUE;
							next_iteration	 = 3'b1;
						end
						LD_C_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							control.read_en  = `TRUE;
							next_iteration	 = 3'b1;
						end
						LD_D_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.read_en  = `TRUE;
							next_iteration	 = 3'b1;
						end
						LD_E_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.read_en  = `TRUE;
							next_iteration	 = 3'b1;
						end
						LD_H_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.read_en  = `TRUE;
							next_iteration	 = 3'b1;
						end
						LD_L_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.read_en  = `TRUE;
							next_iteration	 = 3'b1;
						end
						
						// LOAD MEMORY
						LD_BCA_A: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_B;
							control.reg_selB = reg_C;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end
						LD_DEA_A: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_D;
							control.reg_selB = reg_E;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end
						LD_HLA_A: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end
						LD_HLP_A: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end
						LD_HLN_A: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end
						LD_HLA_B: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end
						LD_HLA_C: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end
						LD_HLA_D: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end
						LD_HLA_E: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end
						LD_HLA_H: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end
						LD_HLA_L: begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end					
						
						// READ MEMORY
						LD_A_BCA: begin
							control.read_en = `TRUE;
							next_iteration	= 3'b1;
						end
						LD_A_DEA: begin
							control.read_en = `TRUE;
							next_iteration	= 3'b1;
						end
						LD_A_HLA: begin
							control.read_en = `TRUE;
							next_iteration	= 3'b1;
						end
						LD_A_HLP: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_INCL;
							control.alu_dest = dest_REGA;
							control.read_en  = `TRUE;
							next_iteration	 = 3'b1;
						end
						LD_A_HLN: begin
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_DECL;
							control.alu_dest = dest_REGA;
							control.read_en  = `TRUE;
							next_iteration	 = 3'b1;
						end
						LD_B_HLA: begin
							control.read_en = `TRUE;
							next_iteration	= 3'b1;
						end
						LD_C_HLA: begin
							control.read_en = `TRUE;
							next_iteration	= 3'b1;
						end
						LD_D_HLA: begin
							control.read_en = `TRUE;
							next_iteration	= 3'b1;
						end
						LD_E_HLA: begin
							control.read_en = `TRUE;
							next_iteration	= 3'b1;
						end
						LD_H_HLA: begin
							control.read_en = `TRUE;
							next_iteration  = 3'b1;
						end
						LD_L_HLA: begin
							control.read_en = `TRUE;
							next_iteration  = 3'b1;
						end
						
						LD_HLA_N8: begin
							control.read_en	= `TRUE;
							next_iteration	= 3'b1;
						end
						
						// LOAD MEMORY IMMEDIATE
						LD_N16A_A: begin
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_PC;
							
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end
						
						// READ MEMORY IMMEDIATE
						LD_A_N16A: begin
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_PC;
							
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end
						
						// ARITHMATIC OPERATIONS
						ADD_A_HLA: begin
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end
						ADC_A_HLA: begin
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end
						SUB_A_HLA: begin
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end
						SBC_A_HLA: begin
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end
						AND_A_HLA: begin
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end
						OR_A_HLA: begin
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end
						XOR_A_HLA: begin
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end
						CP_A_HLA: begin
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end

						ADD_A_N8: begin
							control.read_en	 = `TRUE;
							next_iteration 	 = 3'b1;
						end
						ADC_A_N8: begin
							control.read_en	 = `TRUE;
							next_iteration 	 = 3'b1;
						end
						SUB_A_N8: begin
							control.read_en	 = `TRUE;
							next_iteration 	 = 3'b1;
						end
						SBC_A_N8: begin
							control.read_en	 = `TRUE;
							next_iteration 	 = 3'b1;
						end
						AND_A_N8: begin
							control.read_en	 = `TRUE;
							next_iteration 	 = 3'b1;
						end
						OR_A_N8: begin
							control.read_en	 = `TRUE;
							next_iteration 	 = 3'b1;
						end
						XOR_A_N8: begin
							control.read_en	 = `TRUE;
							next_iteration 	 = 3'b1;
						end
						CP_A_N8: begin
							control.read_en	 = `TRUE;
							next_iteration 	 = 3'b1;
						end
						
						// JUMP ABSOLUTE
						JP_N16: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.read_en  = `TRUE;
							next_iteration		 = 3'b1;
						end
						JP_Z_N16: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.read_en  = `TRUE;
							next_iteration		 = 3'b1;
						end
						JP_C_N16: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.read_en  = `TRUE;
							next_iteration		 = 3'b1;
						end
						JP_NZ_N16: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.read_en  = `TRUE;
							next_iteration		 = 3'b1;
						end
						JP_NC_N16: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.read_en  = `TRUE;
							next_iteration		 = 3'b1;
						end
					endcase				
					
				end else if (iteration == 3'd1) begin
				
					case(op_code)
					
						// MEMORY OPERATIONS
						LD_HLA_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.write_en  = `TRUE;
							next_iteration		 = 3'd2;
						end
					
						// LOAD MEMORY IMMEDIATE
						LD_N16A_A: begin
							control.alu_op	 = alu_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_MEMA_l;
							
							control.read_en	 = `TRUE;
							next_iteration	 = 3'd2;
						end
						
						// READ MEMORY IMMEDIATE
						LD_A_N16A: begin
							control.alu_op	 = alu_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_MEMA_l;
							
							control.read_en	 = `TRUE;
							next_iteration	 = 3'd2;
						end
					
						// ARITHMATIC OPERATIONS
						ADD_A_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							next_iteration	 = 3'b0;
						end
						ADC_A_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							next_iteration	 = 3'b0;
						end
						SUB_A_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							next_iteration	 = 3'b0;
						end
						SBC_A_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							next_iteration	 = 3'b0;
						end
						AND_A_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							next_iteration	 = 3'b0;
						end
						OR_A_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							next_iteration	 = 3'b0;
						end
						XOR_A_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							next_iteration	 = 3'b0;
						end
						CP_A_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							next_iteration	 = 3'b0;
						end
					
						// JUMP ABSOLUTE
						JP_N16: begin
							control.alu_op 	 = alu_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_PC_l;
							next_iteration	 = 3'd2;
							
							control.read_en  = `TRUE;
						end
						JP_Z_N16: begin
							if (flags[3]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;
								next_iteration	 = 3'd2;
								
								control.read_en  = `TRUE;
							end else begin
								control.alu_dest = dest_PC;
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								next_iteration	 = 3'd2;
							
								control.read_en  = `FALSE;
							end
						end
						JP_C_N16: begin
							if (flags[0]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;
								next_iteration	 = 3'd2;

								control.read_en  = `TRUE;
							end else begin
								control.alu_dest = dest_PC;
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								next_iteration	 = 3'd2;
							
								control.read_en  = `FALSE;
							end
						end
						JP_NZ_N16: begin
							if (~flags[3]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;
								next_iteration	 = 3'd2;

								control.read_en  = `TRUE;
							end else begin
								control.alu_dest = dest_PC;
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								next_iteration	 = 3'd2;
							
								control.read_en  = `FALSE;
							end
						end
						JP_NC_N16: begin
							if (~flags[0]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;
								next_iteration	 = 3'd2;

								control.read_en  = `TRUE;
							end else begin
								control.alu_dest = dest_PC;
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								next_iteration	 = 3'd2;
							
								control.read_en  = `FALSE;
							end
						end
						
						default: begin
							next_iteration		= 3'b0;
						end
					endcase
					
				end else if (iteration == 3'd2) begin
				
					case(op_code)
					
						// LOAD MEMORY IMMEDIATE
						LD_N16A_A: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_A;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
							
							next_iteration	 = 3'd3;
						end

						// LOAD MEMORY IMMEDIATE
						LD_A_N16A: begin
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_PC;
						
							control.read_en = `TRUE;
							next_iteration	 = 3'd3;
						end

						default: begin
							next_iteration		= 3'b0;
						end
					endcase
					
				end else if (iteration == 3'd3) begin
					case(op_code)
					
						default: begin
							next_iteration		= 3'b0;
						end
					endcase
				end
			end
		endcase
	end
	
endmodule: control_path