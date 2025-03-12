module permutation (
    input              clk,
    input              rst,
    input      [319:0] S,
    input      [4:0]   round,
    input              start,
    output reg [319:0] S_out,
    output reg         fin  
);

reg [63:0] x0, x1, x2, x3, x4;
reg [63:0] x2_pc;
reg [63:0] x0_ps, x1_ps, x2_ps, x3_ps, x4_ps;
reg [4:0] counter;
integer i;

// FSM
reg [2:0]st, nst;
parameter IDLE = 'd0;
parameter IN   = 'd1;
parameter PC   = 'd2;
parameter PS   = 'd3;
parameter PL   = 'd4;
parameter OUT  = 'd5;

always @(posedge clk) begin
    if (rst) st <= IDLE;
    else     st <= nst;
end

always @(*) begin
    case(st) 
        IDLE: nst = (start)?IN:IDLE;
        IN:   nst = PC;
        PC:   nst = PS;
        PS:   nst = PL;
        PL:   nst = (counter==round)? OUT : PC ;
        OUT:  nst = IN;
        default: nst = IN;
    endcase
end

wire [63:0] Cr [11:0];
    assign Cr[0] = 64'hf0;
    assign Cr[1] = 64'he1;
    assign Cr[2] = 64'hd2;
    assign Cr[3] = 64'hc3;
    assign Cr[4] = 64'hb4;
    assign Cr[5] = 64'ha5;
    assign Cr[6] = 64'h96;
    assign Cr[7] = 64'h87;
    assign Cr[8] = 64'h78;
    assign Cr[9] = 64'h69;
    assign Cr[10] = 64'h5a;
    assign Cr[11] = 64'h4b;
wire [4:0] const[31:0];
    assign const[0]  = 5'h4;
    assign const[1]  = 5'hb;
    assign const[2]  = 5'h1f;
    assign const[3]  = 5'h14;
    assign const[4]  = 5'h1a;
    assign const[5]  = 5'h15;
    assign const[6]  = 5'h9;
    assign const[7]  = 5'h2;
    assign const[8]  = 5'h1b;
    assign const[9]  = 5'h5;
    assign const[10] = 5'h8;
    assign const[11] = 5'h12;
    assign const[12] = 5'h1d;
    assign const[13] = 5'h3;
    assign const[14] = 5'h6;
    assign const[15] = 5'h1c;
    assign const[16] = 5'h1e;
    assign const[17] = 5'h13;
    assign const[18] = 5'h7;
    assign const[19] = 5'he;
    assign const[20] = 5'h0;
    assign const[21] = 5'hd;
    assign const[22] = 5'h11;
    assign const[23] = 5'h18;
    assign const[24] = 5'h10;
    assign const[25] = 5'hc;
    assign const[26] = 5'h1;
    assign const[27] = 5'h19;
    assign const[28] = 5'h16;
    assign const[29] = 5'ha;
    assign const[30] = 5'hf;
    assign const[31] = 5'h17;


always @(posedge clk or posedge rst) begin
    if (rst) begin
        {x0, x1, x2, x3, x4, x2_pc} <= 64'd0;
        {x0_ps, x1_ps, x2_ps, x3_ps, x4_ps} <= 64'd0;
        S_out <= 320'd0;
        counter <= 5'd0;
    end 

    else if (st==IN) begin
        {x0, x1, x2, x3, x4} <= S; // S = x0 || x1 || x2 || x3 || x4 //將Ｓ拆分成多個訊號，自動定義等長 
        {x0_ps, x1_ps, x2_ps, x3_ps, x4_ps} <= 64'd0;
    end
    

    // Addition of Constants
    else if (st==PC) begin
        //if (round == 6)      x2_pc <= x2 ^ (8'h96 - (counter - 1'd1) * 4'd15);
        //else if (round == 8) x2_pc <= x2 ^ (8'hb4 - (counter - 1'd1) * 4'd15);
        //else                 x2_pc <= x2 ^ (8'hf0 - (counter - 1'd1) * 4'd15);
        if (round == 5'd12)     x2_pc <= x2 ^ Cr[counter];
        else if (round == 5'd8) x2_pc <= x2 ^ Cr[counter+5'd4];
        else if (round == 5'd6) x2_pc <= x2 ^ Cr[counter+5'd6];
        else x2_pc <= x2;
        counter <= counter +1'd1;
    end

    // Substitution Layer
    else if (st==PS) begin
        for (i=0;i<64;i=i+1) begin
            {x0_ps[i], x1_ps[i], x2_ps[i], x3_ps[i], x4_ps[i]} <= const[{x0[i], x1[i], x2_pc[i], x3[i], x4[i]}];
        end
    end

    // Linear Diffusion Layer 環狀
    else if (st == PL) begin
    x0 <= x0_ps ^ (x0_ps >> 19) ^ (x0_ps >> 28) ^ (x0_ps << (64 - 19)) ^ (x0_ps << (64 - 28));
    x1 <= x1_ps ^ (x1_ps >> 61) ^ (x1_ps >> 39) ^ (x1_ps << (64 - 61)) ^ (x1_ps << (64 - 39));
    x2 <= x2_ps ^ (x2_ps >> 1)  ^ (x2_ps >> 6)  ^ (x2_ps << (64 - 1))  ^ (x2_ps << (64 - 6));
    x3 <= x3_ps ^ (x3_ps >> 10) ^ (x3_ps >> 17) ^ (x3_ps << (64 - 10)) ^ (x3_ps << (64 - 17));
    x4 <= x4_ps ^ (x4_ps >> 7)  ^ (x4_ps >> 41) ^ (x4_ps << (64 - 7))  ^ (x4_ps << (64 - 41));
    end
    else if (st==OUT) begin
        S_out <= {x0, x1, x2, x3, x4};
    end
    else begin
        x0 <= x0;
        x1 <= x1;
        x2 <= x2;
        x3 <= x3;
        x4 <= x4;
        x2_pc <= x2_pc;
        x0_ps <= x0_ps;
        x1_ps <= x1_ps;
        x2_ps <= x2_ps;
        x3_ps <= x3_ps;
        x4_ps <= x4_ps;
        counter <= counter;
    end
end

// signal done
always @(posedge clk or posedge rst) begin
    if (rst) fin <=1'd0;
    else if (st==OUT) fin <=1'd1;
    else fin <=1'd0;
end


endmodule