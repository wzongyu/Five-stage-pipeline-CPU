`timescale 1ns / 1ps
`include "defines.vh"


module branchcmp(
    input wire[31:0] a,b,
    input wire[7:0] op,
    output wire y
    );
    assign y = (op == `EXE_BEQ_OP) ? (a == b):
            (op == `EXE_BNE_OP) ? (a != b):
            (op == `EXE_BGTZ_OP) ? ((a[31] == 1'b0) && (a != `ZeroWord)):
            (op == `EXE_BLEZ_OP) ? ((a[31] == 1'b1) || (a == `ZeroWord)):
            ((op == `EXE_BGEZ_OP) || (op == `EXE_BGEZAL_OP))? (a[31] == 1'b0):
            ((op == `EXE_BLTZ_OP) || (op == `EXE_BLTZAL_OP))? (a[31] == 1'b1):0;
endmodule



