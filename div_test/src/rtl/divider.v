`timescale 1ns / 1ps

module divider (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] x,
    input  wire [7:0] y,
    input  wire       start,
    output wire [7:0] z,
    output wire [7:0] r,
    output wire       busy
);

    reg [13:0]  dividend;   //被除数/余数
    reg [7:0]   divisor;    //除数
    reg [7:0]   merchant;   //商
    reg [2:0]   count;      //左移计数
    reg         busy_reg;   //忙信号

    



	
endmodule
