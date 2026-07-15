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
    wire [31:0] sra_0, sra_1, sra_2, sra_3, sra_4;

    assign sra_0 = b[0] ? {{1{a[31]}}, a[31:1]} : a;
    assign sra_1 = b[1] ? {{2{a[31]}}, sra_0[31:2]} : sra_0;
    assign sra_2 = b[2] ? {{4{a[31]}}, sra_1[31:4]} : sra_1;
    assign sra_3 = b[3] ? {{8{a[31]}}, sra_2[31:8]} : sra_2;
    assign sra_4 = b[4] ? {{16{a[31]}}, sra_3[31:16]} : sra_3;

    always @(*) begin
        case (op_r != 4'h0 ? op_r : op)
            `ALU_ADD  : c = a + b;
            `ALU_SUB  : c = a - b;
            `ALU_AND  : c = a & b;
            `ALU_OR   : c = a | b;
            `ALU_DIV  : c = busy ? 32'h0 : div_quo;//未验算,纯直觉写的
            `ALU_DIVU : c = busy ? 32'h0 : divu_quo;
            `ALU_REM  : c = busy ? 32'h0 : div_rem;
            `ALU_REMU : c = busy ? 32'h0 : divu_rem;
            `ALU_SLL  : c = a << b[4:0];
            `ALU_MUL  : c = busy ? 32'h0 : mul_res[31:0];
            `ALU_MULH : c = busy ? 32'h0 : mul_res[63:32];
            `ALU_MULHU: c = busy ? 32'h0 : mulu_res[63:32];
            `ALU_LT   : c = ({~a[31], a[30:0]} < {~b[31], b[30:0]});
            `ALU_LTU  : c = ({1'b0, a} < {1'b0, b});
            `ALU_SRA  : c = sra_4;
            default   : c = 32'h0;
        endcase
    end

    always @(*) begin
        case (op)
            `ALU_EQ : br = (a == b);
            // `ALU_LT : br = (a < b);
            `ALU_LT : br = ({~a[31], a[30:0]} < {~b[31], b[30:0]});
            `ALU_LTU: br = ({1'b0, a} < {1'b0, b});
            default : br = 1'b0;
        endcase
    end

    assign mul_flag  = (op == `ALU_MUL | op == `ALU_MULH);
    assign mulu_flag = op == `ALU_MULHU;
    assign div_flag  = (op == `ALU_DIV | op == `ALU_REM);
    assign divu_flag = (op == `ALU_DIVU | op == `ALU_REMU);
    assign busy      = mul_busy | mulu_busy | div_busy | divu_busy;

    always @(posedge clk) begin
        if (mul_flag | mulu_flag | div_flag | divu_flag)
            op_r <= op;
        else if (!busy)
            op_r <= 4'h0;
    end

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
