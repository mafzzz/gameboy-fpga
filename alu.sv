`include "constants.sv"

module alu
	(input logic [7:0]	op_A,
	input logic [7:0]	op_B,
	input alu_op_t		op_code,
	input logic [3:0]	curr_flags,
	output logic [3:0]	next_flags,
	output logic [7:0]	alu_result,
	output logic [15:0]	addr_result);
	
	always_comb begin 
		
		unique case (op_code)
			
			alu_NOP: begin
				alu_result = 8'bx;
				addr_result = 16'bx;
				next_flags = curr_flags;
			end
			alu_AB: begin
				alu_result = 8'bx;
				addr_result = {op_A, op_B};
				next_flags = curr_flags;
			end
			alu_B: begin
				alu_result = op_B;
				addr_result = 16'bx;
				next_flags = curr_flags;
			end				
			alu_ADD: begin
				{next_flags[0], alu_result} = op_A + op_B;
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = {{1'b0, op_A[3:0]} + {1'b0, op_B[3:0]}}[4];
				addr_result = 16'bx;
				next_flags[2] = 1'b0;
			end
			alu_ADC: begin
				{next_flags[0], alu_result} = op_A + op_B + curr_flags[0];
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = {{1'b0, op_A[3:0]} + {1'b0, op_B[3:0]}}[4];
				addr_result = 16'bx;
				next_flags[2] = 1'b0;
			end
			alu_SUB: begin
				{next_flags[0], alu_result} = op_A - op_B;
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = {{1'b0, op_A[3:0]} - {1'b0, op_B[3:0]}}[4];
				addr_result = 16'bx;
				next_flags[2] = 1'b1;
			end
			alu_SBC: begin
				{next_flags[0], alu_result} = op_A - op_B - curr_flags[0];
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = {{1'b0, op_A[3:0]} - {1'b0, op_B[3:0]}}[4];
				addr_result = 16'bx;
				next_flags[2] = 1'b1;
			end
			alu_AND: begin
				alu_result = op_A & op_B;
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:0] = 3'b010;
			end
			alu_OR: begin
				alu_result = op_A | op_B;
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:0] = 3'b000;
			end
			alu_XOR: begin
				alu_result = op_A ^ op_B;
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:0] = 3'b000;
			end
			alu_INC: begin
				alu_result = 7'h01 + op_B;
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = {{1'b0, 4'h1} + {1'b0, op_B[3:0]}}[4];
				addr_result = 16'bx;
				next_flags[2] = 1'b0;
				next_flags[0] = curr_flags[0];
			end
			alu_DEC: begin
				alu_result = op_B - 7'h01;
				next_flags[3] = (alu_result == 8'b0);
				next_flags[1] = {{1'b0, op_B[3:0]} - {1'b0, 4'h1}}[4];
				addr_result = 16'bx;
				next_flags[2] = 1'b1;
				next_flags[0] = curr_flags[0];
			end
			alu_SWAP: begin
				alu_result = {op_B[3:0], op_B[7:4]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:0] = 3'b0;
			end
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
			alu_CPL: begin 
				alu_result = ~op_B;
				addr_result = 16'bx;
				next_flags = curr_flags;
				next_flags[2:1] = 2'b11;
			end
			alu_RLC: begin 
				{next_flags[0], alu_result} = {op_B[7], op_B[6:0], op_B[7]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
			alu_RL: begin
				{next_flags[0], alu_result} = {op_B[7], op_B[6:0], curr_flags[0]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
			alu_RRC: begin
				{next_flags[0], alu_result} = {op_B[0], op_B[0], op_B[7:1]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
			alu_RR: begin
				{next_flags[0], alu_result} = {op_B[0], curr_flags[0], op_B[7:1]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
			alu_SLA: begin
				{next_flags[0], alu_result} = {op_B[7], op_B << 1};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
			alu_SRA: begin
				{next_flags[0], alu_result} = {op_B[0], op_B[7], op_B[7:1]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
			alu_SRL: begin
				{next_flags[0], alu_result} = {op_B[0], 1'b0, op_B[7:1]};
				next_flags[3] = (alu_result == 8'b0);
				addr_result = 16'bx;
				next_flags[2:1] = 2'b00;
			end
	
			alu_UNK: begin
				alu_result = 8'bx;
				addr_result = 16'bx;
				next_flags = 16'bx;
			end
		endcase
		
	end
	
endmodule: alu