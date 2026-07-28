# Vivado 仿真测试 sort_test 操作指南

## 准备工作

### 1. 编译 sort_test 生成 .coe 文件（需要 RISC-V 工具链，WSL/Linux 中执行）

```bash
cd F:/file/workspace/verilog/cpu_design/c_test_rv_stu/c_test/2_sort_test/
bash compile.sh
# 生成 main.coe 文件
```

### 2. 将 .coe 转换为仿真用的 .mem 格式

```bash
python3 coe2mem.py main.coe sort_test.mem
```

### 3. 将 sort_test.mem 复制到仿真目录

把 `sort_test.mem` 放到 `test/` 目录下。

---

## Vivado 仿真设置

### 方法一：纯 Verilog 仿真（推荐，无需 Xilinx IP）

仿真用到的文件（全部纯 Verilog，不需要 IP 核）：
```
../流水线整合/defines.vh
../流水线整合/cpu_core.v         （或替换为新版 ../cpu_core.v 对比测试）
../流水线整合/cpu_top.v
../流水线整合/Controller.v
../流水线整合/RF.v
../流水线整合/ALU.v
../流水线整合/NPC.v
../流水线整合/PC.v
../流水线整合/SEXT.v
../流水线整合/MREQ.v
../流水线整合/MEXT.v
../流水线整合/multiplier.v
../流水线整合/divider.v
../流水线整合/ICache.v
../流水线整合/DCache.v
../流水线整合/cache_line_ram.v
../流水线整合/axi_master.v
test/sort_sim_tb.sv              （testbench）
test/sort_test.mem               （程序镜像）
```

步骤：
1. Vivado 中 Add Sources → 添加上面所有 .v 文件
2. 将 sort_sim_tb.sv 设置为 top-level simulation source
3. Run Simulation → Run Behavioral Simulation

### 方法二：使用 Vivado 项目的完整 SoC 仿真

需要 Vivado 项目包含 `bram_axi` IP 和所有外设 wrapper。

---
## 修改 UART 输入数据

在 `sort_sim_tb.sv` 第 176-179 行修改预置的 UART 输入：

```verilog
// Phase 0: 8 integers (space-separated, one line)
push_string("1 2 3 4 5 6 7 8");   // ← 改成你想测试的数据
push_string("\n");
// Phase 1: array size (single integer)
push_string("20");                  // ← 改成数组大小
push_string("\n");
```

---
## 对比测试

要对比旧版 `cpu_core.v` 和新版 `cpu_core.v`，只需在 Vivado 中替换 `cpu_core.v` 源文件即可，其他所有文件保持不变。

---
## 控制台输出

仿真时 UART 输出会直接打印到 Vivado 的 Tcl Console 窗口，格式与下板时串口输出完全一致。

超时保护：5,000,000 周期自动结束仿真。
