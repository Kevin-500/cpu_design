`timescale 1ns / 1ps

module divider #(
    parameter WIDTH = 32
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire       start,
    output reg  [WIDTH-1:0] z,
    output reg  [WIDTH-1:0] r,
    output reg        busy
);

    localparam COUNT_WIDTH = $clog2(WIDTH);
    reg [WIDTH-1:0] divisor;
    reg [WIDTH-1:0] quotient_work;
    reg [WIDTH:0] remainder_work;
    reg [COUNT_WIDTH-1:0] count;
    reg divisor_zero;

    wire [WIDTH:0] shifted_remainder =
        {remainder_work[WIDTH-1:0], quotient_work[WIDTH-1]};
    wire subtract_divisor = shifted_remainder >= {1'b0, divisor};
    wire [WIDTH:0] remainder_next = subtract_divisor
        ? shifted_remainder - {1'b0, divisor} : shifted_remainder;
    wire [WIDTH-1:0] quotient_next =
        {quotient_work[WIDTH-2:0], subtract_divisor};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            z               <= {WIDTH{1'b0}};
            r               <= {WIDTH{1'b0}};
            divisor         <= {WIDTH{1'b0}};
            quotient_work   <= {WIDTH{1'b0}};
            remainder_work  <= {(WIDTH+1){1'b0}};
            count           <= {COUNT_WIDTH{1'b0}};
            divisor_zero    <= 1'b0;
            busy            <= 1'b0;
        end else if (start && !busy) begin
            divisor         <= y;
            quotient_work   <= x;
            remainder_work  <= {(WIDTH+1){1'b0}};
            count           <= {COUNT_WIDTH{1'b0}};
            divisor_zero    <= (y == {WIDTH{1'b0}});
            busy            <= 1'b1;
        end else if (busy) begin
            if (divisor_zero) begin
                z    <= {WIDTH{1'b1}};
                r    <= quotient_work;
                busy <= 1'b0;
            end else begin
                quotient_work  <= quotient_next;
                remainder_work <= remainder_next;
                if (count == WIDTH-1) begin
                    z     <= quotient_next;
                    r     <= remainder_next[WIDTH-1:0];
                    busy  <= 1'b0;
                    count <= {COUNT_WIDTH{1'b0}};
                end else begin
                    count <= count + 1'b1;
                end
            end
        end
    end
	
endmodule
