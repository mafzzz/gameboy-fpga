/**************************************************************************
*	"alu.sv"
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

/*	Module ALU: All arithmatic and logic tasks
*
*	Operands A and B use ALU OP Code to output result and flags
*	Address result gives 16-bit output with A and B concatenated
*/
module alu
	(input logic [7:0]	op_A,
	input logic [7:0]	op_B,
	input alu_op_t		op_code,
	input logic [3:0]	curr_flags,
	output logic		PC_inc_h,
	output logic		PC_dec_h,
	output logic [3:0]	next_flags,
	output logic [7:0]	alu_result,
	output logic [15:0]	addr_result);
	
	always_comb begin 
		PC_inc_h	= 1'b0;
		PC_dec_h	= 1'b0;
		case (op_code)
			
			// No operation
			alu_NOP: begin
				alu_result = 8'bx;
				addr_result = 16'bx;
				next_flags = curr_flags;
			end
			
			// Pass concatenation of A, B to address
			alu_AB: begin
				alu_result = 8'bx;
				addr_result = {op_A, op_B};
				next_flags = curr_flags;
			end
			
			// Pass B
			alu_B: begin
				alu_result = op_B;
				addr_result = 16'bx;
				next_flags = curr_flags;
			end

			// A + B
			alu_ADD: begin
				{next_flags[0], alu_result} = op_A + op_B;
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = alu_result[4] ^ (op_A[4] ^ op_B[4]);
				addr_result = 16'bx;
				next_flags[2] = 1'b0;
			end
			
			// A + B + CY
			alu_ADC: begin
				{next_flags[0], alu_result} = op_A + op_B + curr_flags[0];
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = alu_result[4] ^ (op_A[4] ^ op_B[4]);
				addr_result = 16'bx;
				next_flags[2] = 1'b0;
			end
			
			// Signed addition for JR, B is signed
			alu_ADS: begin
				addr_result = 16'bx;
				next_flags = curr_flags;
				if (op_B[7]) begin
					{PC_dec_h, alu_result} = op_A + op_B;
					PC_dec_h = ~PC_dec_h;
					PC_inc_h = 1'b0;
				end else begin
					{PC_inc_h, alu_result} = op_A + op_B;
					PC_dec_h = 1'b0;
				end
			end
			
			// A - B
			alu_SUB: begin
				{next_flags[0], alu_result} = op_A - op_B;
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = alu_result[4] ^ (op_A[4] ^ op_B[4]);
				addr_result = 16'bx;
				next_flags[2] = 1'b1;
			end
			
			// A - B - CY
			alu_SBC: begin
				{next_flags[0], alu_result} = op_A - op_B - curr_flags[0];
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = alu_result[4] ^ (op_A[4] ^ op_B[4]);
				addr_result = 16'bx;
				next_flags[2] = 1'b1;
			end
			
			// A & B
			alu_AND: begin
				alu_result = op_A & op_B;
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:0] = 3'b010;
			end
			
			// A | B
			alu_OR: begin
				alu_result = op_A | op_B;
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:0] = 3'b000;
			end
			
			// A ^ B
			alu_XOR: begin
				alu_result = op_A ^ op_B;
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:0] = 3'b000;
			end
			
			// A + 1
			alu_INC: begin
				alu_result = 8'h01 + op_B;
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = alu_result[4] ^ op_B[4];
				addr_result = 16'bx;
				next_flags[2] = 1'b0;
				next_flags[0] = curr_flags[0];
			end
			
			// A - 1
			alu_DEC: begin
				alu_result = op_B - 8'h01;
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = alu_result[4] ^ op_B[4];
				addr_result = 16'bx;
				next_flags[2] = 1'b1;
				next_flags[0] = curr_flags[0];
			end
			
			// Swaps high and low nibbles of B
			alu_SWAP: begin
				alu_result = {op_B[3:0], op_B[7:4]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:0] = 3'b0;
			end
			
			// Adjusts result of arithmetic for BCD depending on Half-carry and Carry
			alu_DAA: begin
				if (curr_flags[2]) begin
					unique case(curr_flags[1:0])
						2'b00: {next_flags[0], alu_result} = {1'b0, op_B};
						2'b01: {next_flags[0], alu_result} = {1'b1, op_B + 8'hA0};
						2'b10: {next_flags[0], alu_result} = {1'b0, op_B + 8'hFA};
						2'b11: {next_flags[0], alu_result} = {1'b1, op_B + 8'h9A};
					endcase
				end else begin
					unique case(curr_flags[1:0])
						2'b00: {next_flags[0], alu_result} = (op_B[3:0] < 4'hA && op_B[7:4] < 4'hA) ? {1'b0, op_B + 8'h00} : ((op_B[3:0] < 4'hA && op_B[7:4] > 4'hA) 
								? {1'b1, op_B + 8'h60} : ((op_B[3:0] > 4'hA) ? {1'b0, op_B + 8'h06} : {1'b1, op_B + 8'h66}));
						2'b01: {next_flags[0], alu_result} = (op_B[3:0] < 4'hA) ? {1'b1, op_B + 8'h60} : {1'b1, op_B + 8'h66};
						2'b10: {next_flags[0], alu_result} = (op_B[7:4] < 4'hA) ? {1'b0, op_B + 8'h06} : {1'b1, op_B + 8'h66};
						2'b11: {next_flags[0], alu_result} = {1'b1, op_B + 8'h66};
					endcase
				end
				addr_result = 16'bx;
				next_flags[3] = (alu_result == 8'b0);
				next_flags[2] = curr_flags[2];
				next_flags[1] = 1'b0;
			end
			
			// Complements B
			alu_CPL: begin 
				alu_result = ~op_B;
				addr_result = 16'bx;
				next_flags = curr_flags;
				next_flags[2:1] = 2'b11;
			end
			
			// Rotate left with carry
			alu_RLC: begin 
				{next_flags[0], alu_result} = {op_B[7], op_B[6:0], op_B[7]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end

			alu_RLCA: begin 
				{next_flags[0], alu_result} = {op_B[7], op_B[6:0], op_B[7]};
				addr_result = 16'bx;
				next_flags[3:1] = 2'b00;
			end
			
			// Rotate left through carry
			alu_RL: begin
				{next_flags[0], alu_result} = {op_B[7], op_B[6:0], curr_flags[0]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end

			alu_RLA: begin
				{next_flags[0], alu_result} = {op_B[7], op_B[6:0], curr_flags[0]};
				addr_result = 16'bx;
				next_flags[3:1] = 2'b00;
			end
			
			// Rotate right with carry
			alu_RRC: begin
				{next_flags[0], alu_result} = {op_B[0], op_B[0], op_B[7:1]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
	
			alu_RRCA: begin
				{next_flags[0], alu_result} = {op_B[0], op_B[0], op_B[7:1]};
				addr_result = 16'bx;
				next_flags[3:1] = 2'b00;
			end
			
			// Rotate right through carry
			alu_RR: begin
				{next_flags[0], alu_result} = {op_B[0], curr_flags[0], op_B[7:1]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
			
			alu_RRA: begin
				{next_flags[0], alu_result} = {op_B[0], curr_flags[0], op_B[7:1]};
				addr_result = 16'bx;
				next_flags[3:1] = 2'b00;
			end

			// Arithmetic shift left
			alu_SLA: begin
				{next_flags[0], alu_result} = {op_B[7], op_B << 1};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
			
			// Arithmetic shift right
			alu_SRA: begin
				{next_flags[0], alu_result} = {op_B[0], op_B[7], op_B[7:1]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
			
			// Logical shift right
			alu_SRL: begin
				{next_flags[0], alu_result} = {op_B[0], 1'b0, op_B[7:1]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
	
			// Increment a 16-bit value
			alu_INCL: begin
				alu_result = 8'bx;
				addr_result = {op_A, op_B} + 1;
				next_flags = curr_flags;
			end
			
			// Increment a 16-bit value
			alu_DECL: begin
				alu_result = 8'bx;
				addr_result = {op_A, op_B} - 1;
				next_flags = curr_flags;
			end
			
			// Set carry flag
			alu_SCF: begin
				alu_result = 8'bx;
				addr_result = 8'bx;
				next_flags = {curr_flags[3], 1'b0, 1'b0, 1'b1};
			end

			// Complement carry flag
			alu_CCF: begin
				alu_result = 8'bx;
				addr_result = 8'bx;
				next_flags = {curr_flags[3], 1'b0, 1'b0, ~curr_flags[0]};
			end
	
			// Unknown OP Code
			default: begin
				alu_result = 8'bx;
				addr_result = 16'bx;
				next_flags = 16'bx;
			end
		endcase
		
	end
	
endmodule: alu
