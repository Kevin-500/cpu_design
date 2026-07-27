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
    wire [ 3:0] ram_wop;
    wire        is_mul;
    wire        is_div;
    wire        is_mul_div;
    // reg         mul_div_flag;       // 乘除法运算的标志位信号

    // Register File
    wire [31:0] rf_rd1;
    wire [31:0] rf_rd2;
    wire        rf_we;
    wire        rf_we1;
    wire [ 4:0] rf_wR;
    reg  [31:0] rf_wD;

    // Signed Extension
    wire [31:0] ext;

    // ALU
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_c;
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

    /***************************** IF *****************************/

    assign ifetch_req = 1'b1;//取值请求信号,假设一直有效
    assign ifetch_addr = pc; //取值地址

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
    // pc_npc由于branch变为ex_pc,此时由于ICache正在读取指令,不会接受外部信号,导致branch信号被忽视
    wire [31:0] pc_npc = (pre_pause | pause | !ifetch_valid) ? pc : npc;

    // 原始逻辑:ex阶段判断需要branch时,pc信号生成后立刻传递给ICache
    // 加入Cache后的问题:此时Cache状态机还未恢复到IDLE,因此输入的信号会被无视
    // 解决:加入寄存器,保存到Cache恢复IDLE之后,再将这些信号传递给Cache

    // 表示从计算出需要branch后到上一条(错误的)指令从ICache取指完毕为止
    reg wait_icache;
    always @ (posedge clk or posedge rst) begin
        if (rst) wait_icache <= 1'b0;
        else if (branch) wait_icache <= 1'b1;
        else if (ifetch_valid) wait_icache <= 1'b0;
    end

    // 表示
    reg [31:0] pc_wait_icache;
    always @ (posedge clk or posedge rst) begin
        if (rst) pc_wait_icache <= 32'h0;
        else if (branch) pc_wait_icache <= npc;
        else if (ifetch_valid & !wait_icache) pc_wait_icache <= 32'h0;
        // 第一个ifetch_valid是取的上一条(错误的)指令,因此pc_wait_icache需要保留到正确的指令取指完毕
    end


    NPC U_NPC (
        .op         (final_npc_op),
        .pc         (npc_pc),
        .offset     (npc_offset),
        .br         (br),
        .npc        (npc),
        .pc4        (pc4)
    );


    wire [31:0] pc_pc;
    assign pc = pc_wait_icache != 32'h0 ? pc_wait_icache : pc_pc; 
    PC U_PC (
        .clk        (cpu_clk),
        .rst        (cpu_rst),
        .npc        (pc_npc),
        .fetch      (1'b1),    //fetch原本用于在单周期cpu中确定指令是否执行完毕,而在流水线cpu中,指令是否执行完毕与pc是否步进无关,因此改为1'b1
        .pc         (pc_pc)
    );
    
    /***************************** ID *****************************/
    // 在单周期cpu中,按照约定的时序，ifetch_inst只在ifetch_valid有效时有效，且它们仅有效1个时钟.
    // 在流水线cpu中,让ifetch_req持续为1,ifetch_inst和ifetch_valid持续有效,
    // 但是读到的指令是否会被传递到下游流水线中由其他信号决定(pause和控制信号等)
    //不再使用NOP指令填补空缺
    assign inst = ifetch_inst;

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
    // is_ld_st只拉高一个周期,而ld_st_flag在完成之前持续拉高
    // is_ld_st表明访存指令处于mem阶段,而ex_ld_st表明访存指令处于ex阶段
    assign is_ld_st = (mem_ram_rop != `RAM_EXT_N) | (mem_ram_wop != `RAM_WE_N);
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if      (cpu_rst)    ld_st_flag <= 1'b0;
        else if (is_ld_st)   ld_st_flag <= 1'b1;
        else if (ld_st_done) ld_st_flag <= 1'b0;
    end

    assign is_mul_div = is_mul | is_div;

    /***************************** EX *****************************/

    //数据冒险
    //按优先级排序
    assign alu_a    = alua_sel ? id_pc  
                    : (ld_st_ex_rs1_hazard ? ram_ext 
                    : (ex_rs1_hazard ? ex_forward 
                    : (ld_st_mem_rs1_hazard ? wb_wd
                    : (mem_rs1_hazard ? mem_forward 
                    : (ld_st_wb_rs1_hazard ? wb_wd
                    : (wb_rs1_hazard ? wb_forward 
                    : rf_rd1))))));

    assign alu_b    = alub_sel ? ext 
                    : (ld_st_ex_rs2_hazard ? ram_ext 
                    : (ex_rs2_hazard ? ex_forward 
                    : (ld_st_mem_rs2_hazard ? wb_wd
                    : (mem_rs2_hazard ? mem_forward 
                    : (ld_st_wb_rs2_hazard ? wb_wd
                    : (wb_rs2_hazard ? wb_forward 
                    : rf_rd2))))));
    assign npc_offset = (ex_npc_op == `NPC_JALR) ? alu_c : ex_sext;

    //RAW型数据冒险:数据来自于ALU计算结果或立即数或PC地址
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

    //load-use型数据冒险:数据来自于写内存.
    //由于暂停,需求数据的指令处在ID阶段时,前一条load指令处在MEM阶段,而其对应的wsel和we信号因暂停处于EX阶段,落后于wdata一个阶段
    //因此虽然数据来源是MEM阶段的ram_ext,但仍按照wsel的位置归类为ex冒险
    //mem和wb同理
    wire ld_st_ex_rs1_hazard = ex_rs1_hazard & ex_rf_wsel == `WB_RAM;
    wire ld_st_ex_rs2_hazard = ex_rs2_hazard & ex_rf_wsel == `WB_RAM;

    wire ld_st_mem_rs1_hazard = mem_rs1_hazard & mem_rf_wsel == `WB_RAM;
    wire ld_st_mem_rs2_hazard = mem_rs2_hazard & mem_rf_wsel == `WB_RAM;

    wire ld_st_wb_rs1_hazard = wb_rs1_hazard & wb_rf_wsel == `WB_RAM;
    wire ld_st_wb_rs2_hazard = wb_rs2_hazard & wb_rf_wsel == `WB_RAM;

    //写内存-读内存数据冒险:先sw/sh/sb再lw/lh/lb
    //具体区别在于上述两种数据冒险需要把数据传递给alu_a和alu_b,而该冒险需要把数据传递给MREQ
    wire [31:0] id_ram_wdata;
    assign id_ram_wdata = ld_st_ex_rs2_hazard ? ram_ext 
                        : (ex_rs2_hazard ? ex_forward 
                        : (ld_st_mem_rs2_hazard ? wb_wd
                        : (mem_rs2_hazard ? mem_forward 
                        : (ld_st_wb_rs2_hazard ? wb_wd
                        : (wb_rs2_hazard ? wb_forward 
                        : rf_rd2)))));
    

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
        .ram_wdata  (mem_ram_wdata),
        .da_wen     (da_wen),
        .da_wdata   (da_wdata)
    );

    MEXT U_MEM_EXT (
        .op             (mem_ram_rop_r),
        .din            (daccess_rdata),
        .byte_offs      (mext_offset),//使用保存的偏移量.
        .ext            (ram_ext)
    );

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

    /***************************** WB *****************************/

    //假设只要到达WB阶段的we信号均有效
    assign rf_we1 = wb_rf_we;
    //假设wR信号随着流水线自然传递到WB阶段,不需要额外的寄存器
    assign rf_wR  = wb_wr;


    //TODO: wD选择的流水线化未完成
    always @(*) begin
        rf_wD = wb_wd;
    end

/*
流水线寄存器
共5级流水线,4个寄存器
目前为理想形态,无数据与控制冒险
*/

// 流水线暂停:暂停IF/ID和ID/EX,使其输入等于自身,但是ID/EX中alu相关的输入需要清零,防止重复输入alu
//乘除法暂停时,EX/MEM寄存器的输入应当改为0,防止一直无限输入,乘除法一结束,数据尚未传到WB阶段,就已经激活了WB阶段的写回操作.
//访存暂停时,ID/EX寄存器中数值清零,防止解除暂停后重复执行
    wire pause = mul_div_pause | ld_st_pause;
// 在ID阶段的预暂停,负责提前暂停指令地址相关的数据,在流水线加入ICache后由于ICache时序原因,原本从ex阶段暂停会让pc错误停留在下下个指令地址处,漏掉一个指令.
    wire pre_pause = is_mul_div | (ram_rop != 3'b0 | ram_wop != 4'b0);
    wire mul_div_done = !mul_div_busy & mul_div_busy_r;
    wire mul_div_pause = ex_mul_div & !mul_div_done;
    wire ld_st_done = daccess_rvalid | daccess_wresp;
    wire ld_st_pause = ((ex_ram_rop != 3'b0) | (ex_ram_wop != 4'b0) | is_ld_st | ld_st_flag) & !ld_st_done; //从ex阶段就开始暂停,规避mem阶段访存且ex阶段乘除法的复杂情况.

    //由于乘除法第一个和最后一个周期都有busy=1'b0,因此只有前一个周期busy=1'b1,当前周期busy=1'b0的情况才能判断乘除法计算完成
    reg mul_div_busy_r;
    always @ (posedge clk or posedge rst) begin
        if (rst) mul_div_busy_r <= 1'b0;
        else     mul_div_busy_r <= mul_div_busy;
    end

    //访存暂停时,offset值由alu_c给出,因此需要一个寄存器来保存这个偏移量
    reg [1:0] mext_offset;
    always @ (posedge clk or posedge rst) begin
        if (rst) mext_offset <= 2'b0;
        else if ((ex_ram_rop != 3'b0) | (ex_ram_wop != 4'b0)) mext_offset <= alu_c;
    end


// IF/ID
    reg [31:0] id_pc;
    reg [31:0] id_inst;
    //pc4由pc自然生成
    
    wire [31:0] if_inst = inst;

    reg [31:0] if_inst_buf;
    always @ (posedge clk or posedge rst) begin
        if (rst) if_inst_buf <= 32'h0;
        else if (ifetch_valid & !wait_icache) if_inst_buf <= if_inst;
    end


    reg branch_r;
    always @ (posedge clk or posedge rst) begin
        if (rst) branch_r <= 1'b0;
        else     branch_r <= branch;
    end

    reg ifetch_valid_r;
    always @ (posedge clk or posedge rst) begin
        if (rst) ifetch_valid_r <= 1'b0;
        else     ifetch_valid_r <= ifetch_valid & !wait_icache;
    end

    //由于pc到IF/ID只需要一个周期,而pc到ifetch再到IF/ID需要两个周期,因此加一层缓冲,确保同周期到达IF/ID寄存器
    reg [31:0] if_pc_r;
    always @ (posedge clk or posedge rst) begin
        if (rst)         if_pc_r <= 32'h0;
        else if (branch) if_pc_r <= 32'h0;
        else if (pause)  if_pc_r <= if_pc_r;
        else if (ifetch_valid & !wait_icache) if_pc_r <= pc;
    end

    //if_inst由于直接从取值模块中连出,无法清零,因此取一个branch_r信号,在下一个周期给id_inst清零.

    always @ (posedge clk or posedge rst) begin
        if (rst)         id_pc <= 32'h0;
        else if (branch) id_pc <= 32'h0;
        else if (pause)  id_pc <= id_pc;
        else if (ifetch_valid_r & !mul_div_done & !ld_st_done) id_pc <= if_pc_r;
        else             id_pc <= 32'h0;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         id_inst <= 32'h0;
        else if (branch | branch_r) id_inst <= 32'h0;
        else if (pause)  id_inst <= id_inst;
        else if (ifetch_valid_r & !mul_div_done & !ld_st_done) id_inst <= if_inst_buf;
        else             id_inst <= 32'h0;
    end

// ID/EX
    reg [31:0] ex_pc;
    reg [1:0] ex_npc_op;
    reg [2:0] ex_ram_rop;
    reg [3:0] ex_ram_wop;
    reg [4:0] ex_alu_op;
    reg [31:0] ex_alu_a;
    reg [31:0] ex_alu_b;
    reg [31:0] ex_ram_wdata;
    reg [31:0] ex_sext;
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
        else if (mul_div_pause)  ex_ram_rop <= ex_ram_rop;
        else if (ld_st_pause) ex_ram_rop <= 3'b0;
        else             ex_ram_rop <= ram_rop;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_ram_wop <= 4'b0;
        else if (branch) ex_ram_wop <= 4'b0;
        else if (mul_div_pause)  ex_ram_wop <= ex_ram_rop;
        else if (ld_st_pause) ex_ram_wop <= 4'b0;
        else             ex_ram_wop <= ram_wop;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_alu_op <= 5'b0;
        else if (branch) ex_alu_op <= 5'b0;
        else if (pause)  ex_alu_op <= 5'b0; //多周期指令时只输入一次alu信号即可
        else             ex_alu_op <= alu_op;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_alu_a <= 32'h0;
        else if (branch) ex_alu_a <= 32'h0;
        else if (pause)  ex_alu_a <= 32'h0; //多周期指令时只输入一次alu信号即可
        else             ex_alu_a <= alu_a;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_alu_b <= 32'h0;
        else if (branch) ex_alu_b <= 32'h0;
        else if (pause)  ex_alu_b <= 32'h0; //多周期指令时只输入一次alu信号即可
        else             ex_alu_b <= alu_b;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_ram_wdata <= 32'h0;
        else if (branch) ex_ram_wdata <= 32'h0;
        else if (pause)  ex_ram_wdata <= ex_ram_wdata;
        else             ex_ram_wdata <= id_ram_wdata;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst)         ex_sext <= 32'h0;
        else if (branch) ex_sext <= 32'h0;
        else if (pause)  ex_sext <= ex_sext;
        else             ex_sext <= ext;
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
    reg [31:0] mem_ram_wdata;
    reg [31:0] mem_sext;
    reg        mem_rf_we;
    reg [1:0]  mem_rf_wsel;
    reg [4:0]  mem_wr;

    //ram相关指令进入EX/MEM寄存器后只保留一个周期,因此需要单独用一个寄存器持久化保存rop信号供MEXT使用
    reg [2:0] mem_ram_rop_r;
    always @ (*) begin
        if (rst) mem_ram_rop_r = 3'b0;
        else if (mem_ram_rop != 3'b0) mem_ram_rop_r = mem_ram_rop;
    end

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
        if (rst) mem_ram_wdata <= 32'h0;
        else if (mul_div_pause) mem_ram_wdata <= 32'h0;
        else     mem_ram_wdata <= ex_ram_wdata;
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) mem_sext <= 32'h0;
        else if (mul_div_pause) mem_sext <= 32'h0;
        else     mem_sext <= ex_sext;
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

    //为同步时序,ld_st_done的下下个周期才开始写入读内存数据
    //访存指令进入mem阶段时,上一个指令被冻结在id阶段,差了一个周期,因此需要让访存指令在wb阶段等一个周期.
    reg ld_st_done_r;
    always @ (posedge clk or posedge rst) begin
        if (rst) ld_st_done_r <= 1'b0;
        else ld_st_done_r <= ld_st_done;
    end

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
        else if (ld_st_done)    wb_wd <= ram_ext;
        else if (ld_st_done_r)  wb_wd <= wb_wd;
        else begin
            case (mem_rf_wsel)
                `WB_ALU: wb_wd <= mem_alu_c;
                `WB_PC4: wb_wd <= mem_pc + 32'h4;
                `WB_EXT: wb_wd <= mem_sext;
            endcase
        end
    end

    //对于wb_rf_we,假如是访存指令,则等到访存结束再接受上级流水线信号,其他指令则直接接受
    //保证了只要是传递到wb阶段的we信号,就一定是有效的wb信号,不再需要进行额外的判断,直接传入寄存器即可.
    always @ (posedge clk or posedge rst) begin
        if (rst) wb_rf_we <= 1'b0;
        // if (is_ld_st | ld_st_flag) wb_rf_we <= ld_st_done ? mem_rf_we : 1'b0;
        if (is_ld_st | ld_st_flag) wb_rf_we <= 1'b0;
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
