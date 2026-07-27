`timescale 1ns / 1ps
`include "axi_peripheral.vh"
module uart_wrap #(parameter integer CLK_FREQ=50000000, parameter integer BAUD_RATE=115200)
    (`AXI_SLAVE_PORTS, input wire rx, output wire tx);
    localparam integer CPB = CLK_FREQ/BAUD_RATE;
    wire wr_en, rd_en; wire [31:0] wr_addr, wr_data, rd_addr; wire [3:0] wr_strb;
    reg [9:0] tx_shift; reg [31:0] tx_count; reg [3:0] tx_bits; wire tx_busy=|tx_bits;
    reg rx_meta, rx_sync; reg [1:0] rx_state; reg [31:0] rx_count; reg [2:0] rx_bit;
    reg [7:0] rx_shift, rx_data; reg rx_valid;
    wire [31:0] status={28'h0,tx_busy,!tx_busy,rx_valid,rx_valid};
    wire [31:0] rd_data=(rd_addr[11:0]==0)?{24'h0,rx_data}:(rd_addr[11:0]==8)?status:0;
    assign tx=tx_busy?tx_shift[0]:1'b1;
    axi_reg_slave U_bus (`AXI_REG_CONNECT, .wr_en(wr_en), .wr_addr(wr_addr),
        .wr_data(wr_data), .wr_strb(wr_strb), .rd_en(rd_en), .rd_addr(rd_addr), .rd_data(rd_data));
    always @(posedge aclk or negedge aresetn) begin
        if(!aresetn) begin tx_shift<=10'h3ff;tx_count<=0;tx_bits<=0; end else begin
            if(wr_en && wr_addr[11:0]==12'h004 && !tx_busy) begin tx_shift<={1'b1,wr_data[7:0],1'b0};tx_count<=CPB-1;tx_bits<=10; end
            else if(wr_en && wr_addr[11:0]==12'h00c && wr_data[0]) tx_bits<=0;
            else if(tx_busy) begin if(tx_count==0) begin tx_shift<={1'b1,tx_shift[9:1]};tx_count<=CPB-1;tx_bits<=tx_bits-1'b1; end else tx_count<=tx_count-1'b1; end
        end
    end
    always @(posedge aclk or negedge aresetn) begin
        if(!aresetn) begin rx_meta<=1;rx_sync<=1;rx_state<=0;rx_count<=0;rx_bit<=0;rx_shift<=0;rx_data<=0;rx_valid<=0; end else begin
            rx_meta<=rx;rx_sync<=rx_meta;
            if(rd_en && rd_addr[11:0]==0) rx_valid<=0;
            if(wr_en && wr_addr[11:0]==12'h00c && wr_data[1]) rx_valid<=0;
            case(rx_state)
                0:if(!rx_sync) begin rx_count<=CPB/2;rx_state<=1;end
                1:if(rx_count==0) begin if(!rx_sync) begin rx_count<=CPB-1;rx_bit<=0;rx_state<=2;end else rx_state<=0;end else rx_count<=rx_count-1'b1;
                2:if(rx_count==0) begin rx_shift[rx_bit]<=rx_sync;rx_count<=CPB-1;if(rx_bit==7)rx_state<=3;else rx_bit<=rx_bit+1'b1;end else rx_count<=rx_count-1'b1;
                3:if(rx_count==0) begin rx_data<=rx_shift;rx_valid<=1;rx_state<=0;end else rx_count<=rx_count-1'b1;
            endcase
        end
    end
    wire unused=wr_strb[0];
endmodule
