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
	output logic			fetch_op_code,
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
	
		fetch_op_code 	= `FALSE;
		next_prefix	  	= prefix_CB;
		next_iteration	= iteration;
	
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
				
				if (iteration == 3'b0)
					fetch_op_code 			= `TRUE;
				else begin
					case (op_code)
						// JUMP ABSOLUTE
						JP_N16: begin
							control.alu_op 	 = alu_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_PC_l;

							control.read_en  = `TRUE;
							next_state 		 = s_DECODE;
						end
						JP_Z_N16: begin
							if (flags[3]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;

								control.read_en  = `TRUE;
								next_state 		 = s_DECODE;
							end else begin
								control.alu_dest = dest_PC;
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
							
								control.read_en  = `FALSE;
								next_state 		 = s_DECODE;
							end
						end
						JP_C_N16: begin
							if (flags[0]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;

								control.read_en  = `TRUE;
								next_state 		 = s_DECODE;
							end else begin
								control.alu_dest = dest_PC;
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
							
								control.read_en  = `FALSE;
								next_state 		 = s_DECODE;
							end
						end
						JP_NZ_N16: begin
							if (~flags[3]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;

								control.read_en  = `TRUE;
								next_state 		 = s_DECODE;
							end else begin
								control.alu_dest = dest_PC;
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
							
								control.read_en  = `FALSE;
								next_state 		 = s_DECODE;
							end
						end
						JP_NC_N16: begin
							if (~flags[0]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;

								control.read_en  = `TRUE;
								next_state 		 = s_DECODE;
							end else begin
								control.alu_dest = dest_PC;
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
							
								control.read_en  = `FALSE;
								next_state 		 = s_DECODE;
							end
						end
					endcase
				end
				
				next_state = s_DECODE;
			end
			
			/*	State = DECODE
			*
			*	Writes to Instruction Register to read instruction from. 
			*
			*/
			s_DECODE: begin
				fetch_op_code			= `FALSE;
				control.reg_selA 		= reg_UNK;
				control.reg_selB 		= reg_UNK;
				control.alu_op   		= alu_UNK;
				control.alu_srcA		= src_UNK;
				control.alu_srcB		= src_UNK;	
				control.alu_dest		= dest_NONE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.ld_flags		= `FALSE;
				
				case (op_code)
					// REGISTER LOAD OPERATIONS
					LD_A_D: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_D;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_A_B: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_B;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_A_C: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_C;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_A_E: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_E;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_A_H: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_H;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_A_L: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_L;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_A_A: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_A;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_B_A: begin
						control.reg_selA = reg_B;
						control.reg_selB = reg_A;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_B_B: begin
						control.reg_selA = reg_B;
						control.reg_selB = reg_B;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_B_C: begin
						control.reg_selA = reg_B;
						control.reg_selB = reg_C;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_B_D: begin
						control.reg_selA = reg_B;
						control.reg_selB = reg_D;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_B_E: begin
						control.reg_selA = reg_B;
						control.reg_selB = reg_E;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_B_H: begin
						control.reg_selA = reg_B;
						control.reg_selB = reg_H;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_B_L: begin
						control.reg_selA = reg_B;
						control.reg_selB = reg_L;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_C_A: begin
						control.reg_selA = reg_C;
						control.reg_selB = reg_A;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_C_B: begin
						control.reg_selA = reg_C;
						control.reg_selB = reg_B;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_C_C: begin
						control.reg_selA = reg_C;
						control.reg_selB = reg_C;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_C_D: begin
						control.reg_selA = reg_C;
						control.reg_selB = reg_D;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_C_E: begin
						control.reg_selA = reg_C;
						control.reg_selB = reg_E;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_C_H: begin
						control.reg_selA = reg_C;
						control.reg_selB = reg_H;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_C_L: begin
						control.reg_selA = reg_C;
						control.reg_selB = reg_L;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_D_A: begin
						control.reg_selA = reg_D;
						control.reg_selB = reg_A;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_D_B: begin
						control.reg_selA = reg_D;
						control.reg_selB = reg_B;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_D_C: begin
						control.reg_selA = reg_D;
						control.reg_selB = reg_C;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_D_D: begin
						control.reg_selA = reg_D;
						control.reg_selB = reg_D;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_D_E: begin
						control.reg_selA = reg_D;
						control.reg_selB = reg_E;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_D_H: begin
						control.reg_selA = reg_D;
						control.reg_selB = reg_H;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_D_L: begin
						control.reg_selA = reg_D;
						control.reg_selB = reg_L;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_E_A: begin
						control.reg_selA = reg_E;
						control.reg_selB = reg_A;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_E_B: begin
						control.reg_selA = reg_E;
						control.reg_selB = reg_B;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_E_C: begin
						control.reg_selA = reg_E;
						control.reg_selB = reg_C;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_E_D: begin
						control.reg_selA = reg_E;
						control.reg_selB = reg_D;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_E_E: begin
						control.reg_selA = reg_E;
						control.reg_selB = reg_E;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_E_H: begin
						control.reg_selA = reg_E;
						control.reg_selB = reg_H;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_E_L: begin
						control.reg_selA = reg_E;
						control.reg_selB = reg_L;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_H_A: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_A;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_H_B: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_B;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_H_C: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_C;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_H_D: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_D;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_H_E: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_E;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_H_H: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_H;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_H_L: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_L_A: begin
						control.reg_selA = reg_L;
						control.reg_selB = reg_A;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_L_B: begin
						control.reg_selA = reg_L;
						control.reg_selB = reg_B;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_L_C: begin
						control.reg_selA = reg_L;
						control.reg_selB = reg_C;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_L_D: begin
						control.reg_selA = reg_L;
						control.reg_selB = reg_D;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_L_E: begin
						control.reg_selA = reg_L;
						control.reg_selB = reg_E;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_L_H: begin
						control.reg_selA = reg_L;
						control.reg_selB = reg_H;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_L_L: begin
						control.reg_selA = reg_L;
						control.reg_selB = reg_L;
						control.alu_op   = alu_B;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					
					
					// LOAD REGISTER IMMEDIATE
					LD_A_N8: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_EXECUTE;
					end
					LD_B_N8: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_EXECUTE;
					end
					LD_C_N8: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_EXECUTE;
					end
					LD_D_N8: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_EXECUTE;
					end
					LD_E_N8: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_EXECUTE;
					end
					LD_H_N8: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_EXECUTE;
					end
					LD_L_N8: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_EXECUTE;
					end
					
					// LOAD MEMORY
					LD_BCA_A: begin
						control.reg_selA = reg_A;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					LD_DEA_A: begin
						control.reg_selA = reg_A;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					LD_HLA_A: begin
						control.reg_selA = reg_A;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					LD_HLP_A: begin
						control.reg_selA = reg_A;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					LD_HLN_A: begin
						control.reg_selA = reg_A;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					LD_HLA_B: begin
						control.reg_selA = reg_B;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					LD_HLA_C: begin
						control.reg_selA = reg_C;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					LD_HLA_D: begin
						control.reg_selA = reg_D;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					LD_HLA_E: begin
						control.reg_selA = reg_E;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					LD_HLA_H: begin
						control.reg_selA = reg_H;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					LD_HLA_L: begin
						control.reg_selA = reg_L;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_MEMD;
						control.alu_op	 = alu_B;
						next_state		 = s_EXECUTE;
					end
					
					// READ MEMORY
					LD_A_BCA: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_B;
						control.reg_selB = reg_C;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
					end
					LD_A_DEA: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_D;
						control.reg_selB = reg_E;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
					end
					LD_A_HLA: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
					end
					LD_A_HLP: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
					end
					LD_A_HLN: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
					end
					LD_B_HLA: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
					end
					LD_C_HLA: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
					end
					LD_D_HLA: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
					end
					LD_E_HLA: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
					end
					LD_H_HLA: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
					end
					LD_L_HLA: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_EXECUTE;
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
						next_state		 = s_FETCH;
					end
					ADD_A_B: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_B;
						control.alu_op	 = alu_ADD;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					ADD_A_C: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_C;
						control.alu_op	 = alu_ADD;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					ADD_A_D: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_D;
						control.alu_op	 = alu_ADD;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					ADD_A_E: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_E;
						control.alu_op	 = alu_ADD;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					ADD_A_H: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_H;
						control.alu_op	 = alu_ADD;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					ADD_A_L: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_ADD;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
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
						next_state		 = s_FETCH;
					end
					ADC_A_B: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_B;
						control.alu_op	 = alu_ADC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					ADC_A_C: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_C;
						control.alu_op	 = alu_ADC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					ADC_A_D: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_D;
						control.alu_op	 = alu_ADC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					ADC_A_E: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_E;
						control.alu_op	 = alu_ADC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					ADC_A_H: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_H;
						control.alu_op	 = alu_ADC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					ADC_A_L: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_ADC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
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
						next_state		 = s_FETCH;
					end
					SUB_A_B: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_B;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					SUB_A_C: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_C;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					SUB_A_D: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_D;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					SUB_A_E: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_E;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					SUB_A_H: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_H;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					SUB_A_L: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
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
						next_state		 = s_FETCH;
					end
					SBC_A_B: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_B;
						control.alu_op	 = alu_SBC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					SBC_A_C: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_C;
						control.alu_op	 = alu_SBC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					SBC_A_D: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_D;
						control.alu_op	 = alu_SBC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					SBC_A_E: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_E;
						control.alu_op	 = alu_SBC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					SBC_A_H: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_H;
						control.alu_op	 = alu_SBC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					SBC_A_L: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_SBC;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
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
						next_state		 = s_FETCH;
					end
					AND_A_B: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_B;
						control.alu_op	 = alu_AND;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					AND_A_C: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_C;
						control.alu_op	 = alu_AND;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					AND_A_D: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_D;
						control.alu_op	 = alu_AND;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					AND_A_E: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_E;
						control.alu_op	 = alu_AND;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					AND_A_H: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_H;
						control.alu_op	 = alu_AND;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					AND_A_L: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_AND;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
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
						next_state		 = s_FETCH;
					end
					OR_A_B: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_B;
						control.alu_op	 = alu_OR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					OR_A_C: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_C;
						control.alu_op	 = alu_OR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					OR_A_D: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_D;
						control.alu_op	 = alu_OR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					OR_A_E: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_E;
						control.alu_op	 = alu_OR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					OR_A_H: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_H;
						control.alu_op	 = alu_OR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					OR_A_L: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_OR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
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
						next_state		 = s_FETCH;
					end
					XOR_A_B: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_B;
						control.alu_op	 = alu_XOR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					XOR_A_C: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_C;
						control.alu_op	 = alu_XOR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					XOR_A_D: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_D;
						control.alu_op	 = alu_XOR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					XOR_A_E: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_E;
						control.alu_op	 = alu_XOR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					XOR_A_H: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_H;
						control.alu_op	 = alu_XOR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					XOR_A_L: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_XOR;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
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
						next_state		 = s_FETCH;
					end
					CP_A_B: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_B;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_NONE;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					CP_A_C: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_C;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_NONE;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					CP_A_D: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_D;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_NONE;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					CP_A_E: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_E;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_NONE;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					CP_A_H: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_H;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_NONE;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					CP_A_L: begin
						control.reg_selA = reg_A;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_SUB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_NONE;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					
					// INCREMENT OPERATIONS
					INC_A: begin
						control.reg_selA = reg_A;
						control.alu_op	 = alu_INC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					INC_B: begin
						control.reg_selA = reg_B;
						control.alu_op	 = alu_INC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					INC_C: begin
						control.reg_selA = reg_C;
						control.alu_op	 = alu_INC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					INC_D: begin
						control.reg_selA = reg_D;
						control.alu_op	 = alu_INC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					INC_E: begin
						control.reg_selA = reg_E;
						control.alu_op	 = alu_INC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					INC_H: begin
						control.reg_selA = reg_H;
						control.alu_op	 = alu_INC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					INC_L: begin
						control.reg_selA = reg_L;
						control.alu_op	 = alu_INC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					
					// DECREMENT OPERATIONS
					DEC_A: begin
						control.reg_selA = reg_A;
						control.alu_op	 = alu_DEC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					DEC_B: begin
						control.reg_selA = reg_B;
						control.alu_op	 = alu_DEC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					DEC_C: begin
						control.reg_selA = reg_C;
						control.alu_op	 = alu_DEC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					DEC_D: begin
						control.reg_selA = reg_D;
						control.alu_op	 = alu_DEC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					DEC_E: begin
						control.reg_selA = reg_E;
						control.alu_op	 = alu_DEC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					DEC_H: begin
						control.reg_selA = reg_H;
						control.alu_op	 = alu_DEC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					DEC_L: begin
						control.reg_selA = reg_L;
						control.alu_op	 = alu_DEC;
						control.alu_srcB = src_REGA;
						control.alu_dest = dest_REG;
						control.ld_flags = `TRUE;
						next_state		 = s_FETCH;
					end
					
					// INCREMENT 16-BIT
					INC_BC: begin
						control.reg_selA = reg_B;
						control.reg_selB = reg_C;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REGA;
						next_state		 = s_EXECUTE;
					end
					INC_DE: begin
						control.reg_selA = reg_D;
						control.reg_selB = reg_E;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REGA;
						next_state		 = s_EXECUTE;
					end
					INC_HL: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REGA;
						next_state		 = s_EXECUTE;
					end
					INC_SP: begin
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_SP_l;
						control.alu_srcB = src_SP_h;
						control.alu_dest = dest_SP;
						next_state		 = s_EXECUTE;
					end

					// DECREMENT 16-BIT
					DEC_BC: begin
						control.reg_selA = reg_B;
						control.reg_selB = reg_C;
						control.alu_op	 = alu_DECL;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REGA;
						next_state		 = s_EXECUTE;
					end
					DEC_DE: begin
						control.reg_selA = reg_D;
						control.reg_selB = reg_E;
						control.alu_op	 = alu_DECL;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REGA;
						next_state		 = s_EXECUTE;
					end
					DEC_HL: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_DECL;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_REGA;
						next_state		 = s_EXECUTE;
					end
					DEC_SP: begin
						control.alu_op	 = alu_DECL;
						control.alu_srcA = src_SP_l;
						control.alu_srcB = src_SP_h;
						control.alu_dest = dest_SP;
						next_state		 = s_EXECUTE;
					end
					
					// JUMPS ABSOLUTE
					JP_HLA: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_dest = dest_PC;
						next_state		 = s_FETCH;
					end
					JP_N16: begin
						if (iteration == 3'b0) begin 
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
							next_state		 = s_EXECUTE;
						end else begin
							control.alu_op 	 = alu_B;
							control.alu_srcB = src_MEMD;
							control.alu_dest = dest_PC_h;
							next_state 		 = s_FETCH;
							next_iteration	 = 3'b0;
						end
					end
					JP_Z_N16: begin
						if (iteration == 3'b0) begin 
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
							next_state		 = s_EXECUTE;
						end else begin
							if (flags[3]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_h;
							end
							next_state 		 = s_FETCH;
							next_iteration	 = 3'b0;
						end
					end
					JP_C_N16: begin
						if (iteration == 3'b0) begin 
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
							next_state		 = s_EXECUTE;
						end else begin
							if (flags[0]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_h;
							end
							next_state 		 = s_FETCH;
							next_iteration	 = 3'b0;
						end
					end
					JP_NZ_N16: begin
						if (iteration == 3'b0) begin 
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
							next_state		 = s_EXECUTE;
						end else begin
							if (~flags[3]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_h;
							end
							next_state 		 = s_FETCH;
							next_iteration	 = 3'b0;
						end
					end
					JP_NC_N16: begin
						if (iteration == 3'b0) begin 
							control.alu_op	 = alu_AB;
							control.alu_srcA = src_PC_h;
							control.alu_srcB = src_PC_l;
							control.alu_dest = dest_MEMA;
							next_state		 = s_EXECUTE;
						end else begin
							if (~flags[0]) begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_h;
							end
							next_state 		 = s_FETCH;
							next_iteration	 = 3'b0;
						end
					end

					
					PREFIX: begin
						next_state = s_FETCH;
						next_prefix = `TRUE;
					end
					STOP: begin
						next_state = s_DECODE;
						$stop;
					end
					NOP: begin
						next_state = s_FETCH;
					end
					
					default: begin
						next_state = s_EXECUTE;
					end
				endcase
				
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
				
				case (op_code)
					// LOAD REGISTER IMMEDIATE
					LD_A_N8: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;

						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					LD_B_N8: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						
						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					LD_C_N8: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;

						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					LD_D_N8: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
					
						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					LD_E_N8: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
					
						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					LD_H_N8: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
					
						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					LD_L_N8: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
					
						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					
					// LOAD MEMORY
					LD_BCA_A: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_B;
						control.reg_selB = reg_C;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end
					LD_DEA_A: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_D;
						control.reg_selB = reg_E;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end
					LD_HLA_A: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end
					LD_HLP_A: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end
					LD_HLN_A: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end
					LD_HLA_B: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end
					LD_HLA_C: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end
					LD_HLA_D: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end
					LD_HLA_E: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end
					LD_HLA_H: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end
					LD_HLA_L: begin
						control.alu_dest = dest_MEMA;
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_AB;
						next_state		 = s_WRITE;
					end					
					
					// READ MEMORY
					LD_A_BCA: begin
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					LD_A_DEA: begin
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					LD_A_HLA: begin
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					LD_A_HLP: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_INCL;
						control.alu_dest = dest_REGA;
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					LD_A_HLN: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_DECL;
						control.alu_dest = dest_REGA;
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					LD_B_HLA: begin
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					LD_C_HLA: begin
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					LD_D_HLA: begin
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					LD_E_HLA: begin
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					LD_H_HLA: begin
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					LD_L_HLA: begin
						control.read_en = `TRUE;
						next_state		 = s_WRITE;
					end
					
					// JUMP ABSOLUTE
					JP_N16: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
					
						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					JP_Z_N16: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
					
						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					JP_C_N16: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
					
						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					JP_NZ_N16: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
					
						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end
					JP_NC_N16: begin
						control.alu_dest = dest_PC;
						control.alu_op	 = alu_INCL;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
					
						control.read_en  = `TRUE;
						next_state 		 = s_WRITE;
					end

					
					default: begin
						next_state = s_WRITE;
					end
				endcase
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
				
				case (op_code)
					// LOAD REGISTER IMMEDIATE
					LD_A_N8: begin
						control.alu_op 	 = alu_B;
						control.reg_selA = reg_A;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_B_N8: begin
						control.alu_op 	 = alu_B;
						control.reg_selA = reg_B;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_C_N8: begin
						control.alu_op 	 = alu_B;
						control.reg_selA = reg_C;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_D_N8: begin
						control.alu_op 	 = alu_B;
						control.reg_selA = reg_D;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_E_N8: begin
						control.alu_op 	 = alu_B;
						control.reg_selA = reg_E;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_H_N8: begin
						control.alu_op 	 = alu_B;
						control.reg_selA = reg_H;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					LD_L_N8: begin
						control.alu_op 	 = alu_B;
						control.reg_selA = reg_L;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						next_state 		 = s_FETCH;
					end
					/*
					// LOAD MEMORY
					LD_BCA_A: begin
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end
					LD_DEA_A: begin
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end
					LD_HLA_A: begin
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end
					LD_HLP_A: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_INCL;
						control.alu_dest = dest_REGA;
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end
					LD_HLN_A: begin
						control.reg_selA = reg_H;
						control.reg_selB = reg_L;
						control.alu_srcA = src_REGA;
						control.alu_srcB = src_REGB;
						control.alu_op	 = alu_DECL;
						control.alu_dest = dest_REGA;
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end
					LD_HLA_B: begin
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end
					LD_HLA_C: begin
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end
					LD_HLA_D: begin
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end
					LD_HLA_E: begin
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end
					LD_HLA_H: begin
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end*/
					LD_HLA_L: begin
						control.write_en = `TRUE;
						next_state		 = s_FETCH;
					end
					
					// READ MEMORY
					LD_A_BCA: begin
						control.reg_selA = reg_A;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					LD_A_DEA: begin
						control.reg_selA = reg_A;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					LD_A_HLA: begin
						control.reg_selA = reg_A;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					LD_A_HLP: begin
						control.reg_selA = reg_A;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					LD_A_HLN: begin
						control.reg_selA = reg_A;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					LD_B_HLA: begin
						control.reg_selA = reg_B;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					LD_C_HLA: begin
						control.reg_selA = reg_C;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					LD_D_HLA: begin
						control.reg_selA = reg_D;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					LD_E_HLA: begin
						control.reg_selA = reg_E;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					LD_H_HLA: begin
						control.reg_selA = reg_H;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					LD_L_HLA: begin
						control.reg_selA = reg_L;
						control.alu_srcB = src_MEMD;
						control.alu_dest = dest_REG;
						control.alu_op	 = alu_B;
						next_state		 = s_FETCH;
					end
					
					// JUMP ABSOLUTE
					JP_N16: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_FETCH;
						next_iteration	 = 3'b1;
					end
					JP_Z_N16: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_FETCH;
						next_iteration	 = 3'b1;
					end
					JP_NZ_N16: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_FETCH;
						next_iteration	 = 3'b1;
					end
					JP_C_N16: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_FETCH;
						next_iteration	 = 3'b1;
					end
					JP_NC_N16: begin
						control.alu_op	 = alu_AB;
						control.alu_srcA = src_PC_h;
						control.alu_srcB = src_PC_l;
						control.alu_dest = dest_MEMA;
						next_state		 = s_FETCH;
						next_iteration	 = 3'b1;
					end
					default: begin
						next_state = s_FETCH;
					end
				endcase
			end
		endcase
	
	end
	
endmodule: control_path