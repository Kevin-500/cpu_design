`timescale 1ns / 1ps

`include "defines.vh"

module ALU (
    input  wire         rst,
    input  wire         clk,
    input  wire [ 4:0]  op,
    input  wire [31:0]  a,
    input  wire [31:0]  b,
    
    output reg  [31:0]  c,
    output reg          br,
    output wire         busy
);

    wire        mul_flag, mulu_flag;
    wire [63:0] mul_res , mulu_res ;
    wire        mul_busy, mulu_busy;
    wire        div_flag, divu_flag;
    wire [31:0] div_quo , divu_quo ;    // quotient
    wire [31:0] div_rem , divu_rem ;    // remainder
    wire        div_busy, divu_busy;
    reg  [ 4:0] op_r;
    // reg         div_quot_negative;
    // reg         div_rem_negative;
    // reg         div_by_zero;
    // reg         div_overflow;
    // reg  [31:0] div_dividend;
    // wire [31:0] div_quot_signed = div_quot_negative ? (~div_quo + 1'b1) : div_quo;
    // wire [31:0] div_rem_signed  = div_rem_negative  ? (~div_rem + 1'b1) : div_rem;

    always @(*) begin
        case (op_r != 5'h0 ? op_r : op)
            `ALU_ADD  : c = a + b;
            `ALU_SUB  : c = a - b;
            `ALU_AND  : c = a & b;
            `ALU_OR   : c = a | b;
            `ALU_XOR  : c = a ^ b;
            `ALU_SLL  : c = a << b[4:0];
            `ALU_SRL  : c = a >> b[4:0];
            `ALU_SRA  : c = $signed(a) >>> b[4:0];
            `ALU_LT   : c = ({~a[31], a[30:0]} < {~b[31], b[30:0]});
            `ALU_LTU  : c = a < b;
            `ALU_NLT  : c = !({~a[31], a[30:0]} < {~b[31], b[30:0]});
            `ALU_NLTU : c = !(a < b);
            `ALU_MUL  : c = mul_res[31:0];
            `ALU_MULH : c = mul_res[63:32];
            `ALU_MULHU: c = mulu_res[63:32];
            `ALU_DIV  : c = busy ? 32'h0 : div_quo;
            `ALU_DIVU : c = busy ? 32'h0 : divu_quo;
            `ALU_REM  : c = busy ? 32'h0 : div_rem;
            `ALU_REMU : c = busy ? 32'h0 : divu_rem;
            default   : c = 32'h0;
        endcase
    end

    always @(*) begin
        case (op)
            `ALU_EQ : br = a == b;
            `ALU_NE : br = a != b;
            `ALU_LT : br = ({~a[31], a[30:0]} < {~b[31], b[30:0]});
            `ALU_LTU : br = a < b;
            `ALU_NLT : br = !({~a[31], a[30:0]} < {~b[31], b[30:0]});
            `ALU_NLTU : br = !(a < b);
            default : br = 1'b0;
        endcase
    end

    assign mul_flag  = (op == `ALU_MUL) | (op == `ALU_MULH);
    assign mulu_flag = (op == `ALU_MULHU);
    assign div_flag  = (op == `ALU_DIV) | (op == `ALU_REM);
    assign divu_flag = (op == `ALU_DIVU) | (op == `ALU_REMU);
    assign busy      = mul_busy | mulu_busy | div_busy | divu_busy;

    always @(posedge clk or posedge rst) begin
        if (rst)
            op_r <= 5'h0;
        else if (mul_flag | mulu_flag | div_flag | divu_flag)
            op_r <= op;
        else if (!busy)
            op_r <= 5'h0;
    end

    // always @(posedge clk or posedge rst) begin
    //     if (rst) begin
    //         div_quot_negative <= 1'b0;
    //         div_rem_negative  <= 1'b0;
    //         div_by_zero       <= 1'b0;
    //         div_overflow      <= 1'b0;
    //         div_dividend      <= 32'h0;
    //     end else if (div_flag) begin
    //         div_quot_negative <= a[31] ^ b[31];
    //         div_rem_negative  <= a[31];
    //         div_by_zero       <= (b == 32'h0);
    //         div_overflow      <= (a == 32'h8000_0000) && (b == 32'hffff_ffff);
    //         div_dividend      <= a;
    //     end
    // end

    multiplier #(32) U_mul (
        .clk    (clk),
        .rst    (rst),
        .x      (a),
        .y      (b),
        .start  (mul_flag),
        .z      (mul_res),
        .busy   (mul_busy)
    );

    multiplier #(33) U_mulu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (mulu_flag),
        .z      (mulu_res),
        .busy   (mulu_busy)
    );

    divider #(32) U_div (
        .clk    (clk),
        .rst    (rst),
        .x      (a[31] ? {1'b1, ~a[30:0] + 31'h1} : a),
        .y      (b[31] ? {1'b1, ~b[30:0] + 31'h1} : b),
        .start  (div_flag),
        .z      (div_quo),
        .r      (div_rem),
        .busy   (div_busy)
    );

    divider #(33) U_divu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (divu_flag),
        .z      (divu_quo),
        .r      (divu_rem),
        .busy   (divu_busy)
    );

endmodule
