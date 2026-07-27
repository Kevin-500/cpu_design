`timescale 1ns / 1ps

module led_wrap (
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
    output wire [15:0]  led_o
);

    wire        wr_en;
    wire        rd_en;
    wire [31:0] wr_addr;
    wire [31:0] wr_data;
    wire [31:0] rd_addr;
    wire [3:0]  wr_strb;

    reg  [31:0] led_reg;

    wire [31:0] rd_data = led_reg;
    assign led_o = led_reg[15:0];

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
            led_reg <= 32'h0;
        end else if (wr_en) begin
            if (wr_strb[0]) led_reg[7:0]   <= wr_data[7:0];
            if (wr_strb[1]) led_reg[15:8]  <= wr_data[15:8];
            if (wr_strb[2]) led_reg[23:16] <= wr_data[23:16];
            if (wr_strb[3]) led_reg[31:24] <= wr_data[31:24];
        end
    end

    wire unused = ^{wr_addr, rd_en, rd_addr};

endmodule
