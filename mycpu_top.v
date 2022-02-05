`timescale 1ns / 1ps


module mycpu_top(
	input wire clk,resetn,
	input wire [5:0] int, 

    output wire        inst_sram_en   , //pc_en
    output wire [3 :0] inst_sram_wen  , //置零
    output wire [31:0] inst_sram_addr , //pc
    output wire [31:0] inst_sram_wdata, //0
    input  wire [31:0] inst_sram_rdata, //instr
    // data sram
    output wire        data_sram_en   , 
    output wire [3 :0] data_sram_wen  ,
    output wire [31:0] data_sram_addr ,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    output [31:0] debug_wb_pc      ,
    output [3 :0] debug_wb_rf_wen  ,
    output [4 :0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata,
    output [5:0] ext_int
    );
    

    wire [31:0] pcF,instrF,readdataM;
    wire [31:0] dataadr;
    wire [31:0] writedata;
    wire [3:0] mem_wenM;
    wire memwrite;
    wire [31:0] pcW;
    wire [3:0] regwriteW4;
    wire [31:0] resultW;
    wire [4:0] writeregW;
    wire memenM;
    wire [31:0] aluoutM_addr;
    wire [31:0] pcconvertF;

    assign ext_int = 6'b000000;

    assign inst_sram_en    = 1'b1;
    assign inst_sram_wen   = 4'b0;
    assign inst_sram_addr  = pcconvertF;
    assign inst_sram_wdata = 32'b0;
    assign instrF = inst_sram_rdata;
    // data sram
    assign data_sram_en    = 1'b1;// store 和 load 置1，57条时需要修改
    assign data_sram_wen   = mem_wenM;// store 
    assign data_sram_addr  = dataadr;// 读写的地址
    assign data_sram_wdata = writedata;// 写的data
    assign readdataM = data_sram_rdata; 

    assign debug_wb_pc       = pcW;// WB的PC
    assign debug_wb_rf_wen   = regwriteW4;// WB regfile的写使能
    assign debug_wb_rf_wnum  = writeregW;// WB regfile写的寄存器号
    assign debug_wb_rf_wdata = resultW;// WB 写regfile的数据



    mmu mm1(
        .inst_vaddr(pcF),
        .inst_paddr(pcconvertF),
        .data_vaddr(aluoutM_addr),
        .data_paddr(dataadr)
        );

    mips mips(
        .clk(~clk),
        .rst(~resetn),
        .pcF(pcF),
        .instrF(instrF),
        .memwriteM(memwrite),
        .memwenM(mem_wenM),
        .aluoutM(aluoutM_addr),
        .writedataM(writedata),
        .readdataM(readdataM),
        .memenM(memenM),
        .pcW(pcW),
        .regwriteW4(regwriteW4),
        .resultW(resultW),
        .writeregW(writeregW)
        );
	
endmodule
