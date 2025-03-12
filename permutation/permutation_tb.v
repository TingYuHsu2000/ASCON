`timescale 1ns/1ns

module tb_permutation;

    reg clk;
    reg rst;
    reg [319:0] S;
    reg [4:0] round;
    reg start;
    wire [319:0] S_out;

    // Instantiate the permutation module
    permutation uut (
        .clk(clk),
        .rst(rst),
        .S(S),
        .round(round),
        .start(start),
        .S_out(S_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 ns period
    end

    // Test sequence
    initial begin
        // Initialize signals
        rst = 1;
        start = 0;
        S = 320'b0;
        round = 5'd0;

        // Reset the system
        #20 rst = 0;

        // Test Case 1: Provide initial values and start the permutation
        #10;
        S = {64'd9241399655273594880, 64'd45400375717294337, 64'd16688268966856064344, 64'd3724962908607778966, 64'd5511705892194216375};
        round = 5'd6; // Set the round count
        start = 1;

        #10 start = 0; // De-assert start signal
        #40 S = 320'd0;

        // Wait for completion (assuming the permutation takes multiple cycles)
        #500;

        // Check the final state
        if (S_out === 320'hdbfa7de9557bfe77cd1ee5a28bf38302ddaaba10f9bbc338f08f66dfae56028e3c3fa37c30f578a4) begin
            $display("Test Passed: Final State is correct.");
            $display("Final State: %h", S_out);
            $display("X0: %h", S_out[319:256]);
            $display("X1: %h", S_out[255:192]);
            $display("X2: %h", S_out[191:128]);
            $display("X3: %h", S_out[127:64]);
            $display("X4: %h", S_out[63:0]);
        end else begin
            $display("Test Failed: Final State is incorrect.");
            $display("Actual Final State: %h", S_out);
        end

        // End simulation
        $finish;
    end

    // Generate VCD file for waveform
    initial begin
        $dumpfile("permutation.vcd");
        $dumpvars(0, tb_permutation);
    end

endmodule
