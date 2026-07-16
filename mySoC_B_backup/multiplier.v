`timescale 1ns / 1ps

module multiplier #(
    parameter WIDTH = 32
)(
    input  wire                clk,
    input  wire                rst,     // high active
    input  wire [WIDTH-1:0]    x,       // multiplicand
    input  wire [WIDTH-1:0]    y,       // multiplier
    input  wire                start,   // 1 - multiplication should begin
    output reg  [2*WIDTH-1:0]  z,       // product
    output wire                busy     // 1 - performing multiplication; 0 - multiplication ends
);

    localparam C_WID = $clog2(WIDTH) + 1;

    reg [WIDTH-1:0]   x_reg; //x_reg 被乘数
    reg [WIDTH-1:0]   p_reg; //部分积
    reg [WIDTH:0]     y_reg; //y_reg 乘数
    reg [C_WID-1:0]   count; //计数器
    reg               busy_reg; //忙标志

    // busy
    assign busy = busy_reg;

    // Booth addend select
    wire [WIDTH-1:0] booth_addend;
    assign booth_addend = (y_reg[0] && !y_reg[1]) ? x_reg :
                          (!y_reg[0] && y_reg[1]) ? (~x_reg + 1'b1) : {WIDTH{1'b0}};
    // partial sum: add then arithmetic shift right
    wire [WIDTH:0] p_sum; // 含最高位溢出位
    assign p_sum = {p_reg[WIDTH-1], p_reg} + {booth_addend[WIDTH-1], booth_addend};

    // 忙标志控制
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy_reg <= 1'b0;
        end else if (start) begin
            busy_reg <= 1'b1;
        end else if (count == C_WID'(WIDTH)) begin
            busy_reg <= 1'b0;
        end
    end

    // 计数器控制
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= {C_WID{1'b0}};
        end else if (count == C_WID'(WIDTH)) begin
            count <= {C_WID{1'b0}};
        end else if (busy_reg) begin
            count <= count + 1'b1;
        end else begin
            count <= {C_WID{1'b0}};
        end
    end

    // 被乘数寄存器
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_reg <= {WIDTH{1'b0}};
        end else if (start) begin
            x_reg <= x; // 存储x的补码
        end
    end

    // 乘数寄存器
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            y_reg <= {(WIDTH+1){1'b0}};
        end else if (start) begin
            y_reg <= {y, 1'b0}; // 将乘数左移一
        end else if (busy_reg) begin
            y_reg <= {p_sum[0], y_reg[WIDTH:1]}; // 乘数右移一
        end
    end

    // 部分积寄存器
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            p_reg <= {WIDTH{1'b0}};
        end else if (start) begin
            p_reg <= {WIDTH{1'b0}};
        end else if (busy_reg) begin
            p_reg <= {p_sum[WIDTH-1], p_sum[WIDTH-1:1]}; // 先加/减,再算术右移
        end
    end

    // 积寄存器
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            z <= {(2*WIDTH){1'b0}};
        end else if (count == C_WID'(WIDTH)) begin
            z <= {p_reg, y_reg[WIDTH:1]};
        end
    end

endmodule
