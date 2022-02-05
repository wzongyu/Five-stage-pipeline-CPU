`timescale 1ns / 1ps


module hazard(
    // Fetch stage
    output wire stallF,flushF,  
    // Decode stage
    input wire[4:0] rsD,rtD,
    input wire branchD,
    output wire forwardaD,forwardbD,
    output wire stallD,flushD,
    // Execute stage
    input wire[4:0] rsE,rtE,
    input wire[4:0] writeregE,
    input wire regwriteE,
    input wire memtoregE,
    input wire divstallE,
    output wire[1:0] forwardaE,forwardbE,
    output wire stallE,flushE,
    // Mem stage
    input wire[4:0] writeregM,
    input wire regwriteM,
    input wire memtoregM,jumpbranchM, 
    output wire stallM,flushM,
    // Writeback stage
    input wire[4:0] writeregW,
    input wire regwriteW,
    output wire stallW,flushW
    );

    wire lwstallD,branchstallD;

    // forwarding sources to D stage (branch equality) 上上条是add这种数据冒险可以使用旁路解决
    assign forwardaD = (rsD != 0 & rsD == writeregM & regwriteM);
    assign forwardbD = (rtD != 0 & rtD == writeregM & regwriteM);
    
    // 解决上一条冒险，避免读0号寄存器，前两条指令如果有对相同寄存器写入都会出错，所以要检查M和W
    assign forwardaE = ((rsE != 5'b0) & (rsE == writeregM) & regwriteM)? 2'b10:
                        ((rsE != 5'b0) & (rsE == writeregW) & regwriteW)?2'b01:2'b00;
    assign forwardbE = ((rtE != 5'b0) & (rtE == writeregM) & regwriteM)? 2'b10:
                        ((rtE != 5'b0) & (rtE == writeregW) & regwriteW)?2'b01:2'b00;

 
    //stalls 注意是rtE，因为lw指令就是加载到rt地址，直接用rsD比较，这样可以避免进入E级执行alu运算
    assign #1 lwstallD = memtoregE & (rtE == rsD | rtE == rtD);
    // 由于分支提前判断了，上一条有数据冒险或上上条是lw时候都要阻塞
    // TODO 应该是没了 assign #1 branchstallD = branchD &
    //             (regwriteE & 
    //             (writeregE == rsD | writeregE == rtD) |
    //             memtoregM &
    //             (writeregM == rsD | writeregM == rtD));

    // Fetch stage
    assign #1 stallF = stallD; //stalling D stalls all previous stages
    assign #1 flushF = jumpbranchM;
    // assign flushF = flush_except;

    // Decode stage 
    assign #1 stallD = lwstallD | divstallE;
    assign flushD = jumpbranchM;

    // Execute stage
    assign #1 stallE = divstallE;
    // assign #1 flushE = stallD; //stalling D flushes next stage 
    assign #1 flushE = lwstallD  | ( ~divstallE & (jumpbranchM)); // TODO 感觉可以不清，那reg有啥必要呢, | branchstallD
    // assign #1 flushE = lwstallD | branchstallD| flush_except;

    // Mem stage
    assign #1 stallM = 0;
    assign #1 flushM = divstallE;
    // assign #1 stallM = stallreq_from_mem;

    // assign #1 flushM=flushF;
    // Writeback stage
    // assign #1 flushW=flushF | stallreq_from_mem;
    assign #1 stallW = 0;   // TODO 记得stallW时把regwrite置0
    assign #1 flushW = 0;

    
    // Note: not necessary to stall D stage on store
     //       if source comes from load;
     //       instead, another bypass network could
     //       be added from W to M
endmodule