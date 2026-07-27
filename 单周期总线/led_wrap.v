`timescale 1ns / 1ps
`include "axi_peripheral.vh"
module led_wrap (`AXI_SLAVE_PORTS, output wire [15:0] led_o);
    wire wr_en, rd_en; wire [31:0] wr_addr, wr_data, rd_addr; wire [3:0] wr_strb;
    reg [31:0] led_reg; wire [31:0] rd_data = led_reg; assign led_o = led_reg[15:0];
    axi_reg_slave U_bus (`AXI_REG_CONNECT, .wr_en(wr_en), .wr_addr(wr_addr),
        .wr_data(wr_data), .wr_strb(wr_strb), .rd_en(rd_en), .rd_addr(rd_addr), .rd_data(rd_data));
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) led_reg <= 0;
        else if (wr_en) begin
            if (wr_strb[0]) led_reg[7:0] <= wr_data[7:0];
            if (wr_strb[1]) led_reg[15:8] <= wr_data[15:8];
            if (wr_strb[2]) led_reg[23:16] <= wr_data[23:16];
            if (wr_strb[3]) led_reg[31:24] <= wr_data[31:24];
        end
    end
    wire unused = ^{wr_addr, rd_en, rd_addr};
endmodule
