// Paul-John Clet
// Advanced Computer Architecture - Project 2
// Superscalar Out of Order RISC-V Execution

`timescale 1ns / 1ps

// toplevel module
module superscalar_ooo #(parameter int clock_period = 10) 
		(input logic clk);
	
	// ----- instruction queue (IQ) -----
	
	// signals for IQ
	logic dispatch_1_ready, dispatch_2_ready, instr_queue_empty;
	logic [31:0] instr1, instr2;
	
	// IQ module
	instr_queue iq (.clk(clk), .dispatch_1_ready(dispatch_1_ready), .dispatch_2_ready(dispatch_2_ready), .instr1(instr1), .instr2(instr2), .instr_queue_empty(instr_queue_empty));
	
	// ----- end instruction queue (IQ) -----
	
	// ----- dispatch units (du1 & du2) -----
	
	// signals for du1 & du2
	// betw adder fu rs
	logic [3:0] adder_rs, mul_rs; 						// for RESERVATION STATION (shared) - may have to be a net
	logic [1:0] adder_count_free, mul_count_free;		// for RESERVATION STATION (shared) - may have to be a net
	logic du_1_add_valid_overwrite, du_1_mul_valid_overwrite, du_2_add_valid_overwrite, du_2_mul_valid_overwrite; 
	logic [2:0] du_1_add_overwrite, du_1_mul_overwrite, du_2_add_overwrite, du_2_mul_overwrite; 

	// between dispatch units
	logic [2:0] du_1_tag, du_2_tag;
	logic du_1_ready, du_1_final_check, du_2_ready, du_2_final_check;
	logic [4:0] du_1_rs1, du_1_rs2, du_1_rd, du_2_rs1, du_2_rs2, du_2_rd;

	// final output to the RAT
	logic [4:0] du_1_final_rs1, du_1_final_rs2, du_1_final_rd, du_2_final_rs1, du_2_final_rs2, du_2_final_rd;
	logic [2:0] du_1_final_tag, du_2_final_tag;
	logic du_1_valid_RAT_instruction, du_2_valid_RAT_instruction;
	
	dispatch #(.dispatch_has_priority(1'b1)) du1
		  (.clk(clk), .instr_in(instr1), .dispatch_ready(dispatch_1_ready), .adder_rs(adder_rs), .adder_count_free(adder_count_free),
			.add_valid_overwrite(du_1_add_valid_overwrite), .add_overwrite(du_1_add_overwrite), .mul_rs(mul_rs), .mul_count_free(mul_count_free),
			.mul_valid_overwrite(du_1_mul_valid_overwrite), .mul_overwrite(du_1_mul_overwrite), .received_tag(du_2_tag), .other_dispatch_ready(du_2_ready),
			.received_final_check(du_2_final_check), .received_rs1(du_2_rs1), .received_rs2(du_2_rs2), .received_rd(du_2_rd), .tag(du_1_tag), 
			.dispatch_processed(du_1_ready), .final_check(du_1_final_check), .output_rs1(du_1_rs1), .output_rs2(du_1_rs2), .output_rd(du_1_rd),
			.final_rs1(du_1_final_rs1), .final_rs2(du_1_final_rs2), .final_rd(du_1_final_rd), .final_tag(du_1_final_tag), .valid_RAT_instruction(du_1_valid_RAT_instruction),
			.instr_queue_empty(instr_queue_empty));
						
	dispatch #(.dispatch_has_priority(1'b0)) du2
		  (.clk(clk), .instr_in(instr2), .dispatch_ready(dispatch_2_ready), .adder_rs(adder_rs), .adder_count_free(adder_count_free),
			.add_valid_overwrite(du_2_add_valid_overwrite), .add_overwrite(du_2_add_overwrite), .mul_rs(mul_rs), .mul_count_free(mul_count_free),
			.mul_valid_overwrite(du_2_mul_valid_overwrite), .mul_overwrite(du_2_mul_overwrite), .received_tag(du_1_tag), .other_dispatch_ready(du_1_ready),
			.received_final_check(du_1_final_check), .received_rs1(du_1_rs1), .received_rs2(du_1_rs2), .received_rd(du_1_rd), .tag(du_2_tag), 
			.dispatch_processed(du_2_ready), .final_check(du_2_final_check), .output_rs1(du_2_rs1), .output_rs2(du_2_rs2), .output_rd(du_2_rd),
			.final_rs1(du_2_final_rs1), .final_rs2(du_2_final_rs2), .final_rd(du_2_final_rd), .final_tag(du_2_final_tag), .valid_RAT_instruction(du_2_valid_RAT_instruction),
			.instr_queue_empty(instr_queue_empty));
	
	// ----- end dispatch units (du1 & du2) -----
	
	// ----- register alias table (RAT) -----
	
	// RAT signals
	wire logic add_bus_valid_output, mul_bus_valid_output;
	wire logic [2:0] add_broadcasted_tag, mul_broadcasted_tag;
	wire logic [31:0] add_broadcasted_value, mul_broadcasted_value;
	
	wire logic bus_valid_output;
	wire logic [2:0] broadcasted_tag;
	wire logic [31:0] broadcasted_value;


	// betw. add reservation station
	logic [31:0] add_rs1_data, add_rs2_data, mul_rs1_data, mul_rs2_data;
	logic [1:0] add_index, mul_index;
	logic add_valid_instruction, mul_valid_instruction;
	
	register_alias_table RAT (.clk(clk), .add_bus_valid_output(add_bus_valid_output), .add_broadcasted_tag(add_broadcasted_tag), .add_broadcasted_value(add_broadcasted_value), 
		.mul_bus_valid_output(mul_bus_valid_output), .mul_broadcasted_tag(mul_broadcasted_tag), .mul_broadcasted_value(mul_broadcasted_value),
		.du1_rs1(du_1_rs1), .du1_rs2(du_1_rs2), 
		.du1_rd(du_1_rd), .du1_tag(du_1_tag), .du1_received_instruction(du_1_valid_RAT_instruction),  .du2_rs1(du_2_rs1), .du2_rs2(du_2_rs2), 
		.du2_rd(du_2_rd), .du2_tag(du_2_tag), .du2_received_instruction(du_2_valid_RAT_instruction), .add_rs1_data(add_rs1_data), .add_rs2_data(add_rs2_data),
		.add_index(add_index), .add_valid_instruction(add_valid_instruction), .mul_rs1_data(mul_rs1_data), .mul_rs2_data(mul_rs2_data), .mul_index(mul_index),
		.mul_valid_instruction(mul_valid_instruction));
	
	// ----- end register alias table (RAT) -----
	
	// ----- reservation stations (rs) -----
	
	// rs signals
	logic adder_unit_ready, mul_unit_ready;
	logic [2:0] rs_add_instruction_tag, rs_mul_instruction_tag;
	logic [31:0] rs_add_a, rs_add_b, rs_mul_a, rs_mul_b;
	logic rs_add_new_instruction, rs_mul_new_instruction;
	
	reservation_station #(.add_or_mul(1'b0)) rs_add
		(.clk(clk), .bus_valid_output(add_bus_valid_output), .broadcasted_tag(add_broadcasted_tag), .broadcasted_value(add_broadcasted_value), .functional_unit_ready(adder_unit_ready),
		.instruction_tag(rs_add_instruction_tag), .a(rs_add_a), .b(rs_add_b), .new_instruction(rs_add_new_instruction), .rs_slots(adder_rs), .rs_count(adder_count_free),
		.du_2_valid_overwrite(du_2_add_valid_overwrite), .du_2_overwrite(du_2_add_overwrite), .rs1_data(add_rs1_data), .rs2_data(add_rs2_data), .instruction_index(add_index), 
		.received_valid_instruction(add_valid_instruction));
	
	reservation_station #(.add_or_mul(1'b1)) rs_mul
		(.clk(clk), .bus_valid_output(mul_bus_valid_output), .broadcasted_tag(mul_broadcasted_tag), .broadcasted_value(mul_broadcasted_value), .functional_unit_ready(mul_unit_ready),
		.instruction_tag(rs_mul_instruction_tag), .a(rs_mul_a), .b(rs_mul_b), .new_instruction(rs_mul_new_instruction), .rs_slots(mul_rs), .rs_count(mul_count_free),
		.du_2_valid_overwrite(du_2_mul_valid_overwrite), .du_2_overwrite(du_2_mul_overwrite), .rs1_data(mul_rs1_data), .rs2_data(mul_rs2_data), .instruction_index(mul_index), 
		.received_valid_instruction(mul_valid_instruction));
	
	// ----- end reservation stations (rs) -----
	
	// ----- functional units (add or mul) -----
	
	functional_unit #(.add_or_mul(1'b0), .clock_period(clock_period)) adder 
		(.clk(clk), .new_instruction(rs_add_new_instruction), .a(rs_add_a), .b(rs_add_b), .instruction_tag(rs_add_instruction_tag), .ready(adder_unit_ready),
		.broadcasted_tag(add_broadcasted_tag), .broadcasted_value(add_broadcasted_value), .bus_valid_output(add_bus_valid_output));
		
	functional_unit #(.add_or_mul(1'b1), .clock_period(clock_period)) mul 
		(.clk(clk), .new_instruction(rs_mul_new_instruction), .a(rs_mul_a), .b(rs_mul_b), .instruction_tag(rs_mul_instruction_tag), .ready(mul_unit_ready),
		.broadcasted_tag(mul_broadcasted_tag), .broadcasted_value(mul_broadcasted_value), .bus_valid_output(mul_bus_valid_output));
endmodule
