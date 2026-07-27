`timescale 1ns / 1ps
`include "axi_peripheral.vh"
module digled_wrap #(parameter integer SCAN_DIV=6250) (`AXI_SLAVE_PORTS,
    output reg [7:0] dig_en, output reg [7:0] dig_seg, output wire [7:0] dig_seg1);
    wire wr_en, rd_en; wire [31:0] wr_addr, wr_data, rd_addr; wire [3:0] wr_strb;
    reg [31:0] digits; reg [7:0] enable; reg [31:0] scan_count; reg [2:0] scan_index;
    wire [31:0] rd_data = (rd_addr[11:0] == 12'h008) ? {24'h0,enable} : digits;
    assign dig_seg1 = dig_seg;
    axi_reg_slave U_bus (`AXI_REG_CONNECT, .wr_en(wr_en), .wr_addr(wr_addr),
        .wr_data(wr_data), .wr_strb(wr_strb), .rd_en(rd_en), .rd_addr(rd_addr), .rd_data(rd_data));
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin digits<=0; enable<=8'hff; scan_count<=0; scan_index<=0; end
        else begin
            if (scan_count == SCAN_DIV-1) begin scan_count<=0; scan_index<=scan_index+1'b1; end
            else scan_count<=scan_count+1'b1;
            if (wr_en && wr_addr[11:0]==12'h000) begin
                if(wr_strb[0]) digits[7:0]<=wr_data[7:0]; if(wr_strb[1]) digits[15:8]<=wr_data[15:8];
                if(wr_strb[2]) digits[23:16]<=wr_data[23:16]; if(wr_strb[3]) digits[31:24]<=wr_data[31:24];
            end else if (wr_en && wr_addr[11:0]==12'h008 && wr_strb[0]) enable<=wr_data[7:0];
        end
    end
    function [7:0] hex7; input [3:0] x; begin case(x)
        0:hex7=8'b11111100;1:hex7=8'b01100000;2:hex7=8'b11011010;3:hex7=8'b11110010;
        4:hex7=8'b01100110;5:hex7=8'b10110110;6:hex7=8'b10111110;7:hex7=8'b11100000;
        8:hex7=8'b11111110;9:hex7=8'b11110110;10:hex7=8'b11101110;11:hex7=8'b00111110;
        12:hex7=8'b10011100;13:hex7=8'b01111010;14:hex7=8'b10011110;default:hex7=8'b10001110;
    endcase end endfunction
    always @(*) begin dig_en = enable & (8'b1 << scan_index); dig_seg = hex7(digits[scan_index*4 +:4]); end
    wire unused = rd_en;
endmodule
