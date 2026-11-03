`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: hd
// Engineer: 
// 
// Create Date: 2025/01/14 11:32:19
// Design Name: lxy
// Module Name: LTC2262
// Project Name: s7500
// Target Devices: xc7z020
// Tool Versions: 18.3
// Description: ltc2262 driver
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module LTC2262(
    input[31:0] Ld_Data,                // 输入数据
    input Ld_SClkp,                     // 100MHz
    input Data_Valid,                   // 数据有效
    input Reset,                        // Spi复位
    input Setup,                        // DA芯片配置
        
    output reg Read_Data = 1'b0,        // Ram read
    //output reg Spi_WriteEn =1'b0,
    output reg Spi_Clear = 1'b0,        // DA复位
    output reg Spi_SClk = 1'b1,         // Spi接口时钟输出
    output reg Spi_SDO = 1'b1,          // Spi串行数据输出
    output reg Spi_CsLd = 1'b1,         // Spi片选，低电平接口片选，高电平DA数据载入
    output reg Spi_Ladc = 1'b1,         // Spi_Cs/L高电平，Ladc下降沿DA输出更新
    output reg Optical_Pulse = 1'b0     // 光脉冲输出
    //output reg[5:0] Spi_Cnt = 6'h0,   // Spi计数器（最大64）
    //output reg[31:0] Spi_Data = 32'hffff_ffff,  // Spi 并行数据
    //output reg[10:0] OptPulse_Cnt = 11'h0     // 光脉冲计数器
    );
    reg[5:0] Spi_Cnt = 6'h0;            // Spi计数器（最大64）
    reg[31:0] Spi_Data = 32'hff_ffff;   // Spi 并行数据
    reg[10:0] OptPulse_Cnt = 11'h0;     // 光脉冲计数器
    reg Spi_WriteEn =1'b0;              // Spi 串行总线写入使能
//------------------------  Turnable Laser Spi ----------------------------------------------
    //---- Reset and Optical Pulse ------------------------------------------------------
    always @(posedge Ld_SClkp) begin
        if(Reset == 1'b0) begin
            Read_Data <= 1'b0;          // Ram read 读Spi并行写入数据
            Spi_Clear <= 1'b0;          // DA复位
            Spi_Ladc <= 1'b1;           // Spi_Cs/Ld
            Optical_Pulse <= 1'b0;      // 光脉冲复位
            Spi_Data <= 32'hffff_ffff;  //  Spi并行数据设置为ff_ffff
            OptPulse_Cnt <= 11'h0;      //  光脉冲计数器清零
            Spi_WriteEn =1'b0;          //  Spi写使能复位
        end
        else if( OptPulse_Cnt == 11'd1499)begin    // 1500(5dc)15uS     
            OptPulse_Cnt <= 11'h0;   
        end
        else begin
            OptPulse_Cnt <= OptPulse_Cnt +11'h1; 
            Spi_Clear <= 1'h1;
        end
    end
    //---- Spi Data Write ---------------------------------------------
    //---- Spi 总线周期使用光脉冲计数器(OptPulse_Cnt) 
    always @(posedge Ld_SClkp) begin
        case(OptPulse_Cnt)
        11'd2:  Optical_Pulse <= 1'h1;                        // OptPulse_Cnt = 2 光脉冲输出，脉冲宽度10nS
        11'd3:  Optical_Pulse <= 1'h0;
        11'd4:  if(Data_Valid == 1'h1) Read_Data <= 1'b1;     // OptPulse_Cnt = 4 读缓冲区数据 
        11'd6:  begin                                         // Data1  OptPulse_Cnt = 6 写入Spi并行数据 
                    if(Read_Data == 1'h1) begin
                        Spi_Data <= Ld_Data;
                        Spi_WriteEn <= 1'd1;                  // 启动串并转换
                    end
                    else Spi_Data <= 32'hffff_ffff;
                end
        11'd7:  Read_Data <= 1'b0;                            // 并行数据写入结束
        11'd64: if(Data_Valid == 1'h1) Read_Data <= 1'b1;
        11'd66: begin                                         // Data2
                    if(Read_Data == 1'h1) begin
                        Spi_Data <= Ld_Data;
                        Spi_WriteEn <= 1'd1;
                    end
                    else Spi_Data <= 32'hffff_ffff;
                end
        11'd67: Read_Data = 1'b0;
        11'd124:if(Data_Valid == 1'h1) Read_Data <= 1'b1;
        11'd126:begin                                         // Data3
                    if(Read_Data == 1'h1) begin
                        Spi_Data <= Ld_Data;
                        Spi_WriteEn <= 1'd1;
                    end
                    else Spi_Data <= 32'hffff_ffff;
                end
        11'd127:Read_Data = 1'b0;
        11'd184:if(Data_Valid == 1'h1) Read_Data <= 1'b1;
        11'd186:begin                                         // Data4
                    if(Read_Data== 1'h1) begin
                        Spi_Data <= Ld_Data;
                        Spi_WriteEn <= 1'd1;
                    end
                    else Spi_Data <= 32'hffff_ffff;
                end
        11'd187: Read_Data = 1'b0;
        11'd244:begin
                    if(Data_Valid == 1'h1) Read_Data <= 1'b1;
                    else Read_Data <= 1'b0;
                end
        11'd246:begin                                         // Data5
                    if(Read_Data == 1'h1) begin
                        Spi_Data <= Ld_Data;
                        Spi_WriteEn <= 1'd1;
                    end
                    else Spi_Data <= 32'hffff_ffff;
                    end
        11'd247:Read_Data <= 1'b0;
        11'd306:begin                                         //  DAC Output
                    Spi_Data <= 32'hffff_ffff;
                    if(Setup == 1'b0)  Spi_Ladc <= 1'b0;
                end
        11'd308:Spi_Ladc <= 1'h1;  // if(OptPulse_Cnt == 11'h248) Optical_Pulse <= 1'h1;
        default:begin
                     Optical_Pulse <= 1'h0;
                end
        endcase
    end
    //---- Spi Data Crystal ------------------------------------------
    always @(posedge Ld_SClkp) begin
        if(Reset == 1'b0) begin
            Spi_Cnt <= 6'h0; 
        end
        else if(Spi_Cnt >= 6'd54)begin
            Spi_Cnt <= 6'h0;
            Spi_WriteEn <= 1'd0;
        end
        else if(Spi_WriteEn == 1'd1)  Spi_Cnt <= Spi_Cnt + 6'h1;
        else Spi_Cnt <=  6'h0;        
    end
    //---- Spi Data Output -------------------------------------------
    always @(posedge Ld_SClkp) begin
        if(Reset == 1'b0) begin
            Spi_SDO <= 1'b1;
            Spi_CsLd <= 1'b1;
            Spi_SClk <= 1'b1;
        end
        else begin
            case(Spi_Cnt)
                6'd2:   Spi_CsLd <= 1'b0;               // Chip select
                6'd3:   begin 
                        Spi_SClk <= 1'b0;
                        Spi_SDO  <= Spi_Data[23]; 
                        end
                6'd4:   Spi_SClk <= 1'b1;
                6'd5:   begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[22]; 
                        end 
                6'd6:   Spi_SClk <= 1'b1;
                6'd7:   begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[21]; 
                        end 
                6'd8:   Spi_SClk <= 1'b1;
                6'd9:   begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[20]; 
                        end 
                6'd10:  Spi_SClk <= 1'b1;
                6'd11:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[19]; 
                        end 
                6'd12:  Spi_SClk <= 1'b1;
                6'd13:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[18]; 
                        end 
                6'd14:  Spi_SClk <= 1'b1;
                6'd15:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[17]; 
                        end 
                6'd16:  Spi_SClk <= 1'b1;
                6'd17:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[16]; 
                        end 
                6'd18:  Spi_SClk <= 1'b1;
                6'd19:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[15]; 
                        end 
                6'd20:  Spi_SClk <= 1'b1;
                6'd21:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[14]; 
                        end 
                6'd22:  Spi_SClk <= 1'b1;
                6'd23:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[13]; 
                        end 
                6'd24:  Spi_SClk <= 1'b1;
                6'd25:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[12]; 
                        end 
                6'd26:  Spi_SClk <= 1'b1;
                6'd27:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[11]; 
                        end 
                6'd28:  Spi_SClk <= 1'b1;
                6'd29:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[10]; 
                        end 
                6'd30:  Spi_SClk <= 1'b1;
                6'd31:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[9]; 
                        end 
                6'd32:  Spi_SClk <= 1'b1;
                6'd33:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[8]; 
                        end 
                6'd34:  Spi_SClk <= 1'b1;
                6'd35:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[7]; 
                        end 
                6'd36:  Spi_SClk <= 1'b1;
                6'd37:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[6]; 
                        end 
                6'd38:  Spi_SClk <= 1'b1;
                6'd39:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[5]; 
                        end 
                6'd40:  Spi_SClk <= 1'b1;
                6'd41:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[4]; 
                        end 
                6'd42:  Spi_SClk <= 1'b1;
                6'd43:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[3]; 
                        end 
                6'd44:  Spi_SClk <= 1'b1;
                6'd45:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[2]; 
                        end 
                6'd46:  Spi_SClk <= 1'b1;
                6'd47:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[1]; 
                        end 
                6'd48:  Spi_SClk <= 1'b1;
                6'd49:  begin 
                            Spi_SClk <= 1'b0;
                            Spi_SDO  <= Spi_Data[0]; 
                        end 
                6'd50:  Spi_SClk <= 1'b1;                // sdo end
                6'd51:  Spi_SDO  <= 1'b1; 
                6'd52:  begin
                            Spi_SClk <= 1'b0;
                            Spi_CsLd <= 1'b1;
                        end
                6'd53: Spi_SClk <= 1'b1;
                default:begin
                            Spi_SClk <= 1'b1;  
                            Spi_SDO  <= 1'b1;
                            //Spi_CsLd <= 1'b1;
                          end
            endcase
        end            
    end        
endmodule
