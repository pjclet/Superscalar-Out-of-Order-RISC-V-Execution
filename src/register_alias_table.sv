// Paul-John Clet2
// Advanced Computer Architecture - Project 2
// Superscalar Out of Order RISC-V Execution

`timescale 1ns / 1ps

module register_alias_table(input logic clk, 
									// bus
									input logic add_bus_valid_output, mul_bus_valid_output,
									input logic [2:0] add_broadcasted_tag, mul_broadcasted_tag,
									input logic [31:0] add_broadcasted_value, mul_broadcasted_value,
									
									// betw. disp unit 1
									input logic [4:0] du1_rs1, du1_rs2, du1_rd,
									input logic [2:0] du1_tag,
									input logic du1_received_instruction,
									
									// betw. disp unit 2
									input logic [4:0] du2_rs1, du2_rs2, du2_rd,
									input logic [2:0] du2_tag,
									input logic du2_received_instruction,
									
									// betw. add reservation station
									output logic [31:0] add_rs1_data, add_rs2_data, 
									output logic [1:0] add_index, 
									output logic add_valid_instruction,
									
									// betw. mul reservation station
									output logic [31:0] mul_rs1_data, mul_rs2_data,
									output logic [1:0] mul_index,
									output logic mul_valid_instruction
									);
	
	// adder address will have a 0 in the beginning of the ID to make a unique tag that is 3 bits
	// multiplier will have a 1 in the beginning of the ID
	
	// 32 registers
	// bits for each entry - 0 for index or register number + 1 for valid bit + 3 for tag + 32 for each integer = 36 bits
	// breakdown: 35 = valid, 34:32 = tag, 31:0 = value
	logic [35:0] RAT [31:0];
	
	initial begin
		// initialize data to simplify load and store operations
		// registers are valid, and each register has its respective value
		for (int i = 0; i < 32; i++) begin
			RAT[i][35] = 1'b1; // set the valid bit
			// leave [34:32] to nothing
			RAT[i][31:0] = i;
			$display("[RAT] Set register %0d to value %0d", i, RAT[i][31:0]);
		end
		add_valid_instruction <= 1'b0; mul_valid_instruction <= 1'b0;
		add_rs1_data <= 32'b0; add_rs2_data <= 32'b0;
		mul_rs1_data <= 32'b0; mul_rs2_data <= 32'b0;
		add_index <= 2'b0; mul_index <= 2'b0;
		
	end
	
	// check if there is a tag before writing the data to the register
	logic instr1_success, instr2_success;
	
	// dispatch units 1 and 2 check
	always @(du1_received_instruction || du2_received_instruction || add_bus_valid_output || mul_bus_valid_output) begin
		// adder - if you hear a change on the bus, then check for matches and update the value
		if (add_bus_valid_output) begin
			for (int i = 0; i < 32; i++) begin
			// if this is an invalid entry and if the tag matches the broadcasted tag
				if (RAT[i][35] == 1'b0 && RAT[i][34:32] == add_broadcasted_tag) begin
					
					RAT[i][35] = 1'b1; 						// set to valid
					RAT[i][34:32] = 3'b0;
					RAT[i][31:0] = add_broadcasted_value; 	// update the value
					
				end
			end
		end 
		// mul - if you hear a change on the bus, then check for matches and update the value
		else if (mul_bus_valid_output) begin
			for (int i = 0; i < 32; i++) begin
			// if this is an invalid entry and if the tag matches the broadcasted tag
				if (RAT[i][35] == 1'b0 && RAT[i][34:32] == mul_broadcasted_tag) begin
					
					RAT[i][35] = 1'b1; 						// set to valid
					RAT[i][34:32] = 3'b0;
					RAT[i][31:0] = mul_broadcasted_value; 	// update the value
					
				end
			end
		end  

		// check for instruction from the du1
		else if (du1_received_instruction && ~du2_received_instruction) begin
			// update the destination register
			RAT[du1_rd] <= {1'b0, du1_tag, 32'b0};
			
			// send the data from rs1 and rs2 to the respective functional unit
			// send to add reservation station
			if (~du1_tag[2]) begin
				$display("[RAT] Sending add instruction from dispatch unit 1.");
				add_rs1_data <= RAT[du1_rs1];
				add_rs2_data <= RAT[du1_rs2];
				add_index <= du1_tag[1:0];
				add_valid_instruction <= 1'b1;  #1; add_valid_instruction <= 1'b0;
			end
			// send to mul reservation station
			else begin
				$display("[RAT] Sending mul instruction from dispatch unit 1.");
				mul_rs1_data <= RAT[du1_rs1];
				mul_rs2_data <= RAT[du1_rs2];
				mul_index <= du1_tag[1:0];
				mul_valid_instruction <= 1'b1; #1; mul_valid_instruction <= 1'b0;
			end


		end
		
		else if (du2_received_instruction && ~du1_received_instruction) begin
			// update the destination register
			RAT[du2_rd] <= {1'b0, du2_tag, 32'b0};
			
			// send the data from rs1 and rs2 to the respective functional unit
			// send to add reservation station
			if (~du2_tag[2]) begin
				$display("[RAT] Sending add instruction from dispatch unit 2.");
				add_rs1_data <= RAT[du2_rs1];
				add_rs2_data <= RAT[du2_rs2];
				add_index <= du2_tag[1:0];
				add_valid_instruction <= 1'b1;  #2; add_valid_instruction <= 1'b0;
			end
			// send to mul reservation station
			else begin
				$display("[RAT] Sending mul instruction from dispatch unit 2.");
				mul_rs1_data <= RAT[du2_rs1];
				mul_rs2_data <= RAT[du2_rs2];
				mul_index <= du2_tag[1:0];
				mul_valid_instruction <= 1'b1; #2; mul_valid_instruction <= 1'b0;
			end
		end
	end
	
	// print the output of the adder bus
	always @(posedge add_bus_valid_output) begin
		// display the output of the reservation station
		for (int i=0; i<19; i++) begin
			$display("%d - %b - %b - %b",i, RAT[i][35], RAT[i][34:32], RAT[i][31:0]);
		end
	end
	
	// print the output of the multiplier bus
	always @(posedge mul_bus_valid_output) begin
		// display the output of the reservation station
		for (int i=0; i<19; i++) begin
			$display("%d - %b - %b - %b",i, RAT[i][35], RAT[i][34:32], RAT[i][31:0]);
		end
	end
endmodule
