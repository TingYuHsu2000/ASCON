`timescale 1ns / 1ns

module encryption_tb;
    reg clk;
    reg rst_n;
    reg start;
    reg [127:0] key;
    reg [127:0] nonce;
    reg [39:0] associated_data; 
    reg [39:0] plaintext;       
    wire encryption_fin;
    wire [39:0] ciphertext;
    wire [127:0] tag;

    // Timeout variable declared at the module level
    integer timeout;

    // Instantiate the ASCON module
    encryption encryption (
        .clk(clk),
        .rst(rst_n),
        .encryption_start(start),
        .key(key),
        .nonce(nonce),
        .ad(associated_data),
        .pt(plaintext),
        .encryption_fin(encryption_fin),
        .ct(ciphertext),
        .tag(tag)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    // Test sequence
        initial begin
        rst_n = 0;
        start = 0;
        key             = 128'h3ffa75efbd1705fa8f9ced62e5bb0be3;
        nonce           = 128'h9691163337dd55217ea2a6b21eaa19b2;
        associated_data = 40'h4153434f4e; 
        plaintext       = 40'h6173636f6e;

        #10;
        rst_n = 1;
        #10;
        start = 1;
        rst_n = 0;
        #10;
        start = 0;

        timeout = 0; 
        while (~encryption_fin && timeout < 100000) begin
            #10;  
            timeout = timeout + 10;  
        end

        // Check for timeout
        //if (timeout >= 100000) begin
        //    $display("Simulation failed: Encryption timeout!");
        //    $finish;
        //end 
        $display("-----------------------------------------");
        $display("Key: %h",key);
        $display("Npub: %h",nonce);
        $display("Associated Data: %h",associated_data);
        $display("plaintext: %h",plaintext);
        $display("-----------------------------------------");
        // Display and validate results
        
        $display("Ciphertext: %h", ciphertext);
        $display("Tag: %h", tag);
        $display("-----------------------------------------");

        //if (ciphertext === 40'h80cdf888e3 && tag === 128'h741c60eea203c9449aa7f6b9adde1dee) begin
        //    $display("Simulation passed: Encryption correct!");
        //end else begin
        //    $display("Simulation failed: Incorrect result!");
        //    $display("Expected Ciphertext: 80cdf888e3");
        //    $display("Expected Tag: 741c60eea203c9449aa7f6b9adde1dee");
        //end

        #100;
        $finish;
    end

    // VCD
    initial begin
        $dumpfile("encryption.vcd");
        $dumpvars(0, encryption_tb);
    end
endmodule