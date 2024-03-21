// Paul-John Clet
// Advanced Computer Architecture - Project 2
// Superscalar Out of Order RISC-V Execution

`timescale 1ns / 1ps

module testbench #(parameter int clock_period = 10);

	logic clk;
	int cycle;

	// instantiate device to be tested
	superscalar_ooo  #(.clock_period(clock_period)) dut (.clk(clk));
	
	initial begin
		$display("[Testbench] Initialized.");
		cycle = 0;
		clk = 1'b0;
	end

	// generate clock to sequence testss
	always begin
		#(clock_period);  // can divide by 2 here
		clk = ~clk; 
	end

	// output clock cycles
	always @(posedge clk) begin
		$display("------------------------- [CLK] Cycle #%0d -------------------------", cycle);
		cycle = cycle + 1;
	end
endmodule
