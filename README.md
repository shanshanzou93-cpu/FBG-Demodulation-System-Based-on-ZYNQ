# 基于 ZYNQ-7020 的弱光纤光栅（uwFBG）解调系统

本工程在单片 ZYNQ-7020 上实现"激光器扫描时序 + 光谱采集 + 高斯拟合寻峰解调"的完整数据通路：PL 承担确定性时序与硬件化解调，PS 承担标定码表下发、参数配置与 DMA 调度，省去独立采集卡与工控机。

<p align="center">
  <img src="docs/系统组成.png" width="760">
</p>

## 1. 系统组成

- **光源**：S7500（MG-Y 结构）可调谐激光器，1527.6–1568.4 nm，系统使用 1528–1545 nm 共 2126 个扫描点，步进 8 pm；PULSE-SOA 提供 10 ns 光门控脉冲；EDFA 补偿链路损耗。
- **光路**：环形器 → 弱光栅阵列（单纤多点复用）→ 光电探测器，反射谱由 PD 转为电压信号。
- **驱动**：LTC2662 五通道 16 bit 电流源型 DAC（SOA / GAIN / PHASE / LEFT / RIGHT），SPI 50 MHz 下发，LDAC 同步锁存，保证五路电流原子更新。
- **采集**：LTC2325-16 四通道 16 bit、5 MSPS 同步采样 ADC，共用 CNV，差分 8 Vpp。
- **探测**：LSIPD-LD50（InGaAs PIN，φ50 µm，0.9 A/W），配跨阻放大。
- **主控**：ZYNQ-7020（xc7z020clg400-2），PS-GEM0 引出 RGMII 以太网，UART1 与上位机通信。

<p align="center">
  <img src="docs/光路复用.png" width="720">
</p>

## 2. 软件架构

### PL（可编程逻辑）

| 模块 | 说明 |
|---|---|
| `turnLD`（`M_FIFO.v`） | 单点扫描窗口发生器，1500 拍 @100 MHz = 15 µs：光门控脉冲 → 5 组 24 bit SPI → LDAC 锁存 → 200 拍 ADC 时序 → 8 B/点打包 |
| `gauss_fit_demod_multi` | 高斯解调算法 IP 核（Vivado HLS），整帧 2126 点一次解出多峰中心波长，0.425 ms/帧 |
| `axi_dma` ×2 | 控制通路（MM2S→turnLD）与数据通路（ADC→S2MM→解调）分离，互不阻塞 |
| `axis_data_fifo` ×2 | 1024 深，跨模块缓冲 |
| `axi_smc` / `ps7` | 单时钟域（FCLK0 = 100 MHz）互联 |

<p align="center">
  <img src="docs/扫描窗口时序.png" width="760">
</p>

扫描窗口内的时间预算：SPI 2.97 µs + LDAC 0.02 µs + ADC 2.00 µs ≈ 4.99 µs，其余为空闲余量。

### PS（处理系统）

- 按离线六步标定生成的查找表（2126 × 5 组驱动码）索引出当前点电流码，编码为 5×32 bit 经 DMA 下发；
- 配置解调 IP 的 8 个 AXI-Lite 寄存器（λ₀、Δλ、data_len、max_peaks、thresh、min_dist、base_edge 等）；
- 逐点调度两次 DMA（发送驱动字 / 接收 8 B 采样），组帧后送入解调 IP，读取 52 B 结果并经 UART 上传上位机；
- 上位机（LabVIEW）完成全谱显示、中心波长读取与阈值示警。

### 解调算法（`hls_src/gauss_feng.cpp`）

1. 三点二项式平滑 `[1,2,1]/4`（II=1 流式）；
2. 相对阈值（0.25 × 全局最大）+ 最小峰距（50 点）寻峰，并在相邻峰中点区间内重定位；
3. 按半高自适应确定对称拟合窗（`h ≤ 40`，强制对称），扣除窗两侧邻接基线；
4. 对数域将高斯峰化为二次函数，利用**对称整数坐标**使奇次矩归零，最小二乘退化为三个累加量 + 一次除法，得亚采样峰位；
5. 128 段整数分段对数表替代浮点 log；凸性检查与质心/三点回退保证任何输入均有输出。

## 3. 目录结构

```
.
├─ dma_loop_test/                     # Vivado 工程（2018.3，xc7z020clg400-2）
│  ├─ dma_loop_test.xpr
│  ├─ rtl_1.xdc                       # 引脚与时序约束
│  ├─ dma_loop_test.srcs/             # Block Design + IP + RTL
│  │  ├─ sources_1/bd/dma_loop_test/  # BD（含 HLS IP 的 .dcp）
│  │  ├─ sources_1/new/M_FIFO.v       # turnLD：扫描窗口时序
│  │  ├─ sources_1/new/LTC2262.v
│  │  └─ constrs_1/
│  └─ dma_loop_test.sdk/
│     ├─ feng/src/                    # PS 裸机程序
│     └─ dma_loop_test_wrapper.hdf    # 硬件描述（可直接导入 SDK）
├─ hls_src/                           # 高斯解调算法 HLS 源码
│  ├─ gauss_feng.cpp
│  └─ gauss_feng.h
├─ M_FIFO.v  LTC2262.v                # 顶层 RTL 副本
├─ laser_scan_data.h                  # 扫描标定查找表
└─ docs/                              # 示意图
```

## 4. 复现步骤

**Vivado 侧**

1. Vivado 2018.3 打开 `dma_loop_test/dma_loop_test.xpr`；
2. 顶层为 BD `dma_loop_test`，HLS IP 以 `.dcp` 形式提供，无需重跑 HLS 综合；
3. Generate Bitstream（约 20–40 min）→ File ▸ Export ▸ Export Hardware（勾选 Include bitstream）。

**SDK 侧**

1. Xilinx SDK 2018.3，Workspace 指向 `dma_loop_test/dma_loop_test.sdk`；
2. File ▸ Import ▸ General ▸ Existing Projects into Workspace，导入 `feng`；
3. 若工程报找不到硬件平台，用 `dma_loop_test_wrapper.hdf` 重新 Create Hardware Platform 并 Re-target BSP；
4. Program FPGA → Run `feng`，串口 115200 输出解调结果。

> HLS 源码位于 `hls_src/`，如需重新生成 IP：Vivado HLS 2018.3，器件 `xc7z020clg400-2`，顶层函数 `gauss_fit_demod_multi`，导出 IP 后在 BD 中替换 `turnLD` 之外的解调核即可（接口逐字一致）。

## 5. 主要指标

| 项目 | 数值 |
|---|---|
| 扫描范围 / 点数 | 1528–1545 nm，2126 点 × 8 pm |
| 波长精度 | ±3 pm（与商用波长计比对的一致性） |
| 波长解调重复性 | 2.187 pm（同条件十帧标准差） |
| 波长分辨率 | 1 pm（1 pm 阶跃加载/卸载可分辨） |
| 解调 IP 吞吐 | 0.425 ms/帧（整机刷新率受 DMA 与串口约束，约 0.5 Hz） |
| 应变灵敏度 | 1.13 pm/με（R² = 0.99979） |
| 温度灵敏度 | 约 8.9–10.1 pm/℃（六栅点） |
| 资源占用 | LUT 15,504（29.14%）、FF 16,844、BRAM 12、DSP 31 |
| 时序 | WNS +0.188 ns / WHS +0.036 ns，0 失败端点 |
| 片上功耗 | 1.882 W（PS7 1.534 W + PL 0.348 W） |

