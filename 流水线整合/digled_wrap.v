`timescale 1ns / 1ps

module digled_wrap #(
    parameter integer SCAN_DIV = 6250
) (
    input  wire         aclk,
    input  wire         aresetn,
    input  wire [31:0]  s_axi_awaddr,
    input  wire [7:0]   s_axi_awlen,
    input  wire [2:0]   s_axi_awsize,
    input  wire [1:0]   s_axi_awburst,
    input  wire         s_axi_awvalid,
    output wire         s_axi_awready,
    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wlast,
    input  wire         s_axi_wvalid,
    output wire         s_axi_wready,
    output wire [1:0]   s_axi_bresp,
    output wire         s_axi_bvalid,
    input  wire         s_axi_bready,
    input  wire [31:0]  s_axi_araddr,
    input  wire [7:0]   s_axi_arlen,
    input  wire [2:0]   s_axi_arsize,
    input  wire [1:0]   s_axi_arburst,
    input  wire         s_axi_arvalid,
    output wire         s_axi_arready,
    output wire [31:0]  s_axi_rdata,
    output wire [1:0]   s_axi_rresp,
    output wire         s_axi_rlast,
    output wire         s_axi_rvalid,
    input  wire         s_axi_rready,
    output reg  [7:0]   dig_en,
    output reg  [7:0]   dig_seg,
    output wire [7:0]   dig_seg1
);

    wire        wr_en;
    wire        rd_en;
    wire [31:0] wr_addr;
    wire [31:0] wr_data;
    wire [31:0] rd_addr;
    wire [3:0]  wr_strb;

    reg  [31:0] digits;
    reg  [ 7:0] enable;
    reg  [31:0] scan_count;
    reg  [ 2:0] scan_index;

    wire [31:0] rd_data = (rd_addr[11:0] == 12'h008) ? {24'h0, enable} : digits;

    assign dig_seg1 = dig_seg;

    axi_reg_slave U_bus (
        .aclk           (aclk),
        .aresetn        (aresetn),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awlen    (s_axi_awlen),
        .s_axi_awsize   (s_axi_awsize),
        .s_axi_awburst  (s_axi_awburst),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arlen    (s_axi_arlen),
        .s_axi_arsize   (s_axi_arsize),
        .s_axi_arburst  (s_axi_arburst),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rlast    (s_axi_rlast),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        .wr_en          (wr_en),
        .wr_addr        (wr_addr),
        .wr_data        (wr_data),
        .wr_strb        (wr_strb),
        .rd_en          (rd_en),
        .rd_addr        (rd_addr),
        .rd_data        (rd_data)
    );

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            digits     <= 32'h0;
            enable     <= 8'hff;
            scan_count <= 32'h0;
            scan_index <= 3'h0;
        end else begin
            if (scan_count == SCAN_DIV - 1) begin
                scan_count <= 32'h0;
                scan_index <= scan_index + 1'b1;
            end else begin
                scan_count <= scan_count + 1'b1;
            end

            if (wr_en && wr_addr[11:0] == 12'h000) begin
                if (wr_strb[0]) digits[7:0]   <= wr_data[7:0];
                if (wr_strb[1]) digits[15:8]  <= wr_data[15:8];
                if (wr_strb[2]) digits[23:16] <= wr_data[23:16];
                if (wr_strb[3]) digits[31:24] <= wr_data[31:24];
            end else if (wr_en && wr_addr[11:0] == 12'h008 && wr_strb[0]) begin
                enable <= wr_data[7:0];
            end
        end
    end

    function [7:0] hex7;
        input [3:0] x;
        begin
            case (x)
                4'h0: hex7 = 8'b11111100;
                4'h1: hex7 = 8'b01100000;
                4'h2: hex7 = 8'b11011010;
                4'h3: hex7 = 8'b11110010;
                4'h4: hex7 = 8'b01100110;
                4'h5: hex7 = 8'b10110110;
                4'h6: hex7 = 8'b10111110;
                4'h7: hex7 = 8'b11100000;
                4'h8: hex7 = 8'b11111110;
                4'h9: hex7 = 8'b11110110;
                4'ha: hex7 = 8'b11101110;
                4'hb: hex7 = 8'b00111110;
                4'hc: hex7 = 8'b10011100;
                4'hd: hex7 = 8'b01111010;
                4'he: hex7 = 8'b10011110;
                default: hex7 = 8'b10001110;
            endcase
        end
    endfunction

    always @(*) begin
        dig_en  = enable & (8'b1 << scan_index);
        dig_seg = hex7(digits[scan_index*4 +:4]);
    end

    wire unused = rd_en;

endmodule
