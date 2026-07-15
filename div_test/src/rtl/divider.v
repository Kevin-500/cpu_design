`timescale 1ns / 1ps

module divider (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] x,
    input  wire [7:0] y,
    input  wire       start,
    output wire [7:0] z,//原码
    output wire [7:0] r,//原码
    output wire       busy
);

reg [13:0]  dividend;   //被除数/余数
reg [7:0]   divisor;    //除数
reg [7:0]   merchant;   //商,原码
reg [2:0]   count;      //计数器,记录加减次数
reg         busy_reg;   //忙信号

assign z = merchant;
assign r = {merchant[7] ^ divisor[7], dividend[12:6]};

assign busy = busy_reg;

    // 忙信号
always @(posedge clk or posedge rst) begin
    if (rst) begin
        busy_reg <= 1'b0;
    end else if (start) begin
        busy_reg <= 1'b1;
    end else if (count == 3'd6) begin
        busy_reg <= 1'b0;
    end
end

// 计数器控制
always @(posedge clk or posedge rst) begin
    if (rst) begin
        count <= 3'b0;
    end else if (count == 3'd6) begin
        count <= 3'b0;
    end else if (busy_reg) begin
        count <= count + 1'b1;
    end else begin
        count <= 3'b0;
    end
end

// 被除数余数寄存器
wire [13:0] dividend_init;
assign dividend_init = {7'b0, x[6:0]} + {~{1'b0, y[6:0]} + 1'b1, 6'b0};
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dividend <= 14'b0;
    end else if (start) begin
        dividend <= dividend_init;
    end else if (busy_reg) begin
        if (count == 3'd6)
            dividend <= dividend + (dividend[13] ? {{1'b0, divisor[6:0]}, 6'b0} : 14'b0);
        else
            dividend <= {dividend[12:0], 1'b0} + (dividend[13] ? {{1'b0, divisor[6:0]}, 6'b0} : {~{1'b0, divisor[6:0]} + 1'b1, 6'b0});
    end
end

// 除数寄存器
always @(posedge clk or posedge rst) begin
    if (rst) begin
        divisor <= 8'b0;
    end else if (start) begin
        divisor <= y;
    end
end

// 商寄存器
always @(posedge clk or posedge rst) begin
    if (rst) begin
        merchant <= 8'b0;
    end else if (start) begin
        merchant <= ((x[7] ^ y[7]) ? 8'h80 : 8'h00) + (dividend_init[13] ? 1'b0 : 1'b1);//首次生成符号位以及最高位数值位
    end else if (busy_reg) begin
        merchant <= {merchant[7], merchant[5:0], dividend[13] ? 1'b0 : 1'b1};
    end
end

endmodule
