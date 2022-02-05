`timescale 1ns / 1ps
`include "defines.vh"

module maindec(
    input wire[5:0] op,
    input wire[5:0] funct,
    input wire[4:0] rt,
    input wire stallD,
    output reg pc8toreg,writereg31,jumptoRs,
    output wire memtoreg,memwrite,memen,
    output wire branch,alusrc,
    output wire regdst,regwrite,
    output wire jump, 
    output wire[7:0] alucontrol // 记得一定全部都是OP结尾
    );
    reg[14:0] controls; // TODO 加信号的话这个位宽别忘了改
    // regwrite：是否写寄存器 regdst：为0时写rt，否则rd
    // alusrc：为0时选寄存器，1选立即数作为操作数, branch：是否是分支指令
    // memwrite：是否写存 memtoreg：数据是否来自内存 jump：是否是跳转指令
    // alucontrol：让alu分辨指令
    assign {regwrite,regdst,alusrc,branch,memwrite,memtoreg,jump,alucontrol} = controls;

    assign memen =( (op == `EXE_LB)||(op == `EXE_LBU)||(op == `EXE_LH)||
            (op == `EXE_LHU)||(op == `EXE_LW)||(op == `EXE_SB)||(op == `EXE_SH)||(op == `EXE_SW))&& ~stallD;

    always @(*) begin
        pc8toreg <= 1'b0;
        writereg31 <= 1'b0; 
        jumptoRs <= 1'b0;
        case (op)
            6'b000000: begin // R型指令，注意下面的op一定都是0！
                case(funct)
                    // 逻辑运算指令
                    `EXE_AND: controls <= {7'b1100000, `EXE_AND_OP};
                    `EXE_OR: controls <= {7'b1100000, `EXE_OR_OP};
                    `EXE_XOR: controls <= {7'b1100000, `EXE_XOR_OP};
                    `EXE_NOR: controls <= {7'b1100000, `EXE_NOR_OP};
                    
                    // 移位指令
                    `EXE_SLL: controls <= {7'b1100000, `EXE_SLL_OP};
                    `EXE_SRL: controls <= {7'b1100000, `EXE_SRL_OP};
                    `EXE_SRA: controls <= {7'b1100000, `EXE_SRA_OP};
                    `EXE_SLLV: controls <= {7'b1100000, `EXE_SLLV_OP};
                    `EXE_SRLV: controls <= {7'b1100000, `EXE_SRLV_OP};
                    `EXE_SRAV: controls <= {7'b1100000, `EXE_SRAV_OP};
                    
                    // 数据移动指令
                    `EXE_MFHI: controls <= {7'b1100000, `EXE_MFHI_OP};
                    `EXE_MFLO: controls <= {7'b1100000, `EXE_MFLO_OP};
                    `EXE_MTHI: controls <= {7'b0100000, `EXE_MTHI_OP}; // TODO这里应该是不能写寄存器堆的
                    `EXE_MTLO: controls <= {7'b0100000, `EXE_MTLO_OP};
                    
                    // 算术运算指令
                    `EXE_ADD: controls <= {7'b1100000, `EXE_ADD_OP};
                    `EXE_ADDU: controls <= {7'b1100000, `EXE_ADDU_OP};
                    `EXE_SUB: controls <= {7'b1100000, `EXE_SUB_OP};
                    `EXE_SUBU: controls <= {7'b1100000, `EXE_SUBU_OP};
                    `EXE_SLT: controls <= {7'b1100000, `EXE_SLT_OP};
                    `EXE_SLTU: controls <= {7'b1100000, `EXE_SLTU_OP};
                    `EXE_MULT: controls <= {7'b0100000, `EXE_MULT_OP};
                    `EXE_MULTU: controls <= {7'b0100000, `EXE_MULTU_OP};
                    `EXE_DIV: controls <= {7'b0100000, `EXE_DIV_OP};
                    `EXE_DIVU: controls <= {7'b0100000, `EXE_DIVU_OP};

                    // 分支跳转指令
                    `EXE_JR: begin 
                        jumptoRs <= 1'b1;
                        controls <= {7'b0000001, `EXE_JR_OP};
                    end
                    `EXE_JALR: begin 
                        pc8toreg <= 1'b1;
                        writereg31 <= 1'b0; 
                        jumptoRs <= 1'b1;
                        controls <= {7'b1100001, `EXE_JALR_OP}; // TODO 最后一个怎么有人写的不是1
                    end
                    // 内陷指令

                    default: controls <= 0; 
                endcase
            end
            // 逻辑运算指令
            `EXE_ANDI: controls <= {7'b1010000, `EXE_ANDI_OP};
            `EXE_XORI: controls <= {7'b1010000, `EXE_XORI_OP};
            `EXE_LUI: controls <= {7'b1010000, `EXE_LUI_OP};
            `EXE_ORI: controls <= {7'b1010000, `EXE_ORI_OP};

            // 算术运算指令
            `EXE_ADDI: controls <= {7'b1010000, `EXE_ADDI_OP};
            `EXE_ADDIU: controls <= {7'b1010000, `EXE_ADDIU_OP};
            `EXE_SLTI: controls <= {7'b1010000, `EXE_SLTI_OP};
            `EXE_SLTIU: controls <= {7'b1010000, `EXE_SLTIU_OP};

            // 分支跳转指令
            `EXE_J: controls <= {7'b0000001, `EXE_J_OP};
            `EXE_JAL: begin
                pc8toreg <= 1'b1;
                writereg31 <= 1'b1; 
                jumptoRs <= 1'b0;
                controls <= {7'b1000001, `EXE_JAL_OP};
            end

            `EXE_REGIMM_INST: begin // 需要把rt加进来
                case(rt) 
                `EXE_BLTZ:controls <= {7'b0001000, `EXE_BLTZ_OP};
                `EXE_BGEZ:controls <= {7'b0001000, `EXE_BGEZ_OP};
                `EXE_BLTZAL: begin
                    pc8toreg <= 1'b1;
                    writereg31 <= 1'b1; 
                    controls <= {7'b1001000, `EXE_BLTZAL_OP}; 
                end
                `EXE_BGEZAL: begin
                    pc8toreg <= 1'b1;
                    writereg31 <= 1'b1; 
                    controls <= {7'b1001000, `EXE_BGEZAL_OP}; 
                end 
                default:  controls <= 0;
                endcase
            end

            `EXE_BEQ: controls <= {7'b0001000, `EXE_BEQ_OP};
            `EXE_BGTZ: controls <= {7'b0001000, `EXE_BGTZ_OP};
            `EXE_BLEZ: controls <= {7'b0001000, `EXE_BLEZ_OP};
            `EXE_BNE: controls <= {7'b0001000, `EXE_BNE_OP};


            // 访存指令
            `EXE_LW: controls <= {7'b1010010, `EXE_LW_OP};
            `EXE_LB: controls <= {7'b1010010, `EXE_LB_OP};
            `EXE_LBU: controls <= {7'b1010010, `EXE_LBU_OP};
            `EXE_LH: controls <= {7'b1010010, `EXE_LH_OP};
            `EXE_LHU: controls <= {7'b1010010, `EXE_LHU_OP};
            `EXE_SW: controls <= {7'b0010100, `EXE_SW_OP};
            `EXE_SB: controls <= {7'b0010100, `EXE_SB_OP};
            `EXE_SH: controls <= {7'b0010100, `EXE_SH_OP};

            // 特权指令

            default:  controls <= 0;

            endcase
    end
endmodule
