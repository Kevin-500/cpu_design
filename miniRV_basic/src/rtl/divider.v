`timescale 1ns / 1ps

module divider #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             rst,
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire             start,
    output wire [WIDTH-1:0] z,
    output wire [WIDTH-1:0] r,
    output wire             busy
);

reg [2*WIDTH-3:0]  dividend;   //被除数/余数
reg [WIDTH-1:0]    divisor;    //除数
reg [WIDTH-1:0]    merchant;   //商,原码存储
reg [$clog2(WIDTH)-1:0] count; //计数器,记录加减次数
reg                busy_reg;   //忙信号

wire [WIDTH-1:0]   remainder;  //余数,原码存储
assign remainder = {merchant[WIDTH-1] ^ divisor[WIDTH-1], dividend[2*WIDTH-4:WIDTH-2]};

// 补码化
assign z = merchant[WIDTH-1] ? {1'b1, ~merchant[WIDTH-2:0] + 1'b1} : {1'b0, merchant[WIDTH-2:0]};
assign r = remainder[WIDTH-1] ? {1'b1, ~remainder[WIDTH-2:0] + 1'b1} : {1'b0, remainder[WIDTH-2:0]};

assign busy = busy_reg;

    // 忙信号
always @(posedge clk or posedge rst) begin
    if (rst) begin
        busy_reg <= 1'b0;
    end else if (start) begin
        busy_reg <= 1'b1;
    end else if (count == (WIDTH-2)) begin
        busy_reg <= 1'b0;
    end
end

// 计数器控制
always @(posedge clk or posedge rst) begin
    if (rst) begin
        count <= {$clog2(WIDTH){1'b0}};
    end else if (count == (WIDTH-2)) begin  //共计WIDTH-1次计数,其中最后一次为余数修正
        count <= {$clog2(WIDTH){1'b0}};
    end else if (busy_reg) begin
        count <= count + 1'b1;
    end else begin
        count <= {$clog2(WIDTH){1'b0}};
    end
end

// 被除数余数寄存器
wire [2*WIDTH-3:0] dividend_init;   //初始化:低位为x的数值位,高位加上-y*的补码
assign dividend_init = {{(WIDTH-1){1'b0}}, x[WIDTH-2:0]} + {~{{1'b0}, y[WIDTH-2:0]} + 1'b1, {(WIDTH-2){1'b0}}};
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dividend <= {(2*WIDTH-2){1'b0}};
    end else if (start) begin
        dividend <= dividend_init;
    end else if (busy_reg) begin
        if (count == (WIDTH-2))     //最后一个周期:若被除数首位为1说明为余数为负,需要加回一个y*,若首位为0则不加.
            dividend <= dividend + (dividend[2*WIDTH-3] ? {{1'b0, divisor[WIDTH-2:0]}, {(WIDTH-2){1'b0}}} : {(2*WIDTH-2){1'b0}});
        else                        //正常周期:按正负号决定+/- y*
            dividend <= {dividend[2*WIDTH-4:0], 1'b0} + (dividend[2*WIDTH-3] ? {{1'b0, divisor[WIDTH-2:0]}, {(WIDTH-2){1'b0}}} : {~{1'b0, divisor[WIDTH-2:0]} + 1'b1, {(WIDTH-2){1'b0}}});
    end
end

// 除数寄存器
always @(posedge clk or posedge rst) begin
    if (rst) begin
        divisor <= {WIDTH{1'b0}};
    end else if (start) begin
        divisor <= y;
    end
end

// 商寄存器
always @(posedge clk or posedge rst) begin
    if (rst) begin
        merchant <= {WIDTH{1'b0}};
    end else if (start) begin       //start时生成符号位以及最高位数值位
        merchant <= ((x[WIDTH-1] ^ y[WIDTH-1]) ? {1'b1, {(WIDTH-1){1'b0}}} : {WIDTH{1'b0}}) + (dividend_init[2*WIDTH-3] ? 1'b0 : 1'b1);
    end else if (busy_reg) begin    //左移
        merchant <= {merchant[WIDTH-1], merchant[WIDTH-3:0], dividend[2*WIDTH-3] ? 1'b0 : 1'b1};
    end
end

endmodule
