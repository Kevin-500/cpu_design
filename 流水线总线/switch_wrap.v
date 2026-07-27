`timescale 1ns / 1ps
`include "axi_peripheral.vh"
module switch_wrap (`AXI_SLAVE_PORTS, input wire [15:0] switch_i);
    wire wr_en, rd_en; wire [31:0] wr_addr, wr_data, rd_addr; wire [3:0] wr_strb;
    wire [31:0] rd_data = {16'h0, switch_i};
    axi_reg_slave U_bus (`AXI_REG_CONNECT, .wr_en(wr_en), .wr_addr(wr_addr),
        .wr_data(wr_data), .wr_strb(wr_strb), .rd_en(rd_en), .rd_addr(rd_addr), .rd_data(rd_data));
    wire unused = ^{wr_en, wr_addr, wr_data, wr_strb, rd_en, rd_addr};
endmodule
