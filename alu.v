`timescale 1ns / 1ps
`include "defines.vh"

// 由alu承担MTHI、MTLO、MFHI、MFLO的判断和处理
module alu(
    input wire clk,rst,
    input wire[31:0] a,b, // clr_mut_div,
    input wire[4:0] sa,
    input wire[7:0] op,
    output reg[31:0] y,
    output reg overflow,
    output wire tobranch,
    input wire[31:0] hi_out,lo_out,
    output wire hilowrite,
    output reg[31:0] hi_in,lo_in,
    output reg stall_div
    );

    reg signed_div,start_div;
    wire div_ready;
    reg[31:0] a_reg, b_reg; 
    wire [63:0] div_result;
    wire[31:0] s,bout;
    wire isSub;
    assign isSub = (op==`EXE_SUB_OP|op==`EXE_SUBU_OP|op==`EXE_SLT_OP|
    op==`EXE_SLTI_OP|op==`EXE_SLTU_OP|op==`EXE_SLTIU_OP);
    assign bout = isSub ? ~b : b;
    assign s = a + bout + isSub;
    // 这种要送出去的信号还是写在外面比较安全
    assign hilowrite = (op==`EXE_MTHI_OP|op==`EXE_MTLO_OP|op==`EXE_MULT_OP|
    op==`EXE_MULTU_OP|(op==`EXE_DIV_OP|op==`EXE_DIVU_OP)&div_ready);


    always @(*) begin
        case (op)
            // 逻辑运算指令
            `EXE_AND_OP, `EXE_ANDI_OP: y <= a & b;
            `EXE_OR_OP, `EXE_ORI_OP: y <= a | b;
            `EXE_XOR_OP, `EXE_XORI_OP: y <= a ^ b;
            `EXE_NOR_OP: y <= ~(a | b);
            `EXE_LUI_OP: y <= {b[15:0],16'b0};
            
            // 移位指令
            `EXE_SLL_OP: y <= b << sa;
            `EXE_SRL_OP: y <= b >> sa;
            `EXE_SRA_OP: y <= ($signed(b)) >>> sa; // $signed用来声明b是有符号数
            `EXE_SLLV_OP: y <= b << a[4:0]; // 最多移32位，所以要取a后5位
            `EXE_SRLV_OP: y <= b >> a[4:0];
            `EXE_SRAV_OP: y <= ($signed(b)) >>> a[4:0];

            // 数据移动指令
            `EXE_MFHI_OP: begin
                y <= hi_out; // 把hi的值写入rd寄存器
                hi_in <= hi_out;
                lo_in <= lo_out;
            end
            `EXE_MFLO_OP: begin
                y <= lo_out;  // 把lo的值写入rd寄存器
                hi_in <= hi_out;
                lo_in <= lo_out;
            end
            `EXE_MTHI_OP: begin 
                hi_in <= a; // 把rs寄存器的值写入hi
                lo_in <= lo_out;
            end
            `EXE_MTLO_OP: begin 
                hi_in <= hi_out;
                lo_in <= a; // 把rs寄存器的值写入lo
            end

            // 算术运算指令
            `EXE_SLT_OP,`EXE_SLTI_OP: y <= (a[31]&~b[31])?1:s[31]&~(~a[31]&b[31]); // 考虑了溢出的情况
            `EXE_SLTU_OP,`EXE_SLTIU_OP: y <= a < b;
            `EXE_ADD_OP,`EXE_ADDU_OP,`EXE_ADDI_OP,`EXE_ADDIU_OP,`EXE_SUB_OP,`EXE_SUBU_OP: y <= s;
            `EXE_MULT_OP: {hi_in, lo_in} <= $signed(a) * $signed(b); // 乘法结果写入hi,lo
            `EXE_MULTU_OP: {hi_in, lo_in} <= {32'b0, a} * {32'b0, b}; // 乘法结果写入hi,lo
            `EXE_DIV_OP, `EXE_DIVU_OP: {hi_in, lo_in} <= div_result; // 除法结果写入hi,lo

            // TODO
            // 分支跳转指令 
            // `EXE_BEQ_OP: y <= s; 这个提前在译码阶段提前判断的话未必需要
            // 访存指令
            `EXE_LW_OP,`EXE_SW_OP,`EXE_LB_OP,`EXE_LBU_OP,`EXE_LH_OP,`EXE_LHU_OP,`EXE_SB_OP,`EXE_SH_OP: y <= s;
            
            default : y <= 32'b0;
        endcase    
    end

    // assign zero = (y == 32'b0);
    branchcmp bcmp(a, b, op, tobranch);

    // 加减法溢出判断
    always @(*) begin
        case (op)
            `EXE_ADD_OP,`EXE_ADDI_OP:overflow <= a[31] & b[31] & ~s[31] |
                            ~a[31] & ~b[31] & s[31];
            `EXE_SUB_OP:overflow <= ~a[31] & b[31] & s[31] |
                            a[31] & ~b[31] & ~s[31];
            default : overflow <= 1'b0;
        endcase    
    end

    ///////////////////// 除法器 //////////////////////
    always@(*) begin
        start_div <= 1'b0;
        stall_div <= 1'b0;
        case(op)
        `EXE_DIV_OP:begin
            signed_div<=1'b1;
            if(div_ready == 1'b0)begin
                start_div <= 1'b1;
                stall_div <= 1'b1;
            end
            else begin
                start_div <= 1'b0;
                stall_div <= 1'b0;
            end
        end
        `EXE_DIVU_OP:begin
            signed_div <= 1'b0;
            if(div_ready == 1'b0)begin
                start_div <= 1'b1;
                stall_div <= 1'b1;
            end
            else begin
                start_div <= 1'b0;
                stall_div <= 1'b0;
            end
        end
        endcase
    end    

    reg reg_control; // 保险起见
    always@(posedge clk) begin // 刚开始上升沿的时候start_div应该是0
        if (start_div)
            reg_control <= 1'b1;
        else
            reg_control <= 1'b0;
    end

    always@(negedge clk) begin // 每次除法开始就更新一次值
        if((reg_control^start_div)&start_div) begin
            a_reg <= a;
            b_reg <= b;
        end
        else begin
            a_reg<=a_reg;
            b_reg<=b_reg;
        end
    end

    div div1(clk, rst, // TODO  rst|flush_except
            signed_div,
            a_reg,b_reg,
            start_div,
            1'b0,
            div_result,
            div_ready);


endmodule
