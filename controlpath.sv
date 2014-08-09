/**************************************************************************
*	"controlpath.sv"
*	GameBoy SystemVerilog reverse engineering project.
*   Copyright (C) 2014 Sohil Shah
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU Public License as published by
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
	(input logic 			rst,
	input logic				clk,
	
	input op_code_t			op_code,
	input logic [3:0]		flags,
	output control_code_t 	control,
	
	// Interrupt lines
	input logic			vblank_int,
	input logic			lcdc_int,
	input logic			timer_int,
	input logic 		serial_int,
	input logic			joypad_int,
	input logic	[7:0]	int_en,
	output logic		int_clear);
	
	// Whether the current instruction is a CB prefix instruction
	logic				prefix_CB, next_prefix;
	
	// How many iterations of FETCH, DECODE, EXECUTE, WRITE current instruction 
	// 		has gone through
	logic [2:0]			iteration, next_iteration;
	
	// FSM states
	control_state_t		curr_state, next_state;
	
	// Interrupt states
	interrupt_state_t	curr_int, next_int;
	
	// Interrupt master enable flag
	reg 	 			IME;
	logic				enable_interrupts, disable_interrupts;
	
	always_ff @(posedge clk, posedge rst) 
		if (rst) 
			IME <= `TRUE;
		else
			IME <= (enable_interrupts) ? `TRUE : ((disable_interrupts) ? `FALSE : IME);
	
	always_ff @(posedge clk, posedge rst) begin
		// Reset into FETCH state, first instruction iteration, no prefix
		if (rst) begin
			curr_int <= int_NONE;
			curr_state <= s_FETCH;
			iteration <= 3'b0;
			prefix_CB <= `FALSE;
		end
		
		// Next state
		else begin
			curr_int <= next_int;
			iteration <= next_iteration;
			prefix_CB <= next_prefix;
			curr_state <= next_state;
		end
	end

	always_comb begin
		enable_interrupts = `FALSE;
		disable_interrupts = `FALSE;
		
		int_clear = `FALSE;
		
		next_int = curr_int;
		
		control.reg_selA 		= reg_UNK;
		control.reg_selB 		= reg_UNK;
		control.alu_op   		= alu_NOP;
		control.alu_srcA		= src_UNK;
		control.alu_srcB		= src_UNK;	
		control.alu_dest		= dest_NONE;
		control.read_en			= `FALSE;
		control.write_en		= `FALSE;
		control.ld_flags		= `FALSE;
		control.load_op_code 	= `FALSE;
		control.fetch 			= `FALSE;
		control.bit_num			= 3'bx;
		
		// Interrupt servicing
		if (curr_state == s_FETCH && iteration == 3'b0 && IME == `TRUE && 
				((vblank_int & int_en[0]) | (joypad_int & int_en[4]) | (serial_int & int_en[3]) | (lcdc_int & int_en[1]) | (timer_int & int_en[2]))) begin
			
			disable_interrupts = `TRUE;
			int_clear = `TRUE;
			
			if (vblank_int & int_en[0])
				next_int = int_VBLANK;
			else if (lcdc_int & int_en[1])
				next_int = int_LCDC;
			else if (timer_int & int_en[2])
				next_int = int_TIMER;
			else if (serial_int & int_en[3])
				next_int = int_SERIAL;
			else if (joypad_int & int_en[4])
				next_int = int_JOYPAD;
		
			next_prefix	  			= prefix_CB;
			next_iteration			= iteration;
			next_state 				= s_EXECUTE;
		
		end else if (curr_int != int_NONE) begin
			next_prefix	  			= prefix_CB;
			next_iteration			= iteration;
			next_state 				= s_FETCH;

			// PUSH PC ONTO STACK AND JUMP TO ISR ADDRESS
			case (curr_state)
				
				s_EXECUTE: begin
					next_state 		= s_WRITE;
					
					case (iteration) 
						3'd0: begin
							control.alu_srcA	= src_SP_h;
							control.alu_srcB	= src_SP_l;
							control.alu_op		= alu_DECL;
							control.alu_dest	= dest_SP;
						end
						3'd1: begin
							control.alu_srcB	= src_SP_l;
							control.alu_srcA	= src_SP_h;
							control.alu_op		= alu_AB;
							control.alu_dest	= dest_MEMA;
						end
						3'd2: begin
							control.alu_srcA	= src_SP_h;
							control.alu_srcB	= src_SP_l;
							control.alu_op		= alu_DECL;
							control.alu_dest	= dest_SP;
						end
						3'd3: begin
							control.alu_srcB	= src_00;
							control.alu_op		= alu_B;
							control.alu_dest	= dest_PC_h;
							
							control.write_en	= `TRUE;
						end
					endcase
				end
				
				s_WRITE: begin
					next_state		= s_EXECUTE;
					
					case (iteration) 
						3'd0: begin
							control.alu_srcB	= src_PC_h;
							control.alu_op		= alu_B;
							control.alu_dest	= dest_MEMD;
							next_iteration		= 3'd1;
						end
						3'd1: begin
							control.alu_srcB	= src_PC_l;
							control.alu_op		= alu_B;
							control.alu_dest	= dest_MEMD;
							
							next_iteration		= 3'd2;
							control.write_en	= `TRUE;
						end
						3'd2: begin
							control.alu_srcB	= src_SP_l;
							control.alu_srcA	= src_SP_h;
							control.alu_op		= alu_AB;
							control.alu_dest	= dest_MEMA;

							next_iteration		= 3'd3;
						end
						3'd3: begin
							case (curr_int)
								int_VBLANK: control.alu_srcB	= src_40;
								int_LCDC:	control.alu_srcB	= src_48;
								int_TIMER:	control.alu_srcB	= src_50;
								int_SERIAL:	control.alu_srcB	= src_58;
								int_JOYPAD:	control.alu_srcB	= src_60;
								default:	control.alu_srcB	= src_00;
							endcase
							
							next_state			= s_FETCH;
							next_iteration		= 3'd0;
							next_int			= int_NONE;
							control.alu_op		= alu_B;
							control.alu_dest	= dest_PC_l;
						end
					endcase
				end
			
				default: /* Do nothing */;
			endcase
		
		end else if (prefix_CB == `FALSE) begin

			next_prefix	  			= prefix_CB;
			next_iteration			= iteration;

			unique case (curr_state)
			
				/*	State = FETCH
				*
				*	Tells Datapath to retrieve next instruction from memory and increment
				*	the PC if on first iteration. 
				*
				*	Does nothing if not first iteration. 
				*/
				s_FETCH: begin
					
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
				
					next_state				= s_EXECUTE;
					
					if (iteration == 3'b0)
						control.load_op_code	= `TRUE;
					
				end
				
				/*	State = EXECUTE
				*
				*	Executes ALU operation or memory read based on iteration and instruction. 
				*/
				s_EXECUTE: begin

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
							
							LD_SP_HL: begin
								control.reg_selA = reg_L;
								control.alu_srcB = src_REGA;
								control.alu_op	 = alu_B;
								control.alu_dest = dest_SP_l;
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
							// LOAD MEMORY HIGH
							LD_CA_A: begin
								control.reg_selA = reg_A;
								control.alu_srcB = src_REGA;
								control.alu_dest = dest_MEMD;
								control.alu_op	 = alu_B;
							end
							LDH_N8A_A: begin
								if (iteration == 3'b0) begin
									control.alu_op	 = alu_AB;
									control.alu_srcA = src_PC_h;
									control.alu_srcB = src_PC_l;
									control.alu_dest = dest_MEMA;
								end else if (iteration == 3'd2) begin
									control.reg_selA = reg_A;
									control.alu_srcB = src_REGA;
									control.alu_dest = dest_MEMD;
									control.alu_op	 = alu_B;						
								end
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
							
							// READ MEMORY HIGH
							LD_A_CA: begin
								control.alu_dest = dest_MEMAH;
								control.reg_selA = reg_C;
								control.alu_srcB = src_REGA;
								control.alu_op	 = alu_B;
							end
							LDH_A_N8A: begin
								if (iteration == 3'b0) begin
									control.alu_op	 = alu_AB;
									control.alu_srcA = src_PC_h;
									control.alu_srcB = src_PC_l;
									control.alu_dest = dest_MEMA;
								end else if (iteration == 3'd2) begin
									control.read_en	 = `TRUE;				
								end
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
							
							// LOAD SP
							LD_N16A_SP: begin
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
									control.alu_srcA = src_MEMA;
									control.alu_srcB = src_MEMA;
									control.alu_dest = dest_MEMA;	

									control.write_en = `TRUE;								
								end else if (iteration == 3'd4) begin
									control.alu_op	 = alu_INCL;
									control.alu_srcA = src_PC_h;
									control.alu_srcB = src_PC_l;
									control.alu_dest = dest_PC;
									control.write_en = `TRUE;
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
							
							// ADD SP
							ADD_SP_N8: begin
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
							
							// SUBROUTINE CALLS
							CALL_N16: begin
							
								if (iteration == 3'b0) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_PC_h;
									control.alu_srcB	= src_PC_l;
									control.alu_dest	= dest_PC;
								end else if (iteration == 3'd2) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd3) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd4) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_PC_h;
									control.alu_srcB	= src_PC_l;
									control.alu_dest	= dest_MEMA;
									
									control.write_en 	= `TRUE;
								end else if (iteration == 3'd5) begin
									control.alu_op		= alu_B;
									control.alu_srcB	= src_MEMD;
									control.alu_dest	= dest_PC_h;
								
									control.read_en		= `TRUE;
								end
							
							end
							CALL_Z_N16: begin
							
								if (iteration == 3'b0) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_PC_h;
									control.alu_srcB	= src_PC_l;
									control.alu_dest	= dest_PC;
								end else if (iteration == 3'd2 && flags[3]) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd3) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd4) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_PC_h;
									control.alu_srcB	= src_PC_l;
									control.alu_dest	= dest_MEMA;
									
									control.write_en 	= `TRUE;
								end else if (iteration == 3'd5) begin
									control.alu_op		= alu_B;
									control.alu_srcB	= src_MEMD;
									control.alu_dest	= dest_PC_h;
								
									control.read_en		= `TRUE;
								end
							
							end
							CALL_NZ_N16: begin
							
								if (iteration == 3'b0) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_PC_h;
									control.alu_srcB	= src_PC_l;
									control.alu_dest	= dest_PC;
								end else if (iteration == 3'd2 && ~flags[3]) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd3) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd4) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_PC_h;
									control.alu_srcB	= src_PC_l;
									control.alu_dest	= dest_MEMA;
									
									control.write_en 	= `TRUE;
								end else if (iteration == 3'd5) begin
									control.alu_op		= alu_B;
									control.alu_srcB	= src_MEMD;
									control.alu_dest	= dest_PC_h;
								
									control.read_en		= `TRUE;
								end
							
							end
							CALL_C_N16: begin
							
								if (iteration == 3'b0) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_PC_h;
									control.alu_srcB	= src_PC_l;
									control.alu_dest	= dest_PC;
								end else if (iteration == 3'd2 && flags[0]) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd3) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd4) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_PC_h;
									control.alu_srcB	= src_PC_l;
									control.alu_dest	= dest_MEMA;
									
									control.write_en 	= `TRUE;
								end else if (iteration == 3'd5) begin
									control.alu_op		= alu_B;
									control.alu_srcB	= src_MEMD;
									control.alu_dest	= dest_PC_h;
								
									control.read_en		= `TRUE;
								end
							
							end
							CALL_NC_N16: begin
							
								if (iteration == 3'b0) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_PC_h;
									control.alu_srcB	= src_PC_l;
									control.alu_dest	= dest_PC;
								end else if (iteration == 3'd2 && ~flags[0]) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd3) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd4) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_PC_h;
									control.alu_srcB	= src_PC_l;
									control.alu_dest	= dest_MEMA;
									
									control.write_en 	= `TRUE;
								end else if (iteration == 3'd5) begin
									control.alu_op		= alu_B;
									control.alu_srcB	= src_MEMD;
									control.alu_dest	= dest_PC_h;
								
									control.read_en		= `TRUE;
								end
							
							end

							// SUBROUTINE RETURNS
							RET: begin
								if (iteration == 3'b0) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd2) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;

									control.read_en 	= `TRUE;
								end
							end
							RET_Z: begin
								if (iteration == 3'b0) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd2) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;

									control.read_en 	= `TRUE;
								end
							end
							RET_NZ: begin
								if (iteration == 3'b0) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd2) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;

									control.read_en 	= `TRUE;
								end
							end
							RET_C: begin
								if (iteration == 3'b0) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd2) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;

									control.read_en 	= `TRUE;
								end
							end
							RET_NC: begin
								if (iteration == 3'b0) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd2) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;

									control.read_en 	= `TRUE;
								end
							end
							RETI: begin
								if (iteration == 3'b0) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd2) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;

									control.read_en 	= `TRUE;
								end
							end

							// RESETS
							RST_0, RST_8, RST_10, RST_18, RST_20, RST_28, RST_30, RST_38: begin
								if (iteration == 3'b0) begin
									control.alu_dest = dest_SP;
									control.alu_op	 = alu_DECL;
									control.alu_srcA = src_SP_h;
									control.alu_srcB = src_SP_l;
								end else if (iteration == 3'd2) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
								end else if (iteration == 3'd3) begin
									control.alu_op		= alu_B;
									control.alu_srcB	= src_00;
									control.alu_dest	= dest_PC_h;
									control.write_en	= `TRUE;
								end
							end
							
							EI: begin
								enable_interrupts 	= `TRUE;
							end
							DI: begin
								disable_interrupts 	= `TRUE;
							end
							
							HALT: begin
								next_state = s_WRITE;
								
								`ifndef synthesis
								// For simulation purposes
								$display("********************************************");
								$display("State: %s			Iter: %d	| 	PC: %h 	IR: HALT	(0x%h)		SP: %h	|Reset: %b \n	Registers {A B C D E H L} : {%h %h %h %h %h %h %h}   MAR: %h		MDR: %h	\n	Condition codes {Z N H C} : {%b %b %b %b}\n\n", 
								DUT.dp.cp.curr_state.name, DUT.dp.cp.iteration, DUT.dp.PC, DUT.dp.IR, DUT.dp.SP, rst,
								DUT.dp.regA, DUT.dp.regB, DUT.dp.regC, DUT.dp.regD, DUT.dp.regE, DUT.dp.regH, DUT.dp.regL, DUT.dp.MAR, DUT.dp.MDR,
								DUT.dp.regF[3], DUT.dp.regF[2], DUT.dp.regF[1], DUT.dp.regF[0]); 
								$display("********************************************\n");
								$stop;
								`endif
							end
							STOP: begin
								next_state = s_EXECUTE;
								
								`ifndef synthesis
								// For simulation purposes
								$display("********************************************");
								$display("State: %s			Iter: %d	| 	PC: %h 	IR: STOP	(0x%h)		SP: %h	|Reset: %b \n	Registers {A B C D E H L} : {%h %h %h %h %h %h %h}   MAR: %h		MDR: %h	\n	Condition codes {Z N H C} : {%b %b %b %b}\n\n", 
								DUT.dp.cp.curr_state.name, DUT.dp.cp.iteration, DUT.dp.PC, DUT.dp.IR, DUT.dp.SP, rst,
								DUT.dp.regA, DUT.dp.regB, DUT.dp.regC, DUT.dp.regD, DUT.dp.regE, DUT.dp.regH, DUT.dp.regL, DUT.dp.MAR, DUT.dp.MDR,
								DUT.dp.regF[3], DUT.dp.regF[2], DUT.dp.regF[1], DUT.dp.regF[0]); 
								$display("********************************************\n");
								$stop;
								`endif
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
							LD_HLA_N8: begin
								control.alu_srcA = src_REGA;
								control.alu_srcB = src_REGB;
								control.reg_selA = reg_H;
								control.reg_selB = reg_L;
								control.alu_op	 = alu_AB;
								control.alu_dest = dest_MEMA;
							end
							// LOAD MEMORY HIGH
							LD_CA_A: begin
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

							// READ MEMORY HIGH
							LD_A_CA: begin
								control.reg_selA = reg_A;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_REG;
								control.alu_op	 = alu_B;
							end
							
							// MEMORY IMMEDIATE
							LD_N16A_A, LD_A_N16A: 
							begin
								control.alu_op	 = alu_AB;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_MEMA;
							end
							
							LD_N16A_SP: begin
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

							// ADD SP
							ADD_SP_N8: begin
								control.alu_op	 = alu_ADS_SP;
								control.alu_srcA = src_SP_l;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_SP_l;
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
								control.alu_op	 = alu_ADS_PC;
								control.alu_srcA = src_PC_l;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_PC_l;
							end
							JR_Z_N8: begin
								if (flags[3]) begin
									control.alu_op	 = alu_ADS_PC;
									control.alu_srcA = src_PC_l;
									control.alu_srcB = src_MEMD;
									control.alu_dest = dest_PC_l;
								end else begin
									// Do Nothing
								end
							end
							JR_NZ_N8: begin
								if (~flags[3]) begin
									control.alu_op	 = alu_ADS_PC;
									control.alu_srcA = src_PC_l;
									control.alu_srcB = src_MEMD;
									control.alu_dest = dest_PC_l;
								end else begin
									// Do Nothing
								end
							end
							JR_C_N8: begin
								if (flags[0]) begin
									control.alu_op	 = alu_ADS_PC;
									control.alu_srcA = src_PC_l;
									control.alu_srcB = src_MEMD;
									control.alu_dest = dest_PC_l;
								end else begin
									// Do Nothing
								end
							end
							JR_NC_N8: begin
								if (~flags[0]) begin
									control.alu_op	 = alu_ADS_PC;
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
							
							// SUBROUTINE CALLS
							CALL_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_h;
								control.alu_dest 	= dest_MEMD;
							end
							CALL_Z_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_h;
								control.alu_dest 	= dest_MEMD;
							end
							CALL_NZ_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_h;
								control.alu_dest 	= dest_MEMD;
							end
							CALL_C_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_h;
								control.alu_dest 	= dest_MEMD;
							end
							CALL_NC_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_h;
								control.alu_dest 	= dest_MEMD;
							end
							
							// SUBROUTINE RETURNS
							RET: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest	= dest_PC_l;
							end
							RET_Z: begin
								if (flags[3]) begin
									control.alu_op		= alu_B;
									control.alu_srcB	= src_MEMD;
									control.alu_dest	= dest_PC_l;
								end
							end
							RET_NZ: begin
								if (~flags[3]) begin
									control.alu_op		= alu_B;
									control.alu_srcB	= src_MEMD;
									control.alu_dest	= dest_PC_l;
								end
							end
							RET_C: begin
								if (flags[0]) begin
									control.alu_op		= alu_B;
									control.alu_srcB	= src_MEMD;
									control.alu_dest	= dest_PC_l;
								end
							end
							RET_NC: begin
								if (~flags[0]) begin
									control.alu_op		= alu_B;
									control.alu_srcB	= src_MEMD;
									control.alu_dest	= dest_PC_l;
								end
							end
							RETI: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest	= dest_PC_l;
							end
							
							RST_0, RST_8, RST_10, RST_18, RST_20, RST_28, RST_30, RST_38: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_h;
								control.alu_dest 	= dest_MEMD;
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
							
							LD_SP_HL: begin
								control.reg_selA = reg_H;
								control.alu_srcB = src_REGA;
								control.alu_op	 = alu_B;
								control.alu_dest = dest_SP_h;
								next_iteration 	 = 3'b1;
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
							// LOAD MEMORY HIGH
							LD_CA_A: begin
								control.alu_dest = dest_MEMAH;
								control.reg_selA = reg_C;
								control.alu_srcB = src_REGA;
								control.alu_op	 = alu_B;
								next_iteration	 = 3'b1;
							end
							LDH_N8A_A: begin
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_PC;
								
								control.read_en	 = `TRUE;
								next_iteration	 = 3'b1;
							end
							// READ MEMORY HIGH
							LDH_A_N8A: begin
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_PC;
								
								control.read_en	 = `TRUE;
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
							// READ MEMORY HIGH
							LD_A_CA: begin
								control.read_en = `TRUE;
								next_iteration	= 3'b1;
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
							
							// LOAD SP
							LD_N16A_SP: begin
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
							
							// ADD SP
							ADD_SP_N8: begin
								control.alu_dest = dest_PC;
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
							
								control.read_en  = `TRUE;
								next_iteration	 = 3'b1;
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
								next_iteration	 = 3'b1;
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
							
							// SUBROUTINE CALLS
							CALL_N16: begin
								control.alu_op		= alu_INCL;
								control.alu_srcA	= src_PC_h;
								control.alu_srcB	= src_PC_l;
								control.alu_dest	= dest_PC;
							
								next_iteration 		= 3'b1;
							end
							CALL_Z_N16: begin
								control.alu_op		= alu_INCL;
								control.alu_srcA	= src_PC_h;
								control.alu_srcB	= src_PC_l;
								control.alu_dest	= dest_PC;
							
								next_iteration 		= 3'b1;
							end
							CALL_NZ_N16: begin
								control.alu_op		= alu_INCL;
								control.alu_srcA	= src_PC_h;
								control.alu_srcB	= src_PC_l;
								control.alu_dest	= dest_PC;
							
								next_iteration 		= 3'b1;
							end
							CALL_C_N16: begin
								control.alu_op		= alu_INCL;
								control.alu_srcA	= src_PC_h;
								control.alu_srcB	= src_PC_l;
								control.alu_dest	= dest_PC;
							
								next_iteration 		= 3'b1;
							end
							CALL_NC_N16: begin
								control.alu_op		= alu_INCL;
								control.alu_srcA	= src_PC_h;
								control.alu_srcB	= src_PC_l;
								control.alu_dest	= dest_PC;
							
								next_iteration 		= 3'b1;
							end

							// SUBROUTINE RETURNS
							RET: begin
								control.alu_op		= alu_INCL;
								control.alu_srcA	= src_SP_h;
								control.alu_srcB	= src_SP_l;
								control.alu_dest 	= dest_SP;
								
								control.read_en		= `TRUE; 
								next_iteration 		= 3'b1;
							end
							RET_Z: begin
								if (flags[3]) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
									control.read_en		= `TRUE; 
								end
								
								next_iteration 		= 3'b1;
							end
							RET_NZ: begin
								if (~flags[3]) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
									control.read_en		= `TRUE; 
								end
								
								next_iteration 		= 3'b1;
							end
							RET_C: begin
								if (flags[0]) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
									control.read_en		= `TRUE; 
								end
								
								next_iteration 		= 3'b1;
							end
							RET_NC: begin
								if (~flags[0]) begin
									control.alu_op		= alu_INCL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
									control.read_en		= `TRUE; 
								end
								
								next_iteration 		= 3'b1;
							end
							RETI: begin
								control.alu_op		= alu_INCL;
								control.alu_srcA	= src_SP_h;
								control.alu_srcB	= src_SP_l;
								control.alu_dest 	= dest_SP;
								
								control.read_en		= `TRUE; 
								next_iteration 		= 3'b1;
							end

							RST_0, RST_8, RST_10, RST_18, RST_20, RST_28, RST_30, RST_38: begin
								control.alu_op		= alu_AB;
								control.alu_srcA	= src_SP_h;
								control.alu_srcB	= src_SP_l;
								control.alu_dest 	= dest_MEMA;
								next_iteration 		= 3'b1;
							end
							
							PREFIX: begin
								next_prefix = `TRUE;
							end
							
						endcase				
						
					end else if (iteration == 3'd1) begin
					
						case(op_code)
						
							// ADD SP
							ADD_SP_N8: begin
								next_iteration   = 3'd2;
							end
						
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
							
								control.write_en = `TRUE;
								next_iteration 	 = 3'd2;
							end
							
							// LOAD MEMORY HIGH
							LDH_N8A_A: begin
								control.alu_op	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_MEMAH;
								
								next_iteration 	= 3'd2;
							end
						
							// READ MEMORY HIGH
							LDH_A_N8A: begin
								control.alu_op	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_MEMAH;
								
								next_iteration 	= 3'd2;
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
							
							// LOAD SP
							LD_N16A_SP: begin
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
							
							// SUBROUTINE CALLS
							CALL_N16: begin
								control.alu_op		= alu_DECL;
								control.alu_srcA	= src_SP_h;
								control.alu_srcB	= src_SP_l;
								control.alu_dest 	= dest_SP;
								
								next_iteration 		= 3'd2;
							end
							CALL_Z_N16: begin
								if (flags[3]) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
								end
								
								next_iteration 		= 3'd2;
							end
							CALL_NZ_N16: begin
								if (~flags[3]) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
								end
								
								next_iteration 		= 3'd2;
							end
							CALL_C_N16: begin
								if (flags[0]) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
								end
								
								next_iteration 		= 3'd2;
							end
							CALL_NC_N16: begin
								if (~flags[0]) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
								end
								
								next_iteration 		= 3'd2;
							end
							
							// SUBROUTINE RETURNS
							RET: begin
								control.alu_op		= alu_AB;
								control.alu_srcA	= src_SP_h;
								control.alu_srcB	= src_SP_l;
								control.alu_dest 	= dest_MEMA;
								
								next_iteration 		= 3'd2;
							end
							RET_Z: begin
								if (flags[3]) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
									
									next_iteration 		= 3'd2;
								end else 
									next_iteration		= 3'b0;
							end
							RET_NZ: begin
								if (~flags[3]) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
									
									next_iteration 		= 3'd2;
								end else 
									next_iteration		= 3'b0;
							end
							RET_C: begin
								if (flags[0]) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
									
									next_iteration 		= 3'd2;
								end else 
									next_iteration		= 3'b0;
							end
							RET_NC: begin
								if (~flags[0]) begin
									control.alu_op		= alu_AB;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_MEMA;
									
									next_iteration 		= 3'd2;
								end else 
									next_iteration		= 3'b0;
							end
							RETI: begin
								control.alu_op		= alu_AB;
								control.alu_srcA	= src_SP_h;
								control.alu_srcB	= src_SP_l;
								control.alu_dest 	= dest_MEMA;
								
								next_iteration 		= 3'd2;
							end

							RST_0, RST_8, RST_10, RST_18, RST_20, RST_28, RST_30, RST_38: begin
								control.alu_dest = dest_SP;
								control.alu_op	 = alu_DECL;
								control.alu_srcA = src_SP_h;
								control.alu_srcB = src_SP_l;
								control.write_en = `TRUE;
								next_iteration 		= 3'd2;
							end
							
							default: begin
								next_iteration		= 3'b0;
							end
						endcase
						
					end else if (iteration == 3'd2) begin
					
						case(op_code)
						
							// ADD SP
							ADD_SP_N8: begin
								next_iteration   = 3'd3;
							end
						
							// LOAD 16-BIT IMMEDIATE
							LD_BC_N16: begin
								control.alu_op 	 = alu_B;
								control.reg_selA = reg_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_REG;
								next_iteration	 = 3'b0;
							end
							LD_DE_N16: begin
								control.alu_op 	 = alu_B;
								control.reg_selA = reg_D;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_REG;
								next_iteration 	 = 3'b0;
							end
							LD_HL_N16: begin
								control.alu_op 	 = alu_B;
								control.reg_selA = reg_H;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_REG;
								next_iteration 	 = 3'b0;
							end
							LD_SP_N16: begin
								control.alu_op 	 = alu_B;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_SP_h;
								next_iteration	 = 3'b0;
							end

							// LOAD MEMORY IMMEDIATE
							LD_N16A_A: begin
								control.alu_op	 = alu_B;
								control.reg_selA = reg_A;
								control.alu_srcB = src_REGA;
								control.alu_dest = dest_MEMD;
								
								next_iteration	 = 3'd3;
							end
							LDH_N8A_A: begin
								control.write_en = `TRUE;
								next_iteration 	 = 3'b0;
							end
							
							// READ MEMORY HIGH
							LDH_A_N8A: begin
								control.alu_op	 = alu_B;
								control.reg_selA = reg_A;
								control.alu_srcB = src_MEMD;
								control.alu_dest = dest_REG;
								
								next_iteration	 = 3'd0;
							end
							
							// READ MEMORY IMMEDIATE
							LD_A_N16A: begin
								control.alu_op	 = alu_INCL;
								control.alu_srcA = src_PC_h;
								control.alu_srcB = src_PC_l;
								control.alu_dest = dest_PC;
							
								control.read_en	 = `TRUE;
								next_iteration	 = 3'd3;
							end
							
							// LOAD SP
							LD_N16A_SP: begin
								control.alu_op	 = alu_B;
								control.alu_srcB = src_SP_l;
								control.alu_dest = dest_MEMD;
								
								next_iteration   = 3'd3;
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
							
							// SUBROUTINE CALLS
							CALL_N16: begin
								control.alu_op		= alu_DECL;
								control.alu_srcA	= src_SP_h;
								control.alu_srcB	= src_SP_l;
								control.alu_dest 	= dest_SP;
								
								next_iteration 		= 3'd3;
								control.write_en	= `TRUE;
							end
							CALL_Z_N16: begin
								if (flags[3]) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
									next_iteration 		= 3'd3;
									control.write_en	= `TRUE;
								end else 
									next_iteration 		= 3'b0;

							end
							CALL_NZ_N16: begin
								if (~flags[3]) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
									next_iteration 		= 3'd3;
									control.write_en	= `TRUE;
								end else 
									next_iteration 		= 3'b0;
							end
							CALL_C_N16: begin
								if (flags[0]) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
									next_iteration 		= 3'd3;
									control.write_en	= `TRUE;
								end else 
									next_iteration 		= 3'b0;
							end
							CALL_NC_N16: begin
								if (~flags[0]) begin
									control.alu_op		= alu_DECL;
									control.alu_srcA	= src_SP_h;
									control.alu_srcB	= src_SP_l;
									control.alu_dest 	= dest_SP;
									next_iteration 		= 3'd3;
									control.write_en	= `TRUE;
								end else 
									next_iteration 		= 3'b0;								
							end
							
							// SUBROUTINE RETURNS
							RET: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest 	= dest_PC_h;
								
								next_iteration 		= 3'd3;
							end
							RET_Z: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest 	= dest_PC_h;
								
								next_iteration 		= 3'd3;
							end
							RET_NZ: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest 	= dest_PC_h;
								
								next_iteration 		= 3'd3;
							end
							RET_C: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest 	= dest_PC_h;
								
								next_iteration 		= 3'd3;
							end
							RET_NC: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest 	= dest_PC_h;
								
								next_iteration 		= 3'd3;
							end
							RETI: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest 	= dest_PC_h;
								
								enable_interrupts 	= `TRUE;
								
								next_iteration 		= 3'd3;
							end
							
							RST_0, RST_8, RST_10, RST_18, RST_20, RST_28, RST_30, RST_38: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_l;
								control.alu_dest 	= dest_MEMD;
								
								next_iteration 		= 3'd3;
							end
							
							default: begin
								next_iteration		= 3'b0;
							end
						endcase
						
					end else if (iteration == 3'd3) begin
						case(op_code)
							// LOAD SP
							LD_N16A_SP: begin
								control.alu_op	 = alu_B;
								control.alu_srcB = src_SP_h;
								control.alu_dest = dest_MEMD;

								next_iteration   = 3'd4;
							end
						
							// STACK OPERATIONS
							PUSH_AF, PUSH_BC, PUSH_DE, PUSH_HL: 
							begin
								control.write_en 	= `TRUE;
								next_iteration		= 3'd0;
							end
							
							// SUBROUTINE CALLS
							CALL_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_l;
								control.alu_dest 	= dest_MEMD;
							
								next_iteration		= 3'd4;
							end
							CALL_Z_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_l;
								control.alu_dest 	= dest_MEMD;
							
								next_iteration		= 3'd4;
							end
							CALL_NZ_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_l;
								control.alu_dest 	= dest_MEMD;
							
								next_iteration		= 3'd4;
							end
							CALL_C_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_l;
								control.alu_dest 	= dest_MEMD;
							
								next_iteration		= 3'd4;
							end
							CALL_NC_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_PC_l;
								control.alu_dest 	= dest_MEMD;
							
								next_iteration		= 3'd4;
							end

							// RESET
							RST_0: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_00;
								control.alu_dest	= dest_PC_l;
								
								next_iteration		= 3'b0;
							end
							RST_8: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_08;
								control.alu_dest	= dest_PC_l;
								
								next_iteration		= 3'b0;
							end
							RST_10: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_10;
								control.alu_dest	= dest_PC_l;
								
								next_iteration		= 3'b0;
							end
							RST_18: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_18;
								control.alu_dest	= dest_PC_l;
								
								next_iteration		= 3'b0;
							end
							RST_20: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_20;
								control.alu_dest	= dest_PC_l;
								
								next_iteration		= 3'b0;
							end
							RST_28: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_28;
								control.alu_dest	= dest_PC_l;
								
								next_iteration		= 3'b0;
							end
							RST_30: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_30;
								control.alu_dest	= dest_PC_l;
								
								next_iteration		= 3'b0;
							end
							RST_38: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_38;
								control.alu_dest	= dest_PC_l;
								
								next_iteration		= 3'b0;
							end							
							
							default: begin
								next_iteration		= 3'b0;
							end
						endcase
						
					end else if (iteration == 3'd4) begin
						case(op_code)
							// SUBROUTINE CALLS
							CALL_N16: begin
								control.alu_op		= alu_DECL;
								control.alu_dest	= dest_MEMA;
								control.alu_srcA	= src_MEMA;
								control.alu_srcB	= src_MEMA;
							
								control.read_en 	= `TRUE;
								next_iteration 		= 3'd5;
							end
							CALL_Z_N16: begin
								control.alu_op		= alu_DECL;
								control.alu_dest	= dest_MEMA;
								control.alu_srcA	= src_MEMA;
								control.alu_srcB	= src_MEMA;
							
								control.read_en 	= `TRUE;
								next_iteration 		= 3'd5;
							end
							CALL_NZ_N16: begin
								control.alu_op		= alu_DECL;
								control.alu_dest	= dest_MEMA;
								control.alu_srcA	= src_MEMA;
								control.alu_srcB	= src_MEMA;
							
								control.read_en 	= `TRUE;
								next_iteration 		= 3'd5;
							end
							CALL_C_N16: begin
								control.alu_op		= alu_DECL;
								control.alu_dest	= dest_MEMA;
								control.alu_srcA	= src_MEMA;
								control.alu_srcB	= src_MEMA;
							
								control.read_en 	= `TRUE;
								next_iteration 		= 3'd5;
							end
							CALL_NC_N16: begin
								control.alu_op		= alu_DECL;
								control.alu_dest	= dest_MEMA;
								control.alu_srcA	= src_MEMA;
								control.alu_srcB	= src_MEMA;
							
								control.read_en 	= `TRUE;
								next_iteration 		= 3'd5;
							end

							
							default: begin
								next_iteration = 3'd0;
							end
						endcase
					
					end else if (iteration == 3'd5) begin
						case(op_code) 
							// SUBROUTINE CALLS
							CALL_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest	= dest_PC_l;
							
								next_iteration 	= 3'd0;
							end
							CALL_Z_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest	= dest_PC_l;
							
								next_iteration 	= 3'd0;
							end
							CALL_NZ_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest	= dest_PC_l;
							
								next_iteration 	= 3'd0;
							end
							CALL_C_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest	= dest_PC_l;
							
								next_iteration 	= 3'd0;
							end
							CALL_NC_N16: begin
								control.alu_op		= alu_B;
								control.alu_srcB	= src_MEMD;
								control.alu_dest	= dest_PC_l;
							
								next_iteration 	= 3'd0;
							end

							default: begin
								next_iteration 	= 3'd0;
							end
						endcase
					end
				end
			endcase
		
		end else begin
		
			next_prefix	  			= `TRUE;
			next_iteration			= iteration;

			case (curr_state)
				s_FETCH: begin
					
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

					next_state				= s_EXECUTE;
					
					if (iteration == 3'b0)
						control.load_op_code	= `TRUE;

				end
				
				/*	State = EXECUTE
				*
				*	Executes ALU operation or memory read based on iteration and instruction. 
				*/
				s_EXECUTE: begin

					next_state				= s_WRITE;
					
					// DO OUR PREFIX INSTRUCTION
					case (op_code) 
					
						// ROTATE LEFT CARRY
						RLC_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RLC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RLC_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RLC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RLC_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RLC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RLC_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RLC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RLC_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RLC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RLC_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RLC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RLC_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RLC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						
						// ROTATE LEFT
						RL_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RL_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RL_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RL_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RL_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RL_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RL_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						
						// ROTATE RIGHT CARRY
						RRC_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RRC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RRC_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RRC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RRC_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RRC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RRC_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RRC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RRC_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RRC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RRC_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RRC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RRC_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RRC;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end

						// ROTATE RIGHT
						RR_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RR;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RR_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RR;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RR_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RR;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RR_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RR;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RR_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RR;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RR_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RR;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						RR_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RR;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end

						// SHIFT LEFT ARITHMETIC
						SLA_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SLA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SLA_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SLA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SLA_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SLA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SLA_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SLA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SLA_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SLA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SLA_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SLA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SLA_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SLA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end

						// SHIFT RIGHT ARITHMETIC
						SRA_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRA_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRA_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRA_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRA_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRA_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRA_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRA;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						
						// SHIFT RIGHT LOGICAL
						SRL_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRL_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRL_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRL_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRL_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRL_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SRL_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SRL;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
					
						// SWAP NIBBLES
						SWAP_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SWAP;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SWAP_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SWAP;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SWAP_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SWAP;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SWAP_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SWAP;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SWAP_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SWAP;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SWAP_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SWAP;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						SWAP_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SWAP;
							control.alu_dest	= dest_REG;
							control.ld_flags	= `TRUE;
						end
						
						
						// BIT COMMANDS
						BIT_0_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b0;
							control.ld_flags 	= `TRUE;
						end
						BIT_1_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b1;
							control.ld_flags 	= `TRUE;
						end
						BIT_2_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd2;
							control.ld_flags 	= `TRUE;
						end
						BIT_3_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd3;
							control.ld_flags 	= `TRUE;
						end
						BIT_4_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd4;
							control.ld_flags 	= `TRUE;
						end
						BIT_5_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd5;
							control.ld_flags 	= `TRUE;
						end
						BIT_6_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd6;
							control.ld_flags 	= `TRUE;
						end
						BIT_7_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd7;
							control.ld_flags 	= `TRUE;
						end
						
						BIT_0_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b0;
							control.ld_flags 	= `TRUE;
						end
						BIT_1_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b1;
							control.ld_flags 	= `TRUE;
						end
						BIT_2_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd2;
							control.ld_flags 	= `TRUE;
						end
						BIT_3_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd3;
							control.ld_flags 	= `TRUE;
						end
						BIT_4_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd4;
							control.ld_flags 	= `TRUE;
						end
						BIT_5_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd5;
							control.ld_flags 	= `TRUE;
						end
						BIT_6_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd6;
							control.ld_flags 	= `TRUE;
						end
						BIT_7_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd7;
							control.ld_flags 	= `TRUE;
						end

						BIT_0_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b0;
							control.ld_flags 	= `TRUE;
						end
						BIT_1_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b1;
							control.ld_flags 	= `TRUE;
						end
						BIT_2_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd2;
							control.ld_flags 	= `TRUE;
						end
						BIT_3_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd3;
							control.ld_flags 	= `TRUE;
						end
						BIT_4_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd4;
							control.ld_flags 	= `TRUE;
						end
						BIT_5_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd5;
							control.ld_flags 	= `TRUE;
						end
						BIT_6_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd6;
							control.ld_flags 	= `TRUE;
						end
						BIT_7_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd7;
							control.ld_flags 	= `TRUE;
						end

						BIT_0_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b0;
							control.ld_flags 	= `TRUE;
						end
						BIT_1_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b1;
							control.ld_flags 	= `TRUE;
						end
						BIT_2_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd2;
							control.ld_flags 	= `TRUE;
						end
						BIT_3_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd3;
							control.ld_flags 	= `TRUE;
						end
						BIT_4_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd4;
							control.ld_flags 	= `TRUE;
						end
						BIT_5_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd5;
							control.ld_flags 	= `TRUE;
						end
						BIT_6_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd6;
							control.ld_flags 	= `TRUE;
						end
						BIT_7_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd7;
							control.ld_flags 	= `TRUE;
						end
						
						BIT_0_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b0;
							control.ld_flags 	= `TRUE;
						end
						BIT_1_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b1;
							control.ld_flags 	= `TRUE;
						end
						BIT_2_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd2;
							control.ld_flags 	= `TRUE;
						end
						BIT_3_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd3;
							control.ld_flags 	= `TRUE;
						end
						BIT_4_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd4;
							control.ld_flags 	= `TRUE;
						end
						BIT_5_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd5;
							control.ld_flags 	= `TRUE;
						end
						BIT_6_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd6;
							control.ld_flags 	= `TRUE;
						end
						BIT_7_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd7;
							control.ld_flags 	= `TRUE;
						end
						

						BIT_0_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b0;
							control.ld_flags 	= `TRUE;
						end
						BIT_1_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b1;
							control.ld_flags 	= `TRUE;
						end
						BIT_2_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd2;
							control.ld_flags 	= `TRUE;
						end
						BIT_3_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd3;
							control.ld_flags 	= `TRUE;
						end
						BIT_4_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd4;
							control.ld_flags 	= `TRUE;
						end
						BIT_5_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd5;
							control.ld_flags 	= `TRUE;
						end
						BIT_6_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd6;
							control.ld_flags 	= `TRUE;
						end
						BIT_7_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd7;
							control.ld_flags 	= `TRUE;
						end
						

						BIT_0_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b0;
							control.ld_flags 	= `TRUE;
						end
						BIT_1_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'b1;
							control.ld_flags 	= `TRUE;
						end
						BIT_2_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd2;
							control.ld_flags 	= `TRUE;
						end
						BIT_3_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd3;
							control.ld_flags 	= `TRUE;
						end
						BIT_4_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd4;
							control.ld_flags 	= `TRUE;
						end
						BIT_5_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd5;
							control.ld_flags 	= `TRUE;
						end
						BIT_6_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd6;
							control.ld_flags 	= `TRUE;
						end
						BIT_7_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_BIT;
							control.bit_num		= 3'd7;
							control.ld_flags 	= `TRUE;
						end
						
						// RES BIT INSTRUCTIONS
						RES_0_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						RES_1_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						RES_2_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						RES_3_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						RES_4_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						RES_5_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						RES_6_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						RES_7_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end
						
						RES_0_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						RES_1_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						RES_2_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						RES_3_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						RES_4_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						RES_5_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						RES_6_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						RES_7_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end

						RES_0_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						RES_1_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						RES_2_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						RES_3_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						RES_4_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						RES_5_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						RES_6_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						RES_7_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end

						RES_0_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						RES_1_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						RES_2_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						RES_3_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						RES_4_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						RES_5_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						RES_6_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						RES_7_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end
						
						RES_0_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						RES_1_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						RES_2_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						RES_3_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						RES_4_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						RES_5_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						RES_6_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						RES_7_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end
						

						RES_0_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						RES_1_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						RES_2_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						RES_3_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						RES_4_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						RES_5_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						RES_6_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						RES_7_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end
						

						RES_0_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						RES_1_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						RES_2_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						RES_3_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						RES_4_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						RES_5_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						RES_6_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						RES_7_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_RES;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end
						
						// SET BIT INSTRUCTIONS
						SET_0_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						SET_1_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						SET_2_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						SET_3_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						SET_4_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						SET_5_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						SET_6_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						SET_7_A: begin
							control.reg_selA	= reg_A;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end
						
						SET_0_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						SET_1_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						SET_2_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						SET_3_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						SET_4_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						SET_5_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						SET_6_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						SET_7_B: begin
							control.reg_selA	= reg_B;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end

						SET_0_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						SET_1_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						SET_2_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						SET_3_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						SET_4_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						SET_5_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						SET_6_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						SET_7_C: begin
							control.reg_selA	= reg_C;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end

						SET_0_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						SET_1_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						SET_2_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						SET_3_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						SET_4_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						SET_5_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						SET_6_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						SET_7_D: begin
							control.reg_selA	= reg_D;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end
						
						SET_0_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						SET_1_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						SET_2_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						SET_3_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						SET_4_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						SET_5_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						SET_6_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						SET_7_E: begin
							control.reg_selA	= reg_E;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end
						

						SET_0_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						SET_1_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						SET_2_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						SET_3_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						SET_4_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						SET_5_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						SET_6_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						SET_7_H: begin
							control.reg_selA	= reg_H;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end
						

						SET_0_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b0;
							control.alu_dest 	= dest_REG;
						end
						SET_1_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'b1;
							control.alu_dest 	= dest_REG;
						end
						SET_2_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd2;
							control.alu_dest 	= dest_REG;
						end
						SET_3_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd3;
							control.alu_dest 	= dest_REG;
						end
						SET_4_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd4;
							control.alu_dest 	= dest_REG;
						end
						SET_5_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd5;
							control.alu_dest 	= dest_REG;
						end
						SET_6_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd6;
							control.alu_dest 	= dest_REG;
						end
						SET_7_L: begin
							control.reg_selA	= reg_L;
							control.alu_srcB	= src_REGA;
							control.alu_op		= alu_SET;
							control.bit_num		= 3'd7;
							control.alu_dest 	= dest_REG;
						end
						
						// HL OPERATIONS
						RLC_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_RLC;
								control.alu_dest	= dest_MEMD;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						RL_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_RL;
								control.alu_dest	= dest_MEMD;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						RRC_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_RRC;
								control.alu_dest	= dest_MEMD;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						RR_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_RR;
								control.alu_dest	= dest_MEMD;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						SLA_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_SLA;
								control.alu_dest	= dest_MEMD;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						SRA_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_SRA;
								control.alu_dest	= dest_MEMD;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						SRL_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_SRL;
								control.alu_dest	= dest_MEMD;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						SWAP_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_SWAP;
								control.alu_dest	= dest_MEMD;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						BIT_0_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_BIT;
								control.bit_num		= 3'd0;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						BIT_1_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_BIT;
								control.bit_num		= 3'd1;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						BIT_2_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.bit_num		= 3'd2;
								control.alu_op	 	= alu_BIT;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						BIT_3_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_BIT;
								control.bit_num		= 3'd3;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						BIT_4_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_BIT;
								control.bit_num		= 3'd4;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						BIT_5_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.bit_num		= 3'd5;
								control.alu_op	 	= alu_BIT;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						BIT_6_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_BIT;
								control.bit_num		= 3'd6;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						BIT_7_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_BIT;
								control.bit_num		= 3'd7;
								control.ld_flags	= `TRUE;
							end else begin
								// DO NOTHING
							end
						end
						SET_0_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_SET;
								control.bit_num		= 3'd0;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						SET_1_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_SET;
								control.bit_num		= 3'd1;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						SET_2_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.bit_num		= 3'd2;
								control.alu_op	 	= alu_SET;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						SET_3_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_SET;
								control.bit_num		= 3'd3;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						SET_4_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_SET;
								control.bit_num		= 3'd4;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						SET_5_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.bit_num		= 3'd5;
								control.alu_op	 	= alu_SET;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						SET_6_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_SET;
								control.bit_num		= 3'd6;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						SET_7_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_SET;
								control.bit_num		= 3'd7;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						RES_0_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_RES;
								control.bit_num		= 3'd0;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						RES_1_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_RES;
								control.bit_num		= 3'd1;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						RES_2_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.bit_num		= 3'd2;
								control.alu_op	 	= alu_RES;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						RES_3_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_RES;
								control.bit_num		= 3'd3;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						RES_4_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_RES;
								control.bit_num		= 3'd4;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						RES_5_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.bit_num		= 3'd5;
								control.alu_op	 	= alu_RES;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						RES_6_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_RES;
								control.bit_num		= 3'd6;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
						RES_7_HLA: begin
							if (iteration == 3'b0) begin
								control.reg_selA 	= reg_H;
								control.reg_selB 	= reg_L;
								control.alu_srcA	= src_REGA;
								control.alu_srcB 	= src_REGB;
								control.alu_op		= alu_AB;
								control.alu_dest	= dest_MEMA;
							end else if (iteration == 3'b1) begin
								control.alu_srcB 	= src_MEMD;
								control.alu_op	 	= alu_RES;
								control.bit_num		= 3'd7;
								control.alu_dest	= dest_MEMD;
							end else begin
								// DO NOTHING
							end
						end
					endcase
					
				end
				
				/*	State = WRITE
				*
				*	Writes back to registers, increments iteration if more iterations necessary. 
				*	Resets iteration if operation done based on instruction. 
				*/
				s_WRITE: begin
					
					// MAKE SURE WE GO BACK TO NORMAL MODE
					next_prefix	  			= `FALSE;
					next_iteration			= 3'b0;
					next_state				= s_FETCH;
					
					case (op_code) 
							
							// HL OPERATIONS
							RLC_HLA,   RL_HLA,    SLA_HLA,   RRC_HLA,   RR_HLA,    SRA_HLA,   SRL_HLA,   SWAP_HLA:
							begin
								if (iteration == 3'b0) begin
									control.read_en		= `TRUE;
									next_prefix 		= `TRUE;
									next_iteration 		= 3'b1;
								end else if (iteration == 3'b1) begin
									control.write_en	= `TRUE;
									next_iteration 		= 3'd2;
									next_prefix 		= `TRUE;
								end else begin
									// DO NOTHING
								end
							end
							
							BIT_0_HLA, BIT_1_HLA, BIT_2_HLA, BIT_3_HLA, BIT_4_HLA, BIT_5_HLA, BIT_6_HLA, BIT_7_HLA, 
							RES_0_HLA, RES_1_HLA, RES_2_HLA, RES_3_HLA, RES_4_HLA, RES_5_HLA, RES_6_HLA, RES_7_HLA, 
							SET_0_HLA, SET_1_HLA, SET_2_HLA, SET_3_HLA, SET_4_HLA, SET_5_HLA, SET_6_HLA, SET_7_HLA:
							
							begin
								if (iteration == 3'b0) begin
									control.read_en		= `TRUE;
									next_prefix 		= `TRUE;
									next_iteration 		= 3'b1;
								end else if (iteration == 3'b1) begin
									next_iteration 		= 3'd2;
									next_prefix 		= `TRUE;
								end else begin
									// DO NOTHING
								end
							end

					endcase
					
				end
				
			endcase
		end
		
	end

endmodule: control_path