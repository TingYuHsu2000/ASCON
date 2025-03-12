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
    wire [319:0] ini_stemp, ad_stemp, pt_stemp;

    // Timeout variable
    integer timeout;

    // Instantiate the encryption module
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
        .tag(tag),
        .ini_stemp(ini_stemp),
        .ad_stemp(ad_stemp),
        .pt_stemp(pt_stemp)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    // Monitor State Transitions and Debugging Information
    always @(posedge clk) begin
    end

    // Test sequence
    initial begin
        rst_n = 0;
        start = 0;
        key = 128'hb7234a4db9fb8b7c2aa5735ebef1180c;
        nonce = 128'h8ebb295da81c74b58306d4e8362e2242;
        associated_data = 40'h4153434f4e; 
        plaintext = 40'h6173636f6e;

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
        $display("Key: %h", key);
        $display("Nonce: %h", nonce);
        $display("Associated Data: %h", associated_data);
        $display("Plaintext: %h", plaintext);
        $display("--------------------------------------------");       
        // Display results
        $display("S after initial: %h", ini_stemp);
        $display("S after ad: %h", ad_stemp);
        $display("S after pt: %h", pt_stemp);
        $display("--------------------------------------------"); 
        $display("Final Ciphertext: %h", ciphertext);
        $display("Final Tag: %h", tag);
        

        
        #100;
        $finish;
    end

    // VCD dump
    initial begin
        $dumpfile("encryption.vcd");
        $dumpvars(0, encryption_tb);
    end
endmodule
