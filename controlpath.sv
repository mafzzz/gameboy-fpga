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
*	Contact Sohil Shah at sohils@cmu.edu for information or questions. 
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
		next_prefix	  	= `FALSE;
		next_iteration	= iteration;
	
		case (curr_state)
		
			/*	State = FETCH
			*
			*	Tells Datapath to retrieve next instruction from memory and increment
			*	the PC if on first iteration. 
			*
			*	Does nothing if not first iteration. 
			*/
			s_FETCH: begin
				if (iteration == 3'b000)
					fetch_op_code 		= `TRUE;
			
				control.reg_selA 		= reg_UNK;
				control.reg_selB 		= reg_UNK;
				control.alu_op   		= alu_UNK;
				control.alu_srcA		= src_UNK;
				control.alu_srcB		= src_UNK;	
				control.alu_dest		= dest_UNK;
				control.reg_ld			= `FALSE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.flags_loaded	= {`FALSE, `FALSE, `FALSE, `FALSE};
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
				control.alu_dest		= dest_UNK;
				control.reg_ld			= `FALSE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.flags_loaded	= {`FALSE, `FALSE, `FALSE, `FALSE};
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
				control.alu_dest		= dest_UNK;
				control.reg_ld			= `FALSE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.flags_loaded	= {`FALSE, `FALSE, `FALSE, `FALSE};
				
				case (op_code)
					default: ;
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
				control.alu_dest		= dest_UNK;
				control.reg_ld			= `FALSE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.flags_loaded	= {`FALSE, `FALSE, `FALSE, `FALSE};
			end
		endcase
	
	end
	
endmodule: control_path