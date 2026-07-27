`timescale 1ns / 1ps

module axi_bram #(
    parameter integer WORDS = 131072,
    parameter INIT_FILE = ""
) (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [31:0] s_axi_awaddr,
    input  wire [7:0]  s_axi_awlen,
    input  wire [2:0]  s_axi_awsize,
    input  wire [1:0]  s_axi_awburst,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wlast,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire [7:0]  s_axi_arlen,
    input  wire [2:0]  s_axi_arsize,
    input  wire [1:0]  s_axi_arburst,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output reg         s_axi_rlast,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready
);
    localparam integer ADDR_BITS = $clog2(WORDS);

    reg [31:0] mem [0:WORDS-1];
    reg aw_hold;
    reg [31:0] awaddr_hold;
    reg w_hold;
    reg [31:0] wdata_hold;
    reg [3:0] wstrb_hold;
    reg [31:0] read_addr;
    reg [7:0] read_remaining;
    integer i;

    assign s_axi_awready = !aw_hold && !s_axi_bvalid;
    assign s_axi_wready = !w_hold && !s_axi_bvalid;
    assign s_axi_bresp = 2'b00;
    assign s_axi_arready = !s_axi_rvalid;
    assign s_axi_rresp = 2'b00;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            mem[i] = 32'h0;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            aw_hold <= 1'b0;
            awaddr_hold <= 32'h0;
            w_hold <= 1'b0;
            wdata_hold <= 32'h0;
            wstrb_hold <= 4'h0;
            s_axi_bvalid <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                aw_hold <= 1'b1;
                awaddr_hold <= s_axi_awaddr;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                w_hold <= 1'b1;
                wdata_hold <= s_axi_wdata;
                wstrb_hold <= s_axi_wstrb;
            end

            if (aw_hold && w_hold && !s_axi_bvalid) begin
                if (wstrb_hold[0]) mem[awaddr_hold[ADDR_BITS+1:2]][7:0] <= wdata_hold[7:0];
                if (wstrb_hold[1]) mem[awaddr_hold[ADDR_BITS+1:2]][15:8] <= wdata_hold[15:8];
                if (wstrb_hold[2]) mem[awaddr_hold[ADDR_BITS+1:2]][23:16] <= wdata_hold[23:16];
                if (wstrb_hold[3]) mem[awaddr_hold[ADDR_BITS+1:2]][31:24] <= wdata_hold[31:24];
                aw_hold <= 1'b0;
                w_hold <= 1'b0;
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            read_addr <= 32'h0;
            read_remaining <= 8'h0;
            s_axi_rdata <= 32'h0;
            s_axi_rlast <= 1'b0;
            s_axi_rvalid <= 1'b0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                read_addr <= s_axi_araddr;
                read_remaining <= s_axi_arlen;
                s_axi_rdata <= mem[s_axi_araddr[ADDR_BITS+1:2]];
                s_axi_rlast <= (s_axi_arlen == 8'd0);
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                if (read_remaining == 8'd0) begin
                    s_axi_rvalid <= 1'b0;
                    s_axi_rlast <= 1'b0;
                end else begin
                    read_addr <= read_addr + 32'd4;
                    read_remaining <= read_remaining - 8'd1;
                    s_axi_rdata <= mem[(read_addr + 32'd4) >> 2];
                    s_axi_rlast <= (read_remaining == 8'd1);
                end
            end
        end
    end

    wire unused_axi = ^{s_axi_awlen, s_axi_awsize, s_axi_awburst,
                        s_axi_wlast, s_axi_arsize, s_axi_arburst};
endmodule
