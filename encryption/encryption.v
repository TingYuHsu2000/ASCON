module encryption #(
    parameter k = 128,   // Key size
    parameter r = 64,    // Rate
    parameter a = 12,    // Initialization and finalization round number
    parameter b = 6,     // Intermediate round number
    parameter al = 40,   // Associated data length (ASCON example)
    parameter pl = 40   // Plaintext length (ascon example)
)(
    input clk, 
    input rst,
    input [k-1:0] key,
    input [127:0] nonce,
    input [al-1:0] ad, // Associated data
    input [pl-1:0] pt, // Plaintext
    input encryption_start,

    output [pl-1:0] ct, // Ciphertext
    output [127:0] tag, // Authentication tag
    output encryption_fin,
    output reg [319:0] ini_stemp, ad_stemp, pt_stemp
);

// Internal Registers and Wires
reg  [319:0] S;      // State register
reg  [319:0] Pin;
wire [319:0] Pout;  // Permutation output
reg  [319:0] Pout_r; 
reg  [pl-1:0] ct_r;
reg  [127:0] tag_r;
reg  permutation_start;  // Permutation start signal
wire permutation_fin;    // Permutation done signal
reg  [3:0] block_counter;
reg  [4:0] round;    // Round counter

// FSM State Encoding
reg [3:0] state, n_state;
parameter IDLE            = 4'd0;
parameter INITIALIZE      = 4'd1;
parameter ASSOCIATED_DATA = 4'd2;
parameter PLAINTEXT       = 4'd3;
parameter FINALIZE        = 4'd4;
parameter FIN             = 4'd5;

// Initialization Vector
parameter c    = 320 - r; // Capacity
parameter IV   = 64'h80800c0800000000;
wire [r-1:0] Sr;         // Rate part of the state
wire [c-1:0] Sc;         // Capacity part of the state
assign {Sr, Sc} = S;

// Padding calculations for associated data and plaintext
wire [3:0] s,t;

parameter ad_z = ((al+1)%r != 0) ? (r-((al+1)%r)) : 0;
parameter AL   = al + 1 + ad_z;
assign    s    = (AL / r) ; // Associated data blocks // block length =  r

parameter pt_z = ((pl+1)%r != 0) ? (r-((pl+1)%r)) : 0;
parameter PL   = pl + 1 + pt_z;
assign    t    = (PL / r) ; // Plaintext blocks

wire [AL-1:0] A;
wire [PL-1:0] P;
assign A = {ad, 1'b1, {ad_z{1'b0}}};
assign P = {pt, 1'b1, {pt_z{1'b0}}};


// State Transition
always @(posedge clk or posedge rst) begin
    if (rst) state <= IDLE;
    else     state <= n_state;
end

// Next State Logic
always @(*) begin
    case (state) 
        IDLE:            n_state = (encryption_start) ? INITIALIZE : IDLE;
        INITIALIZE:      n_state = (in_finish) ? ASSOCIATED_DATA : INITIALIZE;
        ASSOCIATED_DATA: n_state = (block_counter == s) ? PLAINTEXT : ASSOCIATED_DATA;
        PLAINTEXT:       n_state = (pt_finish) ? FINALIZE : PLAINTEXT;
        FINALIZE:        n_state = (fin_finish) ? FIN : FINALIZE;
        FIN:             n_state = IDLE;
        default:         n_state = IDLE;
    endcase
end

always @(*) begin
    case(state)
        IDLE:            round = 0;
        INITIALIZE:      round = a;
        ASSOCIATED_DATA: round = b;
        PLAINTEXT:       round = b;
        FINALIZE:        round = a;
        FIN:             round = 0;
        default:         round = 0;
    endcase
end

//block_counter
always @(posedge clk) begin
    if (rst) begin
        block_counter <= 'd0;
    end
    else if (state == ASSOCIATED_DATA) begin
        if ((block_counter == s))   block_counter <= 'd0;
        else if ((block_counter < s) &&(permutation_fin))   block_counter <= block_counter +1'b1;
        else                        block_counter <= block_counter;
    end
    else if (state == PLAINTEXT) begin
        if ((block_counter == t-1) && (permutation_fin)) block_counter <= 'd0;
        else if ((block_counter < t-1) &&(permutation_fin)) block_counter <= block_counter + 1'b1;
        else                           block_counter <= block_counter;
    end
    else block_counter <= block_counter;
end

reg in_finish, as_finish,pt_finish,permutation_extend,fin_finish;
always @(posedge clk) begin
    if (rst) in_finish <= 1'b0;
    else if ((state == INITIALIZE) && (permutation_extend)) in_finish <= 1'b1;
    else in_finish <= 1'b0;
end
always @(posedge clk) begin
    if(rst) as_finish <= 1'b0;
    else if ((state == ASSOCIATED_DATA) && (block_counter == s)) as_finish <= 1'b1;
    else as_finish <= 1'b0;
end
always @(posedge clk) begin
    if(rst) pt_finish <= 1'b0;
    else if ((state == PLAINTEXT) && (t==1)) pt_finish <= 1'b1;
    else if ((state == PLAINTEXT) && (!permutation_start) && (block_counter == t-1)) pt_finish <= 1'b1;
    else pt_finish <= 1'b0;
end
always @(posedge clk) begin
    if(rst) permutation_extend <= 1'b0;
    else if (permutation_fin) permutation_extend <= 1'b1;
    else permutation_extend <= 1'b0;
end
always @(posedge clk) begin
    if (rst) fin_finish <= 1'b0;
    else if ((state == FINALIZE) && (permutation_extend)) fin_finish <= 1'b1;
    else fin_finish <= 1'b0;
end



// State Actions
always @(posedge clk or posedge rst) begin
    if (rst) begin
        S     <= 320'd0;
        Pin   <= 320'd0;
        Pout_r <= 320'd0;
        round <= 5'd0;
        permutation_start <= 1'b0;
        ct_r    <= 0;
        tag_r <= 0;
        permutation_extend <=1'b0;
        {ini_stemp, ad_stemp, pt_stemp} <= 960'b0;
    end 
    else begin
        case (state)
            IDLE: begin
                S <= {IV, key, nonce};
                permutation_start <= 1'b0;
                round <= 5'd0;
                tag_r <= 128'd0;
            end

            INITIALIZE: begin
                if (in_finish) begin
                    //P 後
                    S <= Pout_r ^ {{(320-k){1'b0}}, key};
                    permutation_start <= 1'b0; 
                    ini_stemp <= S;
                end 
                else begin
                    //P 前
                    Pin <= S;
                    permutation_start <= 1'b1;
                end
            end

            ASSOCIATED_DATA: begin
                if ((!permutation_start)&&(block_counter < s)) begin
                    // 第一次：設定 Pin 和啟動 permutation
                    Pin <= {(Sr ^ A[AL-1-(block_counter*r)-:r]), Sc};
                    permutation_start <= 1'b1;
                end
                else if ((permutation_extend)&&(block_counter < s)) begin
                    // 第1~(S-1)次     
                    S <= Pout_r;
                    Pin <= {Sr ^ A[AL-1-(block_counter*r)-:r], Sc};
                    permutation_start <= 1'b1;
                end
                else if ((permutation_extend)&&(block_counter == s)) begin
                    S <= Pout_r ^ {{319{1'b0}}, 1'b1};
                    permutation_start <= 1'b0;
                    ad_stemp <= S;
                end
            end
                
            PLAINTEXT: begin
                if (t==1) begin
                    ct_r[PL-1-(block_counter*r) -: r] <= Sr ^ P[PL-1-(block_counter*r) -: r];
                    S <= {Sr ^ P[PL-1-(block_counter*r) -: r] , Sc};
                    pt_stemp <= S;
                end
                // 第一次
                else if ((block_counter < t-1) && (!permutation_start) )begin
                    ct_r[PL-1-(block_counter*r) -: r] <= Sr ^ P[PL-1-(block_counter*r) -: r];
                    Pin <= { Sr ^ P[PL-1-(block_counter*r) -: r] , Sc};
                    permutation_start <=1'b1;
                end
                // 第2～(t-1)次
                else if ((block_counter < t-1) && (permutation_extend) ) begin
                    S <= Pout_r;
                    ct_r[PL-1-(block_counter*r) -: r] <= Sr ^ P[PL-1-(block_counter*r) -: r];
                    Pin <=  {Sr ^ P[PL-1-(block_counter*r) -: r] , Sc};
                    permutation_start <=1'b1;
                end
                // 第 t 次
                else if ((block_counter == t-1) && (permutation_extend) ) begin
                    S <= Pout_r;
                    ct_r[PL-1-(block_counter*r) -: r] <= Sr ^ P[PL-1-(block_counter*r) -: r];
                    S <= {Sr ^ P[PL-1-(block_counter*r) -: r] , Sc}; 
                    permutation_start <=1'b0;
                    pt_stemp <= S;
                end
            end

            FINALIZE: begin
                if (permutation_extend) begin
                    S <= Pout_r;
                    tag_r <= Pout_r[127:0] ^ key;
                    permutation_start <= 1'b0;
                end 
                else begin
                    Pin <= S ^ {{r{1'b0}}, key, {(320-r-k){1'b0}}};
                    permutation_start <= 1'b1;
                end
            end
            default: begin
                S <= S;
                Pin <= Pin;
                Pout_r <= Pout_r;
                permutation_start <= 1'b0;
                ct_r <= ct_r;
                tag_r <= tag_r;
                permutation_extend <= 1'b0;
                ini_stemp <= ini_stemp;
                ad_stemp <= ad_stemp;
                pt_stemp <= pt_stemp;
            end
        endcase
    end
end

assign encryption_fin = (state == FIN);
assign ct  = ct_r;
assign tag = tag_r;

always @(posedge clk ) begin
    if (rst) Pout_r <= 319'd0;
    else Pout_r <= Pout;
end

// Instantiate Permutation Module
permutation permutation (
    .clk(clk),
    .rst(rst),
    .S(Pin),
    .start(permutation_start),
    .round(round),
    .S_out(Pout),
    .fin(permutation_fin)
);

endmodule