`timescale 1ns / 1ps

module axi_reg_slave (
    input wire aclk, input wire aresetn,
    input wire [31:0] s_axi_awaddr, input wire [7:0] s_axi_awlen,
    input wire [2:0] s_axi_awsize, input wire [1:0] s_axi_awburst,
    input wire s_axi_awvalid, output wire s_axi_awready,
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb,
    input wire s_axi_wlast, input wire s_axi_wvalid, output wire s_axi_wready,
    output wire [1:0] s_axi_bresp, output reg s_axi_bvalid, input wire s_axi_bready,
    input wire [31:0] s_axi_araddr, input wire [7:0] s_axi_arlen,
    input wire [2:0] s_axi_arsize, input wire [1:0] s_axi_arburst,
    input wire s_axi_arvalid, output wire s_axi_arready,
    output reg [31:0] s_axi_rdata, output wire [1:0] s_axi_rresp,
    output wire s_axi_rlast, output reg s_axi_rvalid, input wire s_axi_rready,
    output wire wr_en, output wire [31:0] wr_addr, output wire [31:0] wr_data,
    output wire [3:0] wr_strb, output wire rd_en, output wire [31:0] rd_addr,
    input wire [31:0] rd_data
);
    reg aw_hold, w_hold;
    reg [31:0] awaddr_hold, wdata_hold;
    reg [3:0] wstrb_hold;

    assign s_axi_awready = !aw_hold && !s_axi_bvalid;
    assign s_axi_wready = !w_hold && !s_axi_bvalid;
    assign s_axi_bresp = 2'b00;
    assign wr_en = aw_hold && w_hold && !s_axi_bvalid;
    assign wr_addr = awaddr_hold;
    assign wr_data = wdata_hold;
    assign wr_strb = wstrb_hold;
    assign s_axi_arready = !s_axi_rvalid;
    assign rd_en = s_axi_arvalid && s_axi_arready;
    assign rd_addr = s_axi_araddr;
    assign s_axi_rresp = 2'b00;
    assign s_axi_rlast = 1'b1;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            aw_hold <= 0; w_hold <= 0; s_axi_bvalid <= 0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin aw_hold <= 1; awaddr_hold <= s_axi_awaddr; end
            if (s_axi_wvalid && s_axi_wready) begin w_hold <= 1; wdata_hold <= s_axi_wdata; wstrb_hold <= s_axi_wstrb; end
            if (wr_en) begin aw_hold <= 0; w_hold <= 0; s_axi_bvalid <= 1; end
            else if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 0;
        end
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin s_axi_rvalid <= 0; s_axi_rdata <= 0; end
        else if (rd_en) begin s_axi_rvalid <= 1; s_axi_rdata <= rd_data; end
        else if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 0;
    end

    wire unused = ^{s_axi_awlen, s_axi_awsize, s_axi_awburst, s_axi_wlast,
                    s_axi_arlen, s_axi_arsize, s_axi_arburst};
endmodule
