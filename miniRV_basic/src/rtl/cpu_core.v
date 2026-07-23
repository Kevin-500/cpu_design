`timescale 1ns / 1ps

`include "defines.vh"

module cpu_core(
    input  wire         cpu_rst,
    input  wire         cpu_clk,

    // Instruction Fetch Interface
    output wire         ifetch_req   /* verilator public */ ,
    output wire [31:0]  ifetch_addr  /* verilator public */ ,
    input  wire         ifetch_valid /* verilator public */ ,
    input  wire [31:0]  ifetch_inst,
    
    // Data Access Interface
    output reg  [ 3:0]  daccess_ren,
    output reg  [31:0]  daccess_addr,
    input  wire         daccess_rvalid,
    input  wire [31:0]  daccess_rdata,
    output reg  [ 3:0]  daccess_wen,
    output reg  [31:0]  daccess_wdata,
    input  wire         daccess_wresp
);

    wire rst = cpu_rst;
    wire clk = cpu_clk;

    // PC and NPC
    wire [31:0] pc;
    wire [31:0] npc;
    wire [31:0] pc4;
    wire [31:0] inst;
    wire [31:0] npc_offset;

    // Controller
    wire [ 1:0] npc_op;
    wire [ 1:0] rf_wsel;
    wire [ 2:0] sext_op;
    wire [ 4:0] alu_op;
    wire        alua_sel;
    wire        alub_sel;
    wire [ 2:0] ram_rop;
    reg  [ 2:0] ram_rop_r;
    wire [ 3:0] ram_wop;
    wire        is_mul;
    wire        is_div;
    wire        is_mul_div;
    reg         mul_div_flag;       // 乘除法运算的标志位信号

    // Register File
    wire [31:0] rf_rd1;
    wire [31:0] rf_rd2;
    wire [31:0] rf_rd3;
    wire        rf_we;
    wire        rf_we1;
    reg  [ 4:0] rf_wR_r;
    wire [ 4:0] rf_wR;
    reg  [31:0] rf_wD;

    // Signed Extension
    wire [31:0] ext;

    // ALU
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_c;
    reg  [31:0] alu_c_r;
    wire        br;
    wire        mul_div_busy;
    
    // Memory Access
    wire [ 3:0] da_ren;
    wire [31:0] da_addr;
    wire [ 3:0] da_wen;
    wire [31:0] da_wdata;
    wire [31:0] ram_ext;
    wire        is_ld_st;
    reg         ld_st_flag;
    wire        ld_st_done;         // 访存完成的标志位信号

    wire        inst_finished;      // 指令执行完成的标志位信号
    reg         inst_finished_r;

    /***************************** IF *****************************/
    reg rst_r;
    wire first_req = rst_r & !cpu_rst;
    always @(posedge cpu_clk) rst_r <= cpu_rst;

    // 复位信号发生边沿变化时首次取指; 当前指令执行完毕后取下一条指令
    //修改流水线cpu取指令逻辑
    wire pause_ifetch   = //(ldst_suspend | is_ld_st | ex_ld_st) & !ldst_done |
                        (mul_div_pause | is_mul_div) & !mul_div_done;
    // wire resume_ifetch = ldst_done | mul_div_done;
    wire resume_ifetch = mul_div_done;

    assign ifetch_req  = !pause_ifetch & (first_req  |    // 复位后首次取指
                                        ifetch_valid |    // 上一条已取回，同时立即取下一条
                                        resume_ifetch);   // 数据访存或乘除运算结束，继续取指
    assign ifetch_addr = pc;

    // 跳转信号高位时pc需要选用ex阶段的pc,跳转信号为低位时继续用if阶段的pc
    // 分支预测默认不跳转,若B型指令br为0则不需要重复跳转.
    // 假如跳转后pc与当前pc一致,则同样不需要跳转,如offset=4时,跳转地址=pc4地址.
    //TODO:在不考虑多周期指令的情况下,目前branch可以兼做flush_pipeline信号清除IF/ID和ID/EX流水线寄存器.
    wire branch = (ex_npc_op == `NPC_JALR & {alu_c[31:1], 1'b0} != id_pc)
                | (ex_npc_op == `NPC_JMP & ex_sext != 32'h4)
                | (ex_npc_op == `NPC_BRA & br & ex_sext != 32'h4);
    wire [31:0] npc_pc = branch ? ex_pc : pc;
    wire [1:0]  final_npc_op = branch ? ex_npc_op : `NPC_PC4;

    // 流水线暂停时需要控制pc不变,即pc的输入npc为pc自身
    wire [31:0] pc_npc = pause ? pc : npc;

    NPC U_NPC (
        .op         (final_npc_op),
        .pc         (npc_pc),
        .offset     (npc_offset),
        .br         (br),
        .npc        (npc),
        .pc4        (pc4)
    );

    PC U_PC (
        .clk        (cpu_clk),
        .rst        (cpu_rst),
        .npc        (pc_npc),
        .fetch      (inst_finished),
        .pc         (pc)
    );
    
    /***************************** ID *****************************/
    // 按照约定的时序，ifetch_inst只在ifetch_valid有效时有效，且它们仅有效1个时钟.
    // 此处是为了避免ifetch_valid撤销后，ifetch_inst发生变化从而导致指令执行出错.
    assign inst = ifetch_valid ? ifetch_inst : 32'h13 /* NOP */ ;

    Controller U_CU (
        // input
        .opcode         (id_inst[6:0]),
        .funct3         (id_inst[14:12]),
        .funct7         (id_inst[31:25]),
        // output
        .npc_op         (npc_op),
        .sext_op        (sext_op),
        .alu_op         (alu_op),
        .alua_sel       (alua_sel),
        .alub_sel       (alub_sel),
        .is_mul         (is_mul),
        .is_div         (is_div),
        .ram_r_op       (ram_rop),
        .ram_w_op       (ram_wop),
        .rf_we          (rf_we),
        .rf_wsel        (rf_wsel)
    );

    RF U_RF (
        .clk        (cpu_clk),
        .rR1        (id_inst[19:15]),
        .rR2        (id_inst[24:20]),
        .rD1        (rf_rd1),
        .rD2        (rf_rd2),
        .we         (rf_we1),
        .wR         (rf_wR),
        .wD         (rf_wD)
    );

    SEXT U_SEXT (
        .op         (sext_op),
        .imm        (id_inst[31:7]),
        .ext        (ext)
    );
    
    // 遇到访存指令时, 拉高ld_st_flag标志位，表示正在执行访存指令
    assign is_ld_st = (mem_ram_rop != `RAM_EXT_N) | (mem_ram_wop != `RAM_WE_N);
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if      (cpu_rst)    ld_st_flag <= 1'b0;
        else if (is_ld_st)   ld_st_flag <= 1'b1;
        else if (ld_st_done) ld_st_flag <= 1'b0;
    end

    // 遇到乘除法指令时，拉高mul_div_flag标志位，表示正在执行乘除法指令
    assign is_mul_div = is_mul | is_div;
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if      (cpu_rst)       mul_div_flag <= 1'b0;
        else if (ex_mul_div)    mul_div_flag <= 1'b1;
        else if (!mul_div_busy) mul_div_flag <= 1'b0;
    end


    // Read Here
    // TODO:wr的流水线存储未完成.
    // 访存、乘除法指令无法在1个时钟内执行完，故先把指令的目标寄存器缓存起来
    always @(posedge cpu_clk) begin
        if (is_ld_st | is_mul_div) rf_wR_r <= id_inst[11:7];
    end

    /***************************** EX *****************************/

    //目前尚未处理内存相关的数据冒险,仅有ALU型冒险的前递逻辑
    assign alu_a = alua_sel ? id_pc  : (ex_rs1_hazard ? ex_forward : (mem_rs1_hazard ? mem_forward : (wb_rs1_hazard ? wb_forward : rf_rd1)));
    assign alu_b = alub_sel ? ext : (ex_rs2_hazard ? ex_forward : (mem_rs2_hazard ? mem_forward : (wb_rs2_hazard ? wb_forward : rf_rd2)));
    assign npc_offset = (ex_npc_op == `NPC_JALR) ? alu_c : ex_sext;

    //非访存型数据冒险:假设数据来自于ALU计算结果或立即数
    //分为EX冒险和MEM冒险和WB冒险,有EX则优先EX,就近原则
    //EX冒险判断条件:(三个条件参考计组流水线处理器章节)
    wire ex_rs1_hazard = ex_rf_we & (ex_wr != 5'b0) & (ex_wr == id_inst[19:15]);
    wire ex_rs2_hazard = ex_rf_we & (ex_wr != 5'b0) & (ex_wr == id_inst[24:20]);
    //MEM冒险判断条件:(三个条件+无EX冒险)
    wire mem_rs1_hazard = mem_rf_we & (mem_wr != 5'b0) & (mem_wr == id_inst[19:15]);
    wire mem_rs2_hazard = mem_rf_we & (mem_wr != 5'b0) & (mem_wr == id_inst[24:20]);
    //WB冒险判定条件
    wire wb_rs1_hazard = wb_rf_we & (wb_wr != 5'b0) & (wb_wr == id_inst[19:15]);
    wire wb_rs2_hazard = wb_rf_we & (wb_wr != 5'b0) & (wb_wr == id_inst[24:20]);

    //除访存外的三个wd都可以前递
    wire [31:0] ex_forward  = {32{ex_rf_wsel == `WB_ALU}} & alu_c
                            | {32{ex_rf_wsel == `WB_EXT}} & ex_sext
                            | {32{ex_rf_wsel == `WB_PC4}} & (ex_pc + 32'h4);
    
    wire [31:0] mem_forward = {32{mem_rf_wsel == `WB_ALU}} & mem_alu_c
                            | {32{mem_rf_wsel == `WB_EXT}} & mem_sext
                            | {32{mem_rf_wsel == `WB_PC4}} & (mem_pc + 32'h4);

    wire [31:0] wb_forward  = {32{wb_rf_wsel == `WB_ALU}} & wb_alu_c
                            | {32{wb_rf_wsel == `WB_EXT}} & wb_sext
                            | {32{wb_rf_wsel == `WB_PC4}} & (wb_pc + 32'h4);

    //载入-使用型数据冒险:假设数据来自于写内存.

    ALU U_ALU (
        .rst        (cpu_rst),
        .clk        (cpu_clk),
        .op         (ex_alu_op),
        .a          (ex_alu_a),
        .b          (ex_alu_b),
        .br         (br),
        .c          (alu_c),
        .busy       (mul_div_busy)  //隔一个周期后高电平有效
    );

    /***************************** MEM *****************************/
    MREQ U_MEM_REQ (
        .ram_addr   (mem_alu_c),

        .ram_rop    (mem_ram_rop),
        .da_ren     (da_ren),
        .da_addr    (da_addr),

        .ram_wop    (mem_ram_wop),
        .ram_wdata  (mem_rd2),
        .da_wen     (da_wen),
        .da_wdata   (da_wdata)
    );

    MEXT U_MEM_EXT (
        .op             (ram_rop_r),
        .din            (daccess_rdata),
        .byte_offs      (alu_c_r[1:0]),
        .ext            (ram_ext)
    );

    always @(posedge cpu_clk) if (is_ld_st) alu_c_r   <= mem_alu_c;
    always @(posedge cpu_clk) if (is_ld_st) ram_rop_r <= mem_ram_rop;

    // Interface to Bus
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            daccess_ren   <= 4'h0;
            daccess_wen   <= 4'h0;
        end else begin
            daccess_ren   <= da_ren;
            daccess_addr  <= da_addr;
            daccess_wen   <= da_wen;
            daccess_wdata <= da_wdata;
        end
    end

    assign ld_st_done = daccess_rvalid | daccess_wresp;

    /***************************** WB *****************************/
    assign rf_we1 = ld_st_flag   & daccess_rvalid |                 // Load指令在读取到数据时写回
                    mul_div_flag & !mul_div_busy  |                 // 乘除法指令在运算完成时写回
                    //TODO:ifetch_valid在流水线cpu中存在的必要性?
                    ifetch_valid & wb_rf_we & !is_ld_st & !ex_mul_div;   // 其他指令在到达WB阶段时写回
                    //ifetch_valid & wb_rf_we & !is_ld_st & !is_mul_div; // 其他指令在取到指令时写回

    assign rf_wR  = ld_st_flag | mul_div_flag ? rf_wR_r : wb_wr;


    //TODO: wD选择的流水线化未完成
    always @(*) begin
        rf_wD = wb_wd;
        // casex ({ld_st_flag, rf_wsel})
        //     {1'b0, `WB_ALU}: rf_wD = alu_c;
        //     {1'b0, `WB_PC4}: rf_wD = id_pc + 32'h4;
        //     {1'b0, `WB_EXT}: rf_wD = ext;
        //     {1'b1, 2'b??  }: rf_wD = wb_wd;
        //     default        : rf_wD = 32'h0;
        // endcase
    end

    assign inst_finished = ld_st_flag   & ld_st_done    |           // 访存指令在读写完毕时执行完成
                            mul_div_flag & !mul_div_busy |           // 乘除法指令在运算完毕时完成
                            //TODO:ifetch_valid在流水线cpu中存在的必要性?
                            //猜测:
                            ifetch_valid & !is_ld_st & !is_mul_div; //TODO: 理想流水线cpu无论如何都会在下一周期取指,因此无需上一条指令执行完毕即可
                            // 其他指令单周期完成（即取到指令的同时执行完成）

    always @(posedge cpu_clk or posedge cpu_rst) begin
        inst_finished_r <= cpu_rst ? 1'b0 : inst_finished;
    end

/*
流水线寄存器
共5级流水线,4个寄存器
目前为理想形态,无数据与控制冒险
*/

// 流水线暂停:暂停IF/ID和ID/EX,使其输入等于自身
//乘除法暂停时,EX/MEM寄存器的输入应当改为0,防止一直无限输入,乘除法一结束,数据尚未传到WB阶段,就已经激活了WB阶段的写回操作.
    wire pause = mul_div_pause | load_use_pause;
    wire mul_div_done = !mul_div_busy & mul_div_busy_r;
    wire mul_div_pause = ex_mul_div & !mul_div_done;
    wire load_use_pause = 1'b0;//占位符

    // always @ (*) begin
    //     if (rst) mul_div_pause <= 1'b0;
    //     else if (ex_mul_div & !mul_div_busy & mul_div_busy_r) mul_div_pause <= 1'b0;
    //     else if (ex_mul_div) mul_div_pause <= 1'b1;
    //     else mul_div_pause <= 1'b0;
    // end
    //由于乘除法第一个和最后一个周期都有busy=1'b0,因此关注前一个周期busy=1'b1,当前周期busy=1'b0的情况
    reg mul_div_busy_r;
    always @ (posedge clk or posedge rst) begin
        if (rst) mul_div_busy_r <= 1'b0;
        else     mul_div_busy_r <= mul_div_busy;
    end




// IF/ID
    reg [31:0] id_pc;
    reg [31:0] id_inst;
    //pc4由pc自然生成
    wire [31:0] if_inst = inst;
    reg branch_r;
    always @ (posedge clk or posedge rst) begin
        if (rst) branch_r <= 1'b0;
        else     branch_r <= branch;
    end

    //由于pc到IF/ID只需要一个周期,而pc到ifetch再到IF/ID需要两个周期,因此加一层缓冲
    reg [31:0] if_pc_r;
    always @ (posedge clk or posedge rst) begin
        if (rst)         if_pc_r <= 32'h0;
        else if (branch) if_pc_r <= 32'h0;
        else if (pause)  if_pc_r <= if_pc_r;
        else             if_pc_r <= pc;
    end

    //此外,if_inst由于直接从取值模块中连出,无法清零,因此取一个branch_r信号,在下一个周期给id_inst清零.

    always @ (posedge clk or posedge rst) begin
        if (rst)         id_pc <= 32'h0;
        else if (branch) id_pc <= 32'h0;
        else if (pause)  id_pc <= id_pc;
        else             id_pc <= if_pc_r;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         id_inst <= 32'h0;
        else if (branch | branch_r) id_inst <= 32'h0;
        else if (pause)  id_inst <= id_inst;
        else             id_inst <= if_inst;
    end

// ID/EX
    reg [31:0] ex_pc;
    reg [1:0] ex_npc_op;
    reg [2:0] ex_ram_rop;
    reg [3:0] ex_ram_wop;
    reg [4:0] ex_alu_op;
    reg [31:0] ex_alu_a;
    reg [31:0] ex_alu_b;
    reg [31:0] ex_rd2;
    reg [31:0] ex_sext;
    //TODO:删除wd信号,改为把所有信号都保留下来,方便处理forward,wd信号只在最终WB阶段判断生成.
    reg [31:0] ex_wd;   //在流水线中不断进行判断,最终到达WB阶段时获得最终的wData
    reg        ex_rf_we;
    reg [1:0]  ex_rf_wsel;
    reg [4:0]  ex_wr;
    reg        ex_mul_div;

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_pc <= 32'h0;
        else if (branch) ex_pc <= 32'h0;
        else if (pause)  ex_pc <= ex_pc;
        else             ex_pc <= id_pc;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_npc_op <= 2'b0;
        else if (branch) ex_npc_op <= 2'b0;
        else if (pause)  ex_npc_op <= ex_npc_op;
        else             ex_npc_op <= npc_op;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_ram_rop <= 3'b0;
        else if (branch) ex_ram_rop <= 3'b0;
        else if (pause)  ex_ram_rop <= ex_ram_rop;
        else             ex_ram_rop <= ram_rop;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_ram_wop <= 4'b0;
        else if (branch) ex_ram_wop <= 4'b0;
        else if (pause)  ex_ram_wop <= ex_ram_wop;
        else             ex_ram_wop <= ram_wop;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_alu_op <= 5'b0;
        else if (branch) ex_alu_op <= 5'b0;
        else if (pause)  ex_alu_op <= ex_alu_op;
        else             ex_alu_op <= alu_op;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_alu_a <= 32'h0;
        else if (branch) ex_alu_a <= 32'h0;
        else if (pause)  ex_alu_a <= ex_alu_a;
        else             ex_alu_a <= alu_a;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_alu_b <= 32'h0;
        else if (branch) ex_alu_b <= 32'h0;
        else if (pause)  ex_alu_b <= ex_alu_b;
        else             ex_alu_b <= alu_b;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_rd2 <= 32'h0;
        else if (branch) ex_rd2 <= 32'h0;
        else if (pause)  ex_rd2 <= ex_rd2;
        else             ex_rd2 <= rf_rd2;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_sext <= 32'h0;
        else if (branch) ex_sext <= 32'h0;
        else if (pause)  ex_sext <= ex_sext;
        else             ex_sext <= ext;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_wd <= 32'h0;
        else if (branch) ex_wd <= 32'h0;
        else if (pause)  ex_wd <= ex_wd;
        else begin
            case (rf_wsel)
                `WB_PC4: ex_wd <= id_pc + 32'h4;
                `WB_EXT: ex_wd <= ext;
                default: ex_wd <= 32'h0;
            endcase
        end
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_rf_we <= 1'b0;
        else if (branch) ex_rf_we <= 1'b0;
        else if (pause)  ex_rf_we <= ex_rf_we;
        else             ex_rf_we <= rf_we;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_rf_wsel <= 2'b0;
        else if (branch) ex_rf_wsel <= 2'b0;
        else if (pause)  ex_rf_wsel <= ex_rf_wsel;
        else             ex_rf_wsel <= rf_wsel;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_wr <= 5'b0;
        else if (branch) ex_wr <= 5'b0;
        else if (pause)  ex_wr <= ex_wr;
        else             ex_wr <= id_inst[11:7];
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_mul_div <= 1'b0;
        else if (branch) ex_mul_div <= 1'b0;
        else if (pause)  ex_mul_div <= ex_mul_div;
        else             ex_mul_div <= is_mul_div;
    end

// EX/MEM
    reg [31:0] mem_pc;
    reg [2:0] mem_ram_rop;
    reg [3:0] mem_ram_wop;
    reg [31:0] mem_alu_c;
    reg [31:0] mem_rd2;
    reg [31:0] mem_sext;
    reg [31:0] mem_wd;
    reg        mem_rf_we;
    reg [1:0]  mem_rf_wsel;
    reg [4:0]  mem_wr;

    always @ (posedge clk or posedge rst) begin
        if (rst) mem_pc <= 32'h0;
        else if (mul_div_pause) mem_pc <= 32'h0;
        else     mem_pc <= ex_pc;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) mem_ram_rop <= 3'h0;
        else if (mul_div_pause) mem_ram_rop <= 3'h0;
        else     mem_ram_rop <= ex_ram_rop;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) mem_ram_wop <= 4'h0;
        else if (mul_div_pause) mem_ram_wop <= 4'h0;
        else     mem_ram_wop <= ex_ram_wop;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) mem_alu_c <= 32'h0;
        else if (mul_div_pause) mem_alu_c <= 32'h0;
        else     mem_alu_c <= alu_c;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) mem_rd2 <= 32'h0;
        else if (mul_div_pause) mem_rd2 <= 32'h0;
        else     mem_rd2 <= ex_rd2;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) mem_sext <= 32'h0;
        else if (mul_div_pause) mem_sext <= 32'h0;
        else     mem_sext <= ex_sext;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) mem_wd <= 32'h0;
        else if (mul_div_pause) mem_wd <= 32'h0;
        else     mem_wd <= (ex_rf_wsel == `WB_ALU) ? alu_c : ex_wd;
    end

        always @ (posedge clk or posedge rst) begin
        if (rst) mem_rf_we <= 1'b0;
        else if (mul_div_pause) mem_rf_we <= 1'b0;
        else     mem_rf_we <= ex_rf_we;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) mem_rf_wsel <= 2'b0;
        else if (mul_div_pause) mem_rf_wsel <= 2'b0;
        else     mem_rf_wsel <= ex_rf_wsel;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) mem_wr <= 5'b0;
        else if (mul_div_pause) mem_wr <= 5'b0;
        else     mem_wr <= ex_wr;
    end

// MEM/WB
    // reg [31:0] wb_mext;
    reg [31:0] wb_pc;
    reg [31:0] wb_alu_c;
    reg [31:0] wb_sext;
    reg [31:0] wb_wd;
    reg        wb_rf_we;
    reg [1:0]  wb_rf_wsel;
    reg [4:0]  wb_wr;

    always @ (posedge clk or posedge rst) begin
        if (rst) wb_pc <= 32'h0;
        else     wb_pc <= mem_pc;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) wb_alu_c <= 32'h0;
        else     wb_alu_c <= mem_alu_c;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) wb_sext <= 32'h0;
        else     wb_sext <= mem_sext;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) wb_wd <= 32'h0;
        else     wb_wd <= ld_st_flag ? ram_ext : mem_wd;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) wb_rf_we <= 1'b0;
        else     wb_rf_we <= mem_rf_we;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) wb_rf_wsel <= 2'b0;
        else     wb_rf_wsel <= mem_rf_wsel;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) wb_wr <= 5'b0;
        else     wb_wr <= mem_wr;
    end

    // always @ (posedge clk or posedge rst) begin
    //     if (rst) wb_mext <= 32'h0;
    //     else     wb_mext <= ram_ext;
    // end

    // always @ (posedge clk or posedge rst) begin
    //     if (rst) wb_wd <= 32'h0;
    //     else     wb_wd <= (mem_rf_wsel == `WB_RAM)
    // end

    /********************* Your CPU ends here *********************/

`ifdef RUN_TRACE
    wire [31:0] debug_wb_pc    /* verilator public */ ;     // WB阶段的PC
    wire        debug_wb_rf_we /* verilator public */ ;     // WB阶段的寄存器写使能
    wire [ 4:0] debug_wb_rf_wR /* verilator public */ ;     // WB阶段的目标寄存器   (若wb_rf_we为0，此项可为任意值)
    wire [31:0] debug_wb_rf_wD /* verilator public */ ;     // WB阶段写入寄存器的值 (若wb_rf_we为0，此项可为任意值)

    wire [31:0] debug_mem_pc    /* verilator public */ ;    // MEM阶段的PC
    wire [ 3:0] debug_mem_we    /* verilator public */ ;    // MEM阶段写访存时的写使能
    wire [31:0] debug_mem_waddr /* verilator public */ ;    // MEM阶段写访存时的写地址 (若mem_we为0，此项可为任意值)
    wire [31:0] debug_mem_wdata /* verilator public */ ;    // MEM阶段写访存时的写数据 (若mem_we为0，此项可为任意值)

    assign debug_wb_pc    = wb_pc;
    assign debug_wb_rf_we = rf_we1;
    assign debug_wb_rf_wR = wb_wr;
    assign debug_wb_rf_wD = wb_wd;

    assign debug_mem_pc    = mem_pc;
    assign debug_mem_we    = daccess_wen;
    assign debug_mem_waddr = daccess_addr;
    assign debug_mem_wdata = daccess_wdata;
`endif

endmodule
