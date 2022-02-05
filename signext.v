`timescale 1ns / 1ps


// 数据扩展模块，支持有符号扩展和无符号扩展（无符号扩展主要是ANDI这类指令需要用）
// 注意ADDU还是有符号哦，U的意思是不产生溢出
module signext(
    input wire[15:0] a,
    input wire[1:0] s, 
    output wire[31:0] y
    );

    assign y = (s == 2'b11)?{16'b0,a}:{{16{a[15]}},a};
endmodule
