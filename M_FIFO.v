`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/01/26 12:35:18
// Design Name: 
// Module Name: M_FIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


 module M_FIFO(
  input aresetn,
  input s_axis_aclk,
  input s_axis_tvalid,
  output s_axis_tready,
  input[31:0] s_axis_tdata,
  //input[3:0] s_axis_tkeep,
  input s_axis_tlast,
  
  input m_axis_aclk,
  input m_axis_tready,
  output reg m_axis_tvalid,
  output[31:0] m_axis_tdata,
  output reg[3:0] m_axis_tkeep,
  output m_axis_tlast
);

// FIFO18E1: 18Kb FIFO (First-In-First-Out) Block RAM Memory
   //           Artix-7
   // Xilinx HDL Language Template, version 2018.3
   //wire m_axis_tvalidn;
   wire s_axis_treadyn;
   wire areset;
   wire read_en;
   reg read;
   wire write_en;
   wire empty;
   assign areset = !aresetn;
   //assign m_axis_tkeep = 4'hf;
   assign s_axis_tready = !s_axis_treadyn;
   always @(posedge  m_axis_aclk)begin
        if(empty == 1'b1)begin
            m_axis_tvalid <= 1'b0;
            m_axis_tkeep <= 4'h0;  
            read <= 0'b0;
        end
        else if(read_en == 1'b1)begin
            m_axis_tvalid <= 1'b1;
            m_axis_tkeep <= 4'hf;
        end
        else read <= 1'b1; 
   end 
   assign m_axis_tlast = m_axis_tvalid & empty;
   assign read_en = m_axis_tready & read & aresetn;
   assign write_en = s_axis_tvalid & s_axis_tready & aresetn;
   
   FIFO18E1 #(
      .ALMOST_EMPTY_OFFSET(13'h0006),       // Sets the almost empty threshold
      .ALMOST_FULL_OFFSET(13'h01f0),        // Sets almost full threshold
      .DATA_WIDTH(36),                      // Sets data width to 4-36
      .DO_REG(1),                           // Enable output register (1-0) Must be 1 if EN_SYN = FALSE
      .EN_SYN("FALSE"),                    // Specifies FIFO as dual-clock (FALSE) or Synchronous (TRUE)
      .FIFO_MODE("FIFO18"),                // Sets mode to FIFO18 or FIFO18_36
      .FIRST_WORD_FALL_THROUGH("FALSE"),   // Sets the FIFO FWFT to FALSE, TRUE
      .INIT(36'h000000000),                  // Initial values on output port
      .SIM_DEVICE("7SERIES"),              // Must be set to "7SERIES" for simulation behavior
      .SRVAL(36'h000000000)                 // Set/Reset value for output port
   )
   FIFO18E1_inst (
      // Read Data: 32-bit (each) output: Read output data
      .DO(m_axis_tdata),                   // 32-bit output: Data output       
      .DOP(),                               // 4-bit output: Parity data output
      // Status: 1-bit (each) output: Flags and other FIFO status outputs
      .ALMOSTEMPTY(),                       // 1-bit output: Almost empty flag
      .ALMOSTFULL(),                        // 1-bit output: Almost full flag
      .EMPTY(empty),                        // 1-bit output: Empty flag
      .FULL(s_axis_treadyn),                          // 1-bit output: Full flag
      .RDCOUNT(),                           // 12-bit output: Read count
      .RDERR(),                             // 1-bit output: Read error
      .WRCOUNT(),                           // 12-bit output: Write count
      .WRERR(),                             // 1-bit output: Write error
      // Read Control Signals: 1-bit (each) input: Read clock, enable and reset input signals
      .RDCLK(m_axis_aclk),                        // 1-bit input: Read clock
      .RDEN(read_en),                          // 1-bit input: Read enable
      .REGCE(1'b1),                        // 1-bit input: Clock enable
      .RST(areset),                            // 1-bit input: Asynchronous Reset
      .RSTREG(1'b0),                      // 1-bit input: Output register set/reset
      // Write Control Signals: 1-bit (each) input: Write clock and enable input signals
      .WRCLK(s_axis_aclk),                        // 1-bit input: Write clock
      .WREN(write_en),                            // 1-bit input: Write enable
      // Write Data: 32-bit (each) input: Write input data
      .DI(s_axis_tdata),                    // 32-bit input: Data input
      .DIP()                            // 4-bit input: Parity input
   );

   // End of FIFO18E1_inst instantiation
endmodule
