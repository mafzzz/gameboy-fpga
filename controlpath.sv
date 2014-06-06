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
						LD_A_N8, LD_B_N8, LD_C_N8, LD_D_N8, LD_E_N8, LD_H_N8, LD_L_N8:
						begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						
						LD_BC_N16, LD_DE_N16, LD_HL_N16, LD_SP_N16: 
						begin
							if (iteration == 3'b0) begin
								control.alu_op	 = alu_AB;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_MEMA;
							end else begin
								control.alu_dest = dest_PC;
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
						
								control.read_en  = `TRUE;
							end
						end

						// LOAD MEMORY
						LD_BCA_A, LD_DEA_A, LD_HLA_A, LD_HLP_A, LD_HLN_A: 
						begin
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
						LD_A_HLA, LD_A_HLP, LD_A_HLN, LD_B_HLA, LD_C_HLA, LD_D_HLA, LD_E_HLA, LD_H_HLA, LD_L_HLA:
						begin
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
						
						ADD_HL_BC: begin
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.reg_selA = reg_L;
							control.reg_selB = reg_C;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_HL_DE: begin
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.reg_selA = reg_L;
							control.reg_selB = reg_E;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_HL_HL: begin
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.reg_selA = reg_L;
							control.reg_selB = reg_L;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_HL_SP: begin
							control.alu_op	 = alu_ADD;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_SP_l;
							control.reg_selA = reg_L;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
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
							control.alu_srcA = src_SP_h;
							control.alu_srcB = src_SP_l;
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
							control.alu_srcA = src_SP_h;
							control.alu_srcB = src_SP_l;
							control.alu_dest = dest_SP;
						end
						
						// INCREMENT/DECREMENT MEMORY
						INC_HLA, DEC_HLA: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_dest = dest_MEMA;
						end
												
						// NO PREFIX ROTATES/SHIFTS
						RLCA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_RLCA;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						RLA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_RLA;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						RRCA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_RRCA;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						RRA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_RRA;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end

						// MISC. ALU OPERATIONS
						DAA: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_DAA;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						SCF: begin
							control.alu_op	 = alu_SCF;
							control.ld_flags = `TRUE;
						end
						CPL: begin
							control.reg_selA = reg_A;
							control.alu_op	 = alu_CPL;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						CCF: begin
							control.alu_op	 = alu_CCF;
							control.ld_flags = `TRUE;
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
						
						// JUMP RELATIVE
						JR_N8, JR_Z_N8, JR_NZ_N8, JR_C_N8, JR_NC_N8: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end

						// STACK OPERATIONS
						PUSH_AF: begin
							if (iteration == 3'b0 || iteration == 3'd2) begin
								control.alu_dest = dest_SP;
								control.alu_op	 = alu_DECL;
								control.alu_srcA = src_SP_h;
								control.alu_srcB = src_SP_l;
							end else begin
								control.alu_op	 = alu_B;
								control.alu_srcB = src_FLAGS;
								control.alu_dest = dest_MEMD;
							end
						end
						PUSH_BC: begin
							if (iteration == 3'b0 || iteration == 3'd2) begin
								control.alu_dest = dest_SP;
								control.alu_op	 = alu_DECL;
								control.alu_srcA = src_SP_h;
								control.alu_srcB = src_SP_l;
							end else begin
								control.alu_op	 = alu_B;
								control.reg_selA = reg_C;
								control.alu_srcB = src_REGA;
								control.alu_dest = dest_MEMD;
							end
						end
						PUSH_DE: begin
							if (iteration == 3'b0 || iteration == 3'd2) begin
								control.alu_dest = dest_SP;
								control.alu_op	 = alu_DECL;
								control.alu_srcA = src_SP_h;
								control.alu_srcB = src_SP_l;
							end else begin
								control.alu_op	 = alu_B;
								control.reg_selA = reg_E;
								control.alu_srcB = src_REGA;
								control.alu_dest = dest_MEMD;
							end
						end
						PUSH_HL: begin
							if (iteration == 3'b0 || iteration == 3'd2) begin
								control.alu_dest = dest_SP;
								control.alu_op	 = alu_DECL;
								control.alu_srcA = src_SP_h;
								control.alu_srcB = src_SP_l;
							end else begin
								control.alu_op	 = alu_B;
								control.reg_selA = reg_L;
								control.alu_srcB = src_REGA;
								control.alu_dest = dest_MEMD;
							end
						end
						
						POP_AF, POP_BC, POP_DE, POP_HL:
						begin
							if (iteration == 3'b0) begin
								control.alu_op		= alu_AB;
								control.alu_srcA	= src_SP_h;
								control.alu_srcB	= src_SP_l;
								control.alu_dest	= dest_MEMA;
							end else begin
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_SP_h;
								control.alu_srcB = src_SP_l;
								control.alu_dest = dest_SP;
								control.read_en = `TRUE;
							end
						end
												
						HALT: begin
							next_state = s_EXECUTE;
							
							// For simulation purposes
							$display("State: %s 	Iter: %d	| 	PC: %h 	IR: HALT	(0x%h)		SP:	%h	|	Reset: %b \n\
				Registers {A B C D E H L} : {%h %h %h %h %h %h %h}   MAR: %h		MDR: %h	\n\
				Condition codes {Z N H C} : {%b %b %b %b}\n\n", 
							DUT.cp.curr_state.name, DUT.cp.iteration, DUT.PC, DUT.IR, DUT.SP, rst,
							DUT.regA, DUT.regB, DUT.regC, DUT.regD, DUT.regE, DUT.regH, DUT.regL, DUT.MAR, DUT.MDR,
							DUT.regF[3], DUT.regF[2], DUT.regF[1], DUT.regF[0]); 
							$stop;
						end
						STOP: begin
							next_state = s_EXECUTE;
							
							// For simulation purposes
							$display("State: %s 	Iter: %d	| 	PC: %h 	IR: STOP	(0x%h)		SP:	%h	|	Reset: %b \n\
				Registers {A B C D E H L} : {%h %h %h %h %h %h %h}   MAR: %h		MDR: %h	\n\
				Condition codes {Z N H C} : {%b %b %b %b}\n\n", 
							DUT.cp.curr_state.name, DUT.cp.iteration, DUT.PC, DUT.IR, DUT.SP, rst,
							DUT.regA, DUT.regB, DUT.regC, DUT.regD, DUT.regE, DUT.regH, DUT.regL, DUT.MAR, DUT.MDR,
							DUT.regF[3], DUT.regF[2], DUT.regF[1], DUT.regF[0]); 
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
						LD_BC_N16: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_C;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						LD_DE_N16: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_E;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						LD_HL_N16: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_L;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						LD_SP_N16: begin
							control.alu_op 	 = alu_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_SP_l;
						end
						
						// LOAD MEMORY
						LD_BCA_A, LD_DEA_A, LD_HLA_A, LD_HLA_B, LD_HLA_C, LD_HLA_D, LD_HLA_E, LD_HLA_H, LD_HLA_L:
						begin
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
						
						// READ MEMORY
						LD_A_BCA, LD_A_DEA, LD_A_HLA, LD_A_HLP, LD_A_HLN:
						begin
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
						
						// MEMORY IMMEDIATE
						LD_N16A_A, LD_A_N16A: 
						begin
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

						INC_HLA: begin
							control.alu_op	 = alu_INC;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_MEMD;
							control.ld_flags = `TRUE;
						end
						
						DEC_HLA: begin
							control.alu_op	 = alu_DEC;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_MEMD;
							control.ld_flags = `TRUE;
						end
						
						// JUMP ABSOLUTE
						JP_N16, JP_Z_N16, JP_NZ_N16, JP_C_N16, JP_NC_N16: begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
						end
						
						// JUMP RELATIVE
						JR_N8: begin
							control.alu_op	 = alu_ADS;
							control.alu_srcA = src_PC_l;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_PC_l;
						end
						JR_Z_N8: begin
							if (flags[3]) begin
								control.alu_op	 = alu_ADS;
								control.alu_srcA = src_PC_l;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;
							end else begin
								// Do Nothing
							end
						end
						JR_NZ_N8: begin
							if (~flags[3]) begin
								control.alu_op	 = alu_ADS;
								control.alu_srcA = src_PC_l;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;
							end else begin
								// Do Nothing
							end
						end
						JR_C_N8: begin
							if (flags[0]) begin
								control.alu_op	 = alu_ADS;
								control.alu_srcA = src_PC_l;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;
							end else begin
								// Do Nothing
							end
						end
						JR_NC_N8: begin
							if (~flags[0]) begin
								control.alu_op	 = alu_ADS;
								control.alu_srcA = src_PC_l;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;
							end else begin
								// Do Nothing
							end
						end
						
						// STACK OPERATIONS
						PUSH_AF: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_A;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
						end
						PUSH_BC: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_B;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
						end
						PUSH_DE: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_D;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
						end
						PUSH_HL: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_H;
							control.alu_srcB = src_REGA;
							control.alu_dest = dest_MEMD;
						end
						
						POP_AF: begin
							control.alu_op	 = alu_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_FLAGS;
						end
						POP_BC: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_C;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						POP_DE: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_E;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
						end
						POP_HL: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_L;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
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
						LD_A_N8, LD_B_N8, LD_C_N8, LD_D_N8, LD_E_N8, LD_H_N8, LD_L_N8, LD_BC_N16, LD_DE_N16, LD_HL_N16, LD_SP_N16: 
						begin
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
						LD_HLA_A, LD_HLP_A, LD_HLN_A, LD_HLA_L, LD_HLA_B, LD_HLA_C, LD_HLA_D, LD_HLA_E, LD_HLA_H: 
						begin
							control.alu_dest = dest_MEMA;
							control.reg_selA = reg_H;
							control.reg_selB = reg_L;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.alu_op	 = alu_AB;
							next_iteration	 = 3'b1;
						end

						// READ MEMORY
						LD_A_BCA, LD_A_DEA, LD_A_HLA, LD_B_HLA, LD_C_HLA, LD_D_HLA, LD_E_HLA, LD_H_HLA, LD_L_HLA, LD_HLA_N8:
						begin
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
						
						// MEMORY IMMEDIATE
						LD_N16A_A, LD_A_N16A: begin
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_PC;
							
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end
						
						// ARITHMATIC OPERATIONS
						ADD_A_HLA, ADC_A_HLA, SUB_A_HLA, SBC_A_HLA, AND_A_HLA, OR_A_HLA, XOR_A_HLA, CP_A_HLA,
							ADD_A_N8, ADC_A_N8, SUB_A_N8, SBC_A_N8, AND_A_N8, OR_A_N8, XOR_A_N8, CP_A_N8: 
						begin
							control.read_en	 = `TRUE;
							next_iteration	 = 3'b1;
						end

						ADD_HL_BC: begin
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.reg_selA = reg_H;
							control.reg_selB = reg_B;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_HL_DE: begin
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.reg_selA = reg_H;
							control.reg_selB = reg_D;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_HL_HL: begin
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_REGB;
							control.reg_selA = reg_H;
							control.reg_selB = reg_H;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						ADD_HL_SP: begin
							control.alu_op	 = alu_ADC;
							control.alu_srcA = src_REGA;
							control.alu_srcB = src_SP_h;
							control.reg_selA = reg_H;
							control.alu_dest = dest_REG;
							control.ld_flags = `TRUE;
						end
						
						// INCREMENT/DECREMENT MEMORY
						INC_HLA, DEC_HLA: begin
							control.read_en	 = `TRUE;
							next_iteration 	 = 3'b1;
						end
						
						// JUMP ABSOLUTE
						JP_N16, JP_Z_N16, JP_C_N16, JP_NZ_N16, JP_NC_N16: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.read_en  = `TRUE;
							next_iteration		 = 3'b1;
						end

						// JUMP RELATIVE
						JR_N8, JR_Z_N8, JR_NZ_N8, JR_C_N8, JR_NC_N8:
						begin
							control.read_en	= `TRUE;
							next_iteration	= 3'b1;
						end

						// STACK OPERATIONS
						PUSH_AF, PUSH_BC, PUSH_DE, PUSH_HL: 
						begin
							control.alu_op		= alu_AB;
							control.alu_srcA 	= src_SP_h;
							control.alu_srcB 	= src_SP_l;
							control.alu_dest	= dest_MEMA;
							next_iteration	= 3'b1;
						end
						
						POP_AF, POP_BC, POP_DE, POP_HL:
						begin
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_SP_h;
							control.alu_srcB = src_SP_l;
							control.alu_dest = dest_SP;
						
							control.read_en = `TRUE;
							next_iteration	= 3'b1;
						end
						
						PREFIX: begin
							next_prefix = `TRUE;
						end
						
					endcase				
					
				end else if (iteration == 3'd1) begin
				
					case(op_code)
					
						// LOAD 16-BIT IMMEDIATE
						LD_BC_N16, LD_DE_N16, LD_HL_N16, LD_SP_N16: 
						begin
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
							next_iteration	 = 3'd2;
						end

						// MEMORY OPERATIONS
						LD_HLA_N8: begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
						
							control.write_en  = `TRUE;
							next_iteration		 = 3'd2;
						end
					
						// MEMORY IMMEDIATE
						LD_N16A_A, LD_A_N16A: 
						begin
							control.alu_op	 = alu_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_MEMA_l;
							
							control.read_en	 = `TRUE;
							next_iteration	 = 3'd2;
						end
											
						// ARITHMATIC OPERATIONS
						ADD_A_N8, ADC_A_N8, SUB_A_N8, SBC_A_N8, AND_A_N8, OR_A_N8, XOR_A_N8, CP_A_N8: 
						begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							next_iteration	 = 3'b0;
						end
					
						// INCREMENT/DECREMENT MEMORY
						INC_HLA, DEC_HLA: begin
							control.write_en = `TRUE;
							next_iteration 	 = 3'b0;
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
						
						// JUMP RELATIVE
						JR_N8, JR_Z_N8, JR_NZ_N8, JR_C_N8, JR_NC_N8: 
						begin
							control.alu_dest = dest_PC;
							control.alu_op	 = alu_INCL;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;

							next_iteration	 = 3'b0;
						end

						// STACK OPERATIONS
						PUSH_AF, PUSH_BC, PUSH_DE, PUSH_HL: 
						begin
							control.write_en 	= `TRUE;
							next_iteration		= 3'd2;
						end
						
						POP_AF, POP_BC, POP_DE, POP_HL:
						begin
							control.alu_op		= alu_AB;
							control.alu_srcA	= src_SP_h;
							control.alu_srcB	= src_SP_l;
							control.alu_dest	= dest_MEMA;
							next_iteration 		= 3'd2;
						end
						
						default: begin
							next_iteration		= 3'b0;
						end
					endcase
					
				end else if (iteration == 3'd2) begin
				
					case(op_code)
					
						// LOAD 16-BIT IMMEDIATE
						LD_BC_N16: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							next_iteration		= 3'b0;
						end
						LD_DE_N16: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_D;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							next_iteration		= 3'b0;
						end
						LD_HL_N16: begin
							control.alu_op 	 = alu_B;
							control.reg_selA = reg_H;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							next_iteration		= 3'b0;
						end
						LD_SP_N16: begin
							control.alu_op 	 = alu_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_SP_h;
							next_iteration		= 3'b0;
						end

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

						// STACK OPERATIONS
						PUSH_AF, PUSH_BC, PUSH_DE, PUSH_HL: 
						begin
							control.alu_op		= alu_AB;
							control.alu_srcA 	= src_SP_h;
							control.alu_srcB 	= src_SP_l;
							control.alu_dest	= dest_MEMA;
							next_iteration		= 3'd3;
						end
						
						POP_AF: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_A;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							next_iteration	 = 3'b0;
						end
						POP_BC: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							next_iteration	 = 3'b0;
						end
						POP_DE: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_D;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							next_iteration	 = 3'b0;
						end
						POP_HL: begin
							control.alu_op	 = alu_B;
							control.reg_selA = reg_H;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_REG;
							next_iteration	 = 3'b0;
						end
						
						default: begin
							next_iteration		= 3'b0;
						end
					endcase
					
				end else if (iteration == 3'd3) begin
					case(op_code)
					
						// STACK OPERATIONS
						PUSH_AF, PUSH_BC, PUSH_DE, PUSH_HL: 
						begin
							control.write_en 	= `TRUE;
							next_iteration		= 3'd0;
						end
						
						default: begin
							next_iteration		= 3'b0;
						end
					endcase
				end
			end
		endcase
	end
	
endmodule: control_path