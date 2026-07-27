`timescale 1ns / 1ps

`include "defines.vh"

module axi_master (
    input  wire                       aclk,
    input  wire                       areset,
    output wire                       ic_dev_rrdy,
    input  wire [3:0]                 ic_cpu_ren,
    input  wire [31:0]                ic_cpu_raddr,
    output reg                        ic_dev_rvalid,
    output reg  [`IC_BLK_SIZE-1:0]    ic_dev_rdata,
    output wire                       dc_dev_wrdy,
    input  wire [3:0]                 dc_cpu_wen,
    input  wire [31:0]                dc_cpu_waddr,
    input  wire [31:0]                dc_cpu_wdata,
    output wire                       dc_dev_rrdy,
    input  wire [3:0]                 dc_cpu_ren,
    input  wire [31:0]                dc_cpu_raddr,
    output reg                        dc_dev_rvalid,
    output reg  [`DC_BLK_SIZE-1:0]    dc_dev_rdata,
    output reg  [31:0]                m_axi_awaddr,
    output reg  [7:0]                 m_axi_awlen,
    output reg  [2:0]                 m_axi_awsize,
    output reg  [1:0]                 m_axi_awburst,
    output reg                        m_axi_awvalid,
    input  wire                       m_axi_awready,
    output reg  [31:0]                m_axi_wdata,
    output reg  [3:0]                 m_axi_wstrb,
    output wire                       m_axi_wlast,
    output reg                        m_axi_wvalid,
    input  wire                       m_axi_wready,
    output reg                        m_axi_bready,
    input  wire [1:0]                 m_axi_bresp,
    input  wire                       m_axi_bvalid,
    output reg  [31:0]                m_axi_araddr,
    output reg  [7:0]                 m_axi_arlen,
    output reg  [2:0]                 m_axi_arsize,
    output reg  [1:0]                 m_axi_arburst,
    output reg                        m_axi_arvalid,
    input  wire                       m_axi_arready,
    output reg                        m_axi_rready,
    input  wire [31:0]                m_axi_rdata,
    input  wire [1:0]                 m_axi_rresp,
    input  wire                       m_axi_rlast,
    input  wire                       m_axi_rvalid
);
    localparam IDLE    = 3'd0;
    localparam R_ADDR  = 3'd1;
    localparam R_DATA  = 3'd2;
    localparam W_SEND  = 3'd3;
    localparam W_RESP  = 3'd4;

    localparam SRC_ICACHE = 1'b0;
    localparam SRC_DCACHE = 1'b1;

    reg [2:0] state;
    reg read_source;
    reg [31:0] read_addr;
    reg [7:0] read_len;
    reg [1:0] read_beat;
    reg [127:0] read_buffer;
    reg [31:0] write_addr;
    reg [31:0] write_data;
    reg [3:0] write_strobe;
    reg aw_pending;
    reg w_pending;

    assign m_axi_wlast = 1'b1;
    assign dc_dev_wrdy = (state == IDLE);
    assign dc_dev_rrdy = (state == IDLE) && (dc_cpu_wen == 4'h0);
    assign ic_dev_rrdy = (state == IDLE) && (dc_cpu_wen == 4'h0) &&
                         (dc_cpu_ren == 4'h0);

    function [7:0] request_len;
        input source;
        input [31:0] address;
        begin
            if (address[31:16] == 16'hffff)
                request_len = 8'd0;
            else if (source == SRC_ICACHE)
                request_len = `IC_BLK_LEN - 1;
            else
                request_len = `DC_BLK_LEN - 1;
        end
    endfunction

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            state <= IDLE;
            read_source <= SRC_ICACHE;
            read_addr <= 32'h0;
            read_len <= 8'h0;
            read_beat <= 2'h0;
            read_buffer <= 128'h0;
            write_addr <= 32'h0;
            write_data <= 32'h0;
            write_strobe <= 4'h0;
            aw_pending <= 1'b0;
            w_pending <= 1'b0;
            ic_dev_rvalid <= 1'b0;
            dc_dev_rvalid <= 1'b0;
            ic_dev_rdata <= {`IC_BLK_SIZE{1'b0}};
            dc_dev_rdata <= {`DC_BLK_SIZE{1'b0}};
        end else begin
            ic_dev_rvalid <= 1'b0;
            dc_dev_rvalid <= 1'b0;

            case (state)
                IDLE: begin
                    if (dc_cpu_wen != 4'h0) begin
                        write_addr <= dc_cpu_waddr;
                        write_data <= dc_cpu_wdata;
                        write_strobe <= dc_cpu_wen;
                        aw_pending <= 1'b1;
                        w_pending <= 1'b1;
                        state <= W_SEND;
                    end else if (dc_cpu_ren != 4'h0) begin
                        read_source <= SRC_DCACHE;
                        read_addr <= dc_cpu_raddr;
                        read_len <= request_len(SRC_DCACHE, dc_cpu_raddr);
                        read_beat <= 2'h0;
                        read_buffer <= 128'h0;
                        state <= R_ADDR;
                    end else if (ic_cpu_ren != 4'h0) begin
                        read_source <= SRC_ICACHE;
                        read_addr <= ic_cpu_raddr;
                        read_len <= request_len(SRC_ICACHE, ic_cpu_raddr);
                        read_beat <= 2'h0;
                        read_buffer <= 128'h0;
                        state <= R_ADDR;
                    end
                end
                R_ADDR: begin
                    if (m_axi_arready)
                        state <= R_DATA;
                end
                R_DATA: begin
                    if (m_axi_rvalid) begin
                        case (read_beat)
                            2'd0: read_buffer[31:0] <= m_axi_rdata;
                            2'd1: read_buffer[63:32] <= m_axi_rdata;
                            2'd2: read_buffer[95:64] <= m_axi_rdata;
                            default: read_buffer[127:96] <= m_axi_rdata;
                        endcase

                        if (m_axi_rlast || (read_beat == read_len[1:0])) begin
                            if (read_source == SRC_ICACHE) begin
                                ic_dev_rvalid <= 1'b1;
                                if (read_len == 8'd0)
                                    ic_dev_rdata <= m_axi_rdata;
                                else
                                    ic_dev_rdata <= {m_axi_rdata, read_buffer[95:0]};
                            end else begin
                                dc_dev_rvalid <= 1'b1;
                                if (read_len == 8'd0)
                                    dc_dev_rdata <= m_axi_rdata;
                                else
                                    dc_dev_rdata <= {m_axi_rdata, read_buffer[95:0]};
                            end
                            state <= IDLE;
                        end else begin
                            read_beat <= read_beat + 2'd1;
                        end
                    end
                end
                W_SEND: begin
                    if (aw_pending && m_axi_awready)
                        aw_pending <= 1'b0;
                    if (w_pending && m_axi_wready)
                        w_pending <= 1'b0;
                    if ((!aw_pending || m_axi_awready) &&
                        (!w_pending || m_axi_wready))
                        state <= W_RESP;
                end
                W_RESP: begin
                    if (m_axi_bvalid)
                        state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    always @(*) begin
        m_axi_awaddr = write_addr;
        m_axi_awlen = 8'd0;
        m_axi_awsize = 3'd2;
        m_axi_awburst = 2'b01;
        m_axi_awvalid = (state == W_SEND) && aw_pending;
        m_axi_wdata = write_data;
        m_axi_wstrb = write_strobe;
        m_axi_wvalid = (state == W_SEND) && w_pending;
        m_axi_bready = (state == W_RESP);

        m_axi_araddr = read_addr;
        m_axi_arlen = read_len;
        m_axi_arsize = 3'd2;
        m_axi_arburst = 2'b01;
        m_axi_arvalid = (state == R_ADDR);
        m_axi_rready = (state == R_DATA);
    end

    wire unused_responses = ^{m_axi_bresp, m_axi_rresp};
endmodule
