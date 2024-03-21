// Paul-John Clet
// Advanced Computer Architecture - Project 2
// Superscalar Out of Order RISC-V Execution

`timescale 1ns / 1ps

// reservation station module

module reservation_station #(parameter logic add_or_mul) // 0 for adder, 1 for multiplier
									(input logic clk, bus_valid_output,
									 input logic [2:0] broadcasted_tag,
									 input logic [31:0] broadcasted_value,
									 
									 // betw functional unit
									 input logic functional_unit_ready,
									 output logic [2:0] instruction_tag,
									 output logic [31:0] a,b,
									 output logic new_instruction,
										
									 // betw dispatch
									 output logic [3:0] rs_slots,
									 output logic [1:0] rs_count,
									 
									 input logic du_2_valid_overwrite,
									 input logic [5:0] du_2_overwrite,
									 
									 // betw RAT
									 input logic [31:0] rs1_data, rs2_data, 
									 input logic [1:0] instruction_index, 
									 input logic received_valid_instruction
									 );
	
	
	localparam int num_RS_entries = 4;
	
	// intermediate signals
	logic [3:0] [71:0] RS;
	logic [2:0] no_tag_code = {~add_or_mul, ~add_or_mul, ~add_or_mul}; // this code tells the system whether or not is has been overwritten by the dispatch unit
	
	initial begin
		// reservation station is initially empty
		for (int i = 0; i < num_RS_entries; i++) begin
			RS[i] = {1'b0, no_tag_code, 32'b0, 1'b0, no_tag_code, 32'b0}; // empty value code
			$display("[RS %s] Set %0d = %b.", (add_or_mul ? "MUL" : "ADD"), i, RS[i]);
		end
		
		rs_count = 2'b0; 	// set the count
		rs_slots = 4'b0000; // tell the dispatch unit that all slots are open
		new_instruction <= 1'b0;
	end
	
	// every clock cycle try to issue an instruction to the functional unit
	always @(posedge clk) begin
		// if the unit is ready
		if (functional_unit_ready) begin
			$display("[RS %s] Attempting to issue a new instruction.", (add_or_mul ? "MUL" : "ADD"));
			for (int i = 0; i < num_RS_entries; i++) begin
				if (RS[i][71] && RS[i][35]) begin
					// start the instruction
					instruction_tag = {add_or_mul, 2'(i)}; // may have to use a temporary register here? 
					a = RS[i][67:36]; b = RS[i][31:0]; // set the operands
					new_instruction = 1'b1; #2; new_instruction = 1'b0; // toggle the instruction to valid
					
					$display("[RS %s] Issued a new instruction.", (add_or_mul ? "MUL" : "ADD"));
					break; // only set one
				end 
			end
		end
	end
	
	
	// combine all the racing conditions
	always @(bus_valid_output || received_valid_instruction || du_2_valid_overwrite) begin
		// if you hear a change on the bus, then check for matches and update the value
		if (bus_valid_output) begin
			
			$display("Checking %b against %b", broadcasted_tag[2], add_or_mul);
			// check if your value finished to remove the data and set the values to default
			if (broadcasted_tag[2] == add_or_mul) begin
				$display("[RS %s] Heard that my functional unit's instruction finished.", (add_or_mul ? "MUL" : "ADD"));
				// broadcasted_tag[1:0] is the index in this reservation station to reset
				RS[broadcasted_tag[1:0]] = {1'b0, no_tag_code, 32'b0, 1'b0, no_tag_code, 32'b0}; // set to empty value code
				rs_count = rs_count - 2'b1; 	// subtract 1 from the count
				rs_slots[broadcasted_tag[1:0]] = 1'b0; 			// free this slot
			end
		
			for (int i = 0; i < num_RS_entries; i++) begin
				// if this is an invalid entry and if the tag matches the broadcasted tag
				if (RS[i][71] == 1'b0 && RS[i][70:68] == broadcasted_tag) begin
					
					RS[i][71] = 1'b1; // set to valid
					RS[i][67:36] = broadcasted_value; // update the value
				
				end else if (RS[i][35] == 1'b0 && RS[i][34:32] == broadcasted_tag) begin
					
					RS[i][35] = 1'b1; // set to valid
					RS[i][31:0] = broadcasted_value; // update the value
				
				end
			end
		end
		
		// check for a new instruction
		else if (received_valid_instruction) begin
			$display("[RS %s] Received a new instruction.", (add_or_mul ? "MUL" : "ADD"));
		
			// check if the current entry has a tag and is invalid
			// rs1
			if (RS[instruction_index][70:68] == no_tag_code) begin
				RS[instruction_index][67:36] = rs1_data; // load the data
				RS[instruction_index][71] = 1'b1; 			// set the valid bit
			end
			
			// rs2
			if (RS[instruction_index][34:32] == no_tag_code) begin
				RS[instruction_index][31:0] = rs2_data; 	// load the data
				RS[instruction_index][35] = 1'b1; 			// set the valid bit
			end
			
			$display("[RS %s] Received a new instruction, set the index: %0d = %0d | %0d (%b|%b).", (add_or_mul ? "MUL" : "ADD"), instruction_index, RS[instruction_index][67:36], RS[instruction_index][31:0],RS[instruction_index][71], RS[instruction_index][35]);
			#6;
			// for dispatch
			rs_slots[instruction_index] = 1'b1; 			// fill this slot
			rs_count = rs_count + 2'b1; 						// add one to the count
		end 
		
		// check for an overwrite
		else if (du_2_valid_overwrite) begin
			// check if sending to rs1 
			if (~du_2_overwrite[5]) begin
				RS[du_2_overwrite[4:3]][71:36] = {1'b0, du_2_overwrite[2:0], 32'b0};
			end 
			// sending to rs2
			else begin
				RS[du_2_overwrite[4:3]][35:0] = {1'b0, du_2_overwrite[2:0], 32'b0};
			end
			
		end
	end
endmodule
