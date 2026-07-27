`timescale 1ns / 1ps

module cache_line_ram (
    input  wire         clk,
    input  wire         we,
    input  wire [5:0]   addr,
    input  wire [127:0] wdata,
    output reg  [127:0] rdata
);
    reg [127:0] mem [0:63];
    integer i;

    initial begin
        rdata = 128'h0;
        for (i = 0; i < 64; i = i + 1)
            mem[i] = 128'h0;
    end

    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= wdata;
            rdata <= wdata;
        end else begin
            rdata <= mem[addr];
        end
    end
endmodule
