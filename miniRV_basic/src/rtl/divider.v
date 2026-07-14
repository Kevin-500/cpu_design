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
reg [WIDTH-1:0]    merchant;   //商
reg [$clog2(WIDTH)-1:0] count;      //计数器,记录加减次数
reg                busy_reg;   //忙信号

assign z = merchant;
assign r = {merchant[WIDTH-1] ^ divisor[WIDTH-1], dividend[2*WIDTH-4:WIDTH-2]};

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
    end else if (count == (WIDTH-2)) begin
        count <= {$clog2(WIDTH){1'b0}};
    end else if (busy_reg) begin
        count <= count + 1'b1;
    end else begin
        count <= {$clog2(WIDTH){1'b0}};
    end
end

// 被除数余数寄存器
wire [2*WIDTH-3:0] dividend_init;
assign dividend_init = {{(WIDTH-1){1'b0}}, x[WIDTH-2:0]} + {~{{1'b0}, y[WIDTH-2:0]} + 1'b1, {(WIDTH-2){1'b0}}};
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dividend <= {(2*WIDTH-2){1'b0}};
    end else if (start) begin
        dividend <= dividend_init;
    end else if (busy_reg) begin
        if (count == (WIDTH-2))
            dividend <= dividend + (dividend[2*WIDTH-3] ? {{1'b0, divisor[WIDTH-2:0]}, {(WIDTH-2){1'b0}}} : {(2*WIDTH-2){1'b0}});
        else
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
    end else if (start) begin
        merchant <= ((x[WIDTH-1] ^ y[WIDTH-1]) ? {1'b1, {(WIDTH-1){1'b0}}} : {WIDTH{1'b0}}) + (dividend_init[2*WIDTH-3] ? 1'b0 : 1'b1);//首次生成符号位以及最高位数值位
    end else if (busy_reg) begin
        merchant <= {merchant[WIDTH-1], merchant[WIDTH-3:0], dividend[2*WIDTH-3] ? 1'b0 : 1'b1};
    end
end

endmodule
