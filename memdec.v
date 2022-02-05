`timescale 1ns / 1ps
`include "defines.vh"


// 部分参考https://github.com/JF2098/A-simple-MIPS-CPU/tree/master/rtl
module memdec(
    input wire[7:0]op,
    input wire[1:0]endOfAddr,
    input wire[31:0]readdata_in,writedata_in,
    output reg[31:0]readdata_out,writedata_out,
    output reg[3:0] writeEn,
    output reg read_addr_error,write_addr_error
    );
    always@(*)begin
        writeEn<=4'b0;
        case(op) // 处理写使能
            `EXE_SW_OP:if(endOfAddr==2'b00)writeEn<=4'b1111;
            `EXE_SH_OP:begin
                if(endOfAddr==2'b00)writeEn<=4'b0011;
                else if(endOfAddr==2'b10)writeEn<=4'b1100;
            end
            `EXE_SB_OP:begin
                if(endOfAddr==2'b00)writeEn<=4'b0001;
                else if(endOfAddr==2'b01)writeEn<=4'b0010;
                else if(endOfAddr==2'b10)writeEn<=4'b0100;
                else if(endOfAddr==2'b11)writeEn<=4'b1000;
            end
        endcase
    end
    always@(*)begin // 修正读数据
        readdata_out<=32'b0;writedata_out<=32'b0;
        case(op)
            `EXE_LW_OP:if(endOfAddr==2'b00)readdata_out<=readdata_in;
            `EXE_LH_OP:begin
                if(endOfAddr==2'b00)readdata_out<={{16{readdata_in[15]}},readdata_in[15:0]};
                else if(endOfAddr==2'b10)readdata_out<={{16{readdata_in[31]}},readdata_in[31:16]};
            end
            `EXE_LHU_OP:begin
                if(endOfAddr==2'b00)readdata_out<={16'b0,readdata_in[15:0]};
                else if(endOfAddr==2'b10)readdata_out<={16'b0,readdata_in[31:16]};
            end
            `EXE_LB_OP:begin
                if(endOfAddr==2'b00)readdata_out<={{24{readdata_in[7]}},readdata_in[7:0]};
                else if(endOfAddr==2'b01)readdata_out<={{24{readdata_in[15]}},readdata_in[15:8]};
                else if(endOfAddr==2'b10)readdata_out<={{24{readdata_in[23]}},readdata_in[23:16]};
                else if(endOfAddr==2'b11)readdata_out<={{24{readdata_in[31]}},readdata_in[31:24]};
            end
            `EXE_LBU_OP:begin
                if(endOfAddr==2'b00)readdata_out<={24'b0,readdata_in[7:0]};
                else if(endOfAddr==2'b01)readdata_out<={24'b0,readdata_in[15:8]};
                else if(endOfAddr==2'b10)readdata_out<={24'b0,readdata_in[23:16]};
                else if(endOfAddr==2'b11)readdata_out<={24'b0,readdata_in[31:24]};
            end
            // 更正写数据，兼容大小端
            `EXE_SW_OP:writedata_out<=writedata_in;
            `EXE_SH_OP:writedata_out<={writedata_in[15:0],writedata_in[15:0]};
            `EXE_SB_OP:writedata_out<={writedata_in[7:0],writedata_in[7:0],writedata_in[7:0],writedata_in[7:0]};
        endcase
    end
    always@(*)begin
        read_addr_error <= ((op == `EXE_LH_OP || op == `EXE_LHU_OP) && endOfAddr[0]) 
        || (op == `EXE_LW_OP && endOfAddr != 2'b00);
        write_addr_error <= (op == `EXE_SH_OP & endOfAddr[0]) | (op == `EXE_SW_OP & endOfAddr != 2'b00);
    end
    

endmodule
