`timescale 1ns / 1ps

`include "defines.vh"

module cpu_core(
    input  wire         cpu_rst,
    input  wire         cpu_clk,

    output wire         ifetch_req   /* verilator public */,
    output wire [31:0]  ifetch_addr  /* verilator public */,
    input  wire         ifetch_valid /* verilator public */,
    input  wire [31:0]  ifetch_inst,

    output reg  [ 3:0]  daccess_ren,
    output reg  [31:0]  daccess_addr,
    input  wire         daccess_rvalid,
    input  wire [31:0]  daccess_rdata,
    output reg  [ 3:0]  daccess_wen,
    output reg  [31:0]  daccess_wdata,
    input  wire         daccess_wresp
);

    /* ------------------------------ IF ------------------------------ */
    reg [31:0] fetch_pc;
    reg [31:0] fetch_req_pc;
    reg        fetch_pending;
    reg        fetch_drop;

    reg        ifid_valid;
    reg [31:0] ifid_pc;
    reg [31:0] ifid_inst;

    /* Keep this name public for the supplied liveness/debug benches. */
    wire [31:0] pc = fetch_pc;

    /* ------------------------------ ID ------------------------------ */
    wire [1:0] id_npc_op;
    wire [2:0] id_sext_op;
    wire       id_alua_sel;
    wire       id_alub_sel;
    wire [4:0] id_alu_op;
    wire       id_is_mul;
    wire       id_is_div;
    wire [2:0] id_ram_rop;
    wire [3:0] id_ram_wop;
    wire       id_rf_we;
    wire [1:0] id_rf_wsel;
    wire [31:0] id_ext;
    wire [31:0] rf_rd1;
    wire [31:0] rf_rd2;

    Controller U_CU (
        .opcode(ifid_inst[6:0]), .funct3(ifid_inst[14:12]),
        .funct7(ifid_inst[31:25]), .npc_op(id_npc_op),
        .sext_op(id_sext_op), .alua_sel(id_alua_sel),
        .alub_sel(id_alub_sel), .alu_op(id_alu_op),
        .is_mul(id_is_mul), .is_div(id_is_div),
        .ram_r_op(id_ram_rop), .ram_w_op(id_ram_wop),
        .rf_we(id_rf_we), .rf_wsel(id_rf_wsel)
    );

    SEXT U_SEXT (
        .op(id_sext_op), .imm(ifid_inst[31:7]), .ext(id_ext)
    );

    /* ------------------------------ WB ------------------------------ */
    reg        memwb_valid;
    reg [31:0] memwb_pc;
    reg        memwb_regwrite;
    reg [4:0]  memwb_rd;
    reg [31:0] memwb_value;

    wire rf_write = memwb_valid && memwb_regwrite && (memwb_rd != 5'h0);

    RF U_RF (
        .clk(cpu_clk), .rR1(ifid_inst[19:15]), .rR2(ifid_inst[24:20]),
        .we(rf_write), .wR(memwb_rd), .wD(memwb_value),
        .rD1(rf_rd1), .rD2(rf_rd2)
    );

    /* WB-to-ID bypass is required because the RF writes on the same edge
       that ID captures its operands. */
    wire [31:0] id_rs1_value =
        (rf_write && (memwb_rd == ifid_inst[19:15])) ? memwb_value : rf_rd1;
    wire [31:0] id_rs2_value =
        (rf_write && (memwb_rd == ifid_inst[24:20])) ? memwb_value : rf_rd2;

    /* ---------------------------- ID / EX --------------------------- */
    reg        idex_valid;
    reg [31:0] idex_pc;
    reg [31:0] idex_rs1_value;
    reg [31:0] idex_rs2_value;
    reg [31:0] idex_imm;
    reg [4:0]  idex_rs1;
    reg [4:0]  idex_rs2;
    reg [4:0]  idex_rd;
    reg [1:0]  idex_npc_op;
    reg [4:0]  idex_alu_op;
    reg        idex_alua_sel;
    reg        idex_alub_sel;
    reg [2:0]  idex_ram_rop;
    reg [3:0]  idex_ram_wop;
    reg        idex_regwrite;
    reg [1:0]  idex_wb_sel;
    reg        idex_is_md;
    reg        md_started;

    /* --------------------------- EX / MEM --------------------------- */
    reg        exmem_valid;
    reg [31:0] exmem_pc;
    reg [31:0] exmem_alu_result;
    reg [31:0] exmem_store_value;
    reg [31:0] exmem_imm;
    reg [4:0]  exmem_rd;
    reg [2:0]  exmem_ram_rop;
    reg [3:0]  exmem_ram_wop;
    reg        exmem_regwrite;
    reg [1:0]  exmem_wb_sel;
    reg        mem_request_sent;

    wire exmem_is_load  = exmem_ram_rop != `RAM_EXT_N;
    wire exmem_is_store = exmem_ram_wop != `RAM_WE_N;
    wire exmem_is_mem   = exmem_is_load || exmem_is_store;

    wire [3:0] mem_req_ren;
    wire [3:0] mem_req_wen;
    wire [31:0] mem_req_addr;
    wire [31:0] mem_req_wdata;

    MREQ U_MEM_REQ (
        .ram_addr(exmem_alu_result), .ram_rop(exmem_ram_rop),
        .da_ren(mem_req_ren), .da_addr(mem_req_addr),
        .ram_wop(exmem_ram_wop), .ram_wdata(exmem_store_value),
        .da_wen(mem_req_wen), .da_wdata(mem_req_wdata)
    );

    wire [31:0] load_value;
    MEXT U_MEM_EXT (
        .op(exmem_ram_rop), .din(daccess_rdata),
        .byte_offs(exmem_alu_result[1:0]), .ext(load_value)
    );

    always @(*) begin
        daccess_ren   = 4'h0;
        daccess_wen   = 4'h0;
        daccess_addr  = exmem_alu_result;
        daccess_wdata = exmem_store_value;
        if (exmem_valid && exmem_is_mem && !mem_request_sent) begin
            daccess_ren   = mem_req_ren;
            daccess_wen   = mem_req_wen;
            daccess_addr  = mem_req_addr;
            daccess_wdata = mem_req_wdata;
        end
    end

    wire mem_response = exmem_is_load ? daccess_rvalid : daccess_wresp;
    wire mem_complete = !exmem_is_mem || mem_response;
    wire mem_fire = exmem_valid && mem_complete;
    wire exmem_ready = !exmem_valid || mem_complete;

    wire [31:0] exmem_result = exmem_is_load ? load_value :
        (exmem_wb_sel == `WB_PC4) ? (exmem_pc + 32'd4) :
        (exmem_wb_sel == `WB_EXT) ? exmem_imm : exmem_alu_result;

    wire exmem_forward_valid = exmem_valid && exmem_regwrite &&
                               (exmem_rd != 5'h0) &&
                               (!exmem_is_load || daccess_rvalid);
    wire memwb_forward_valid = memwb_valid && memwb_regwrite &&
                               (memwb_rd != 5'h0);

    wire [31:0] ex_rs1_forwarded =
        (exmem_forward_valid && (exmem_rd == idex_rs1)) ? exmem_result :
        (memwb_forward_valid && (memwb_rd == idex_rs1)) ? memwb_value :
        idex_rs1_value;
    wire [31:0] ex_rs2_forwarded =
        (exmem_forward_valid && (exmem_rd == idex_rs2)) ? exmem_result :
        (memwb_forward_valid && (memwb_rd == idex_rs2)) ? memwb_value :
        idex_rs2_value;

    wire [31:0] ex_alu_a = idex_alua_sel ? idex_pc : ex_rs1_forwarded;
    wire [31:0] ex_alu_b = idex_alub_sel ? idex_imm : ex_rs2_forwarded;
    wire [4:0] alu_op_to_unit = (idex_is_md && md_started) ? `ALU_ADD : idex_alu_op;
    wire [31:0] ex_alu_result;
    wire ex_branch_condition;
    wire alu_busy;

    ALU U_ALU (
        .rst(cpu_rst), .clk(cpu_clk), .op(alu_op_to_unit),
        .a(ex_alu_a), .b(ex_alu_b), .c(ex_alu_result),
        .br(ex_branch_condition), .busy(alu_busy)
    );

    wire md_done = md_started && !alu_busy;
    wire ex_complete = !idex_is_md || md_done;
    wire ex_fire = idex_valid && ex_complete && exmem_ready;

    wire control_taken = (idex_npc_op == `NPC_JMP) ||
                         (idex_npc_op == `NPC_JALR) ||
                         ((idex_npc_op == `NPC_BRA) && ex_branch_condition);
    wire [31:0] control_target = (idex_npc_op == `NPC_JALR) ?
                                 ((ex_rs1_forwarded + idex_imm) & 32'hffff_fffe) :
                                 (idex_pc + idex_imm);
    wire redirect = ex_fire && control_taken;

    wire idex_ready = !idex_valid || ex_fire;
    wire id_issue = ifid_valid && idex_ready && !redirect;
    wire front_ready = !ifid_valid || id_issue;
    assign ifetch_req = !cpu_rst && !fetch_pending && front_ready && !redirect;
    assign ifetch_addr = fetch_pc;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            fetch_pc         <= `PC_INIT_VAL;
            fetch_req_pc     <= `PC_INIT_VAL;
            fetch_pending    <= 1'b0;
            fetch_drop       <= 1'b0;
            ifid_valid       <= 1'b0;
            ifid_pc          <= 32'h0;
            ifid_inst        <= 32'h00000013;
            idex_valid       <= 1'b0;
            idex_pc          <= 32'h0;
            idex_rs1_value   <= 32'h0;
            idex_rs2_value   <= 32'h0;
            idex_imm         <= 32'h0;
            idex_rs1         <= 5'h0;
            idex_rs2         <= 5'h0;
            idex_rd          <= 5'h0;
            idex_npc_op      <= `NPC_PC4;
            idex_alu_op      <= `ALU_ADD;
            idex_alua_sel    <= `ALU_A_RS1;
            idex_alub_sel    <= `ALU_B_RS2;
            idex_ram_rop     <= `RAM_EXT_N;
            idex_ram_wop     <= `RAM_WE_N;
            idex_regwrite    <= 1'b0;
            idex_wb_sel      <= `WB_ALU;
            idex_is_md       <= 1'b0;
            md_started       <= 1'b0;
            exmem_valid      <= 1'b0;
            exmem_pc         <= 32'h0;
            exmem_alu_result <= 32'h0;
            exmem_store_value<= 32'h0;
            exmem_imm        <= 32'h0;
            exmem_rd         <= 5'h0;
            exmem_ram_rop    <= `RAM_EXT_N;
            exmem_ram_wop    <= `RAM_WE_N;
            exmem_regwrite   <= 1'b0;
            exmem_wb_sel     <= `WB_ALU;
            mem_request_sent <= 1'b0;
            memwb_valid      <= 1'b0;
            memwb_pc         <= 32'h0;
            memwb_regwrite   <= 1'b0;
            memwb_rd         <= 5'h0;
            memwb_value      <= 32'h0;
        end else begin
            /* WB is a one-cycle commit stage. */
            memwb_valid <= 1'b0;

            /* Accept one fetch response. A response belonging to a path
               invalidated by EX is consumed but not inserted. */
            if (ifetch_valid && fetch_pending) begin
                fetch_pending <= 1'b0;
                fetch_drop <= 1'b0;
                if (!fetch_drop && !redirect) begin
                    ifid_valid <= 1'b1;
                    ifid_pc <= fetch_req_pc;
                    ifid_inst <= ifetch_inst;
                end
            end

            if (ifetch_req) begin
                fetch_pending <= 1'b1;
                fetch_req_pc <= fetch_pc;
                fetch_pc <= fetch_pc + 32'd4;
            end

            /* MEM completes into WB. */
            if (exmem_valid && exmem_is_mem && !mem_request_sent)
                mem_request_sent <= 1'b1;
            if (mem_fire) begin
                memwb_valid <= 1'b1;
                memwb_pc <= exmem_pc;
                memwb_regwrite <= exmem_regwrite;
                memwb_rd <= exmem_rd;
                memwb_value <= exmem_result;
                exmem_valid <= 1'b0;
                mem_request_sent <= 1'b0;
            end

            /* Start a multi-cycle operation once and hold ID/EX until done. */
            if (idex_valid && idex_is_md && !md_started)
                md_started <= 1'b1;

            /* EX advances when its result is complete and MEM can accept it. */
            if (ex_fire) begin
                exmem_valid <= 1'b1;
                exmem_pc <= idex_pc;
                exmem_alu_result <= ex_alu_result;
                exmem_store_value <= ex_rs2_forwarded;
                exmem_imm <= idex_imm;
                exmem_rd <= idex_rd;
                exmem_ram_rop <= idex_ram_rop;
                exmem_ram_wop <= idex_ram_wop;
                exmem_regwrite <= idex_regwrite;
                exmem_wb_sel <= idex_wb_sel;
                mem_request_sent <= 1'b0;
                idex_valid <= 1'b0;
                md_started <= 1'b0;
            end

            /* ID advances whenever EX has room. */
            if (id_issue) begin
                idex_valid <= 1'b1;
                idex_pc <= ifid_pc;
                idex_rs1_value <= id_rs1_value;
                idex_rs2_value <= id_rs2_value;
                idex_imm <= id_ext;
                idex_rs1 <= ifid_inst[19:15];
                idex_rs2 <= ifid_inst[24:20];
                idex_rd <= ifid_inst[11:7];
                idex_npc_op <= id_npc_op;
                idex_alu_op <= id_alu_op;
                idex_alua_sel <= id_alua_sel;
                idex_alub_sel <= id_alub_sel;
                idex_ram_rop <= id_ram_rop;
                idex_ram_wop <= id_ram_wop;
                idex_regwrite <= id_rf_we;
                idex_wb_sel <= id_rf_wsel;
                idex_is_md <= id_is_mul || id_is_div;
                md_started <= 1'b0;
                ifid_valid <= 1'b0;
            end

            /* Static not-taken prediction: EX redirects and kills all younger
               work, including an outstanding instruction response. */
            if (redirect) begin
                fetch_pc <= control_target;
                ifid_valid <= 1'b0;
                if (fetch_pending && !ifetch_valid)
                    fetch_drop <= 1'b1;
            end
        end
    end

`ifdef RUN_TRACE
    wire [31:0] debug_wb_pc    /* verilator public */ = memwb_pc;
    wire        debug_wb_rf_we /* verilator public */ = rf_write;
    wire [ 4:0] debug_wb_rf_wR /* verilator public */ = memwb_rd;
    wire [31:0] debug_wb_rf_wD /* verilator public */ = memwb_value;

    wire [31:0] debug_mem_pc    /* verilator public */ = exmem_pc;
    wire [ 3:0] debug_mem_we    /* verilator public */ = daccess_wen;
    wire [31:0] debug_mem_waddr /* verilator public */ = daccess_addr;
    wire [31:0] debug_mem_wdata /* verilator public */ = daccess_wdata;
`endif

endmodule
