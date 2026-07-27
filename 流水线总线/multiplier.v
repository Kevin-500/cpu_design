`timescale 1ns / 1ps

module multiplier #(
    parameter WIDTH = 32
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire [WIDTH-1:0]     x,
    input  wire [WIDTH-1:0]     y,
    input  wire                 start,
    output reg  [2*WIDTH-1:0]   z,
    output wire                 busy
);

    localparam COUNT_WIDTH = $clog2(WIDTH);
    reg [2*WIDTH-1:0] multiplicand;
    reg [WIDTH-1:0] multiplier_bits;
    reg [2*WIDTH-1:0] accumulator;
    reg [COUNT_WIDTH-1:0] count;
    reg result_negative;
    reg busy_reg;
    wire [WIDTH-1:0] x_magnitude = x[WIDTH-1] ? (~x + 1'b1) : x;
    wire [WIDTH-1:0] y_magnitude = y[WIDTH-1] ? (~y + 1'b1) : y;
    wire [2*WIDTH-1:0] accumulator_next =
        multiplier_bits[0] ? accumulator + multiplicand : accumulator;

    assign busy = busy_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            z               <= {(2*WIDTH){1'b0}};
            multiplicand    <= {(2*WIDTH){1'b0}};
            multiplier_bits <= {WIDTH{1'b0}};
            accumulator     <= {(2*WIDTH){1'b0}};
            count           <= {COUNT_WIDTH{1'b0}};
            result_negative <= 1'b0;
            busy_reg        <= 1'b0;
        end else if (start && !busy_reg) begin
            multiplicand    <= {{WIDTH{1'b0}}, x_magnitude};
            multiplier_bits <= y_magnitude;
            accumulator     <= {(2*WIDTH){1'b0}};
            count           <= {COUNT_WIDTH{1'b0}};
            result_negative <= x[WIDTH-1] ^ y[WIDTH-1];
            busy_reg        <= 1'b1;
        end else if (busy_reg) begin
            accumulator     <= accumulator_next;
            multiplicand    <= multiplicand << 1;
            multiplier_bits <= multiplier_bits >> 1;
            if (count == WIDTH-1) begin
                z        <= result_negative ? (~accumulator_next + 1'b1) : accumulator_next;
                busy_reg <= 1'b0;
                count    <= {COUNT_WIDTH{1'b0}};
            end else begin
                count <= count + 1'b1;
            end
        end
    end
    
endmodule

