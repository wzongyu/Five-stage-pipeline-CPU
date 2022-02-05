`timescale 1ns / 1ps

// 将control和datapath合并，注意接口名字可能和top文件对不上
module mips(
    input wire clk,rst,
    output wire[31:0] pcF,
    input wire[31:0] instrF,
    output wire memwriteM,memenM,
    output wire[3:0] memwenM,
    output wire[31:0] aluoutM,writedataM,
    input wire[31:0] readdataM,
    // debug信号
    output wire [31:0] pcW, 
    output wire[3:0] regwriteW4,
    output wire [4:0] writeregW,
    output wire [31:0] resultW
    );


    // Fetch stage
    wire stallF,flushF;
    wire[31:0] pcplus4F,pcplus8F; // 注意位宽别写错了
    wire [31:0] pcnextF,pcnextbrF;

    // Decode stage
    wire [31:0] pcplus4D,pcplus8D,instrD,pcjumpD,pcD;
    wire[5:0] opD,functD;

    wire pc8toregD,writereg31D,jumptoRsD;
    wire regwriteD,memtoregD,memwriteD,memenD;
    wire alusrcD,regdstD,branchD,jumpD;
    wire[7:0] alucontrolD;

    wire [4:0] rsD,rtD,rdD,saD;
    wire [31:0] srcaD,srcbD,signimmD;

    wire forwardaD,forwardbD,stallD,flushD; 

    // Execute stage
    wire pc8toregE,writereg31E,jumptoRsE;
    wire regwriteE,memtoregE, memwriteE,memenE;
    wire alusrcE,regdstE;
    wire divstallE,hilowriteE,branchE,jumpE;
    wire overflowE,tobranchE;  // TODO overflow暂时没用上,tobranch就是原来的zero 
    wire[7:0] alucontrolE;

    wire [4:0] rsE,rtE,rdE,writeregE,writeregE_old,saE; // 要读写的寄存器和偏移量
    wire [31:0] srcaE,srca2E,srcbE,srcb2E,srcb3E,signimmE,signimmshE;
    wire [31:0] aluoutE,aluoutE_old,hi_inE,lo_inE,hi_outE,lo_outE;
    wire [31:0] pcplus4E,pcbranchE,pcjumpE,pcjumpE_old,pcplus8E,pcE;
    
    wire stallE,flushE;
    wire [1:0] forwardaE,forwardbE;
    
    // Mem stage
    wire regwriteM,memtoregM,hilowriteM;
    wire branchM,jumpM,pcsrcM,jumpbranchM;
    wire stallM,flushM;
    wire [4:0] writeregM;
    wire [31:0] hi_inM,lo_inM,pcbranchM,pcjumpM;
    wire [31:0] writedata_inM,readdata_outM;
    wire [31:0] pcM;
    wire[7:0] alucontrolM;

    // Writeback stage
    wire memtoregW,regwriteW;
    wire stallW,flushW;
    wire [31:0] aluoutW,readdataW;

    /////////////// Others ////////////////////////
    // hazard detection
    hazard h(
        // Fetch stage
        .stallF(stallF),.flushF(flushF),
        // Decode stage
        .rsD(rsD),.rtD(rtD),
        .branchD(branchD),
        .forwardaD(forwardaD),.forwardbD(forwardbD),
        .stallD(stallD),.flushD(flushD),
        // Execute stage
        .rsE(rsE),.rtE(rtE),
        .writeregE(writeregE),
        .regwriteE(regwriteE),
        .memtoregE(memtoregE),
        .divstallE(divstallE),
        .forwardaE(forwardaE),.forwardbE(forwardbE),
        .stallE(stallE),.flushE(flushE),
        // Mem stage
        .writeregM(writeregM),
        .regwriteM(regwriteM),
        .memtoregM(memtoregM),.jumpbranchM(jumpbranchM),
        .stallM(stallM),.flushM(flushM),
        // Write back stage
        .writeregW(writeregW),
        .regwriteW(regwriteW),
        .stallW(stallW),.flushW(flushW)
        );

    // regfile (operates in decode and writeback)
    regfile rf(clk,regwriteW,rsD,rtD,writeregW,resultW,srcaD,srcbD); // 在D阶段读，W阶段写

    // hi lo register
    hilo_reg hilor(clk,rst,hilowriteM,hi_inM,lo_inM,hi_outE,lo_outE); // 在E阶段读，M阶段写


    /////////////// Fetch stage ///////////////////

    // next PC logic (operates in fetch an decode) 
    mux2 #(32) pcbrmux(pcplus4F,pcbranchM,pcsrcM,pcnextbrF); // 从分支地址和PC+4选一个
    mux2 #(32) pcmux(pcnextbrF,                              // 从跳转地址和上一个结果中选一个
                    pcjumpM, 
                    jumpM,pcnextF);


    // fetch stage logic
    pc #(32) pcreg(clk,rst,~stallF,pcnextF,pcF); // 取指
    adder pcaddF1(pcF,32'b100,pcplus4F);           // 计算PC+4
    adder pcaddF2(pcF,32'b1000,pcplus8F);

    /////////////// Fetch to Decode ///////////////
    flopenrc #(32) r1D(clk,rst,~stallD,flushD,pcplus4F,pcplus4D);
    flopenrc #(32) r2D(clk,rst,~stallD,flushD,instrF,instrD);
    flopenrc #(32) r3D(clk,rst,~stallD,flushD,pcplus8F,pcplus8D);
    // debug
    flopenrc #(32) r4D(clk,rst,~stallD,flushD,pcF,pcD);

    /////////////// Decode stage //////////////////
    assign opD = instrD[31:26];
    assign rsD = instrD[25:21];
    assign rtD = instrD[20:16];
    assign rdD = instrD[15:11];
    assign saD = instrD[10:6];
    assign functD = instrD[5:0];

    maindec md(
        opD,functD,rtD,stallD,
        pc8toregD,writereg31D,jumptoRsD,
        memtoregD,memwriteD,memenD,
        branchD,alusrcD,regdstD,regwriteD,jumpD,
        alucontrolD
        );

    signext se(instrD[15:0],instrD[29:28],signimmD);  // 只有ORI那几个需要无符号扩展的指令instrD[29:28]是11

    assign pcjumpD = {pcplus4D[31:28],instrD[25:0],2'b00};


    /////////////// Decode to Execute /////////////
    flopenrc #(32) r1E(clk,rst,~stallE,flushE,srcaD,srcaE);
    flopenrc #(32) r2E(clk,rst,~stallE,flushE,srcbD,srcbE);
    flopenrc #(32) r3E(clk,rst,~stallE,flushE,signimmD,signimmE);
    flopenrc #(32) r4E(clk,rst,~stallE,flushE,pcplus4D,pcplus4E);
    flopenrc #(32) r5E(clk,rst,~stallE,flushE,pcjumpD,pcjumpE_old);
    flopenrc #(32) r6E(clk,rst,~stallE,flushE,pcplus8D,pcplus8E);
    flopenrc #(5)  r7E(clk,rst,~stallE,flushE,rsD,rsE);
    flopenrc #(5)  r8E(clk,rst,~stallE,flushE,rtD,rtE);
    flopenrc #(5)  r9E(clk,rst,~stallE,flushE,rdD,rdE);
    flopenrc #(5)  r10E(clk,rst,~stallE,flushE,saD,saE);
    flopenrc #(8)  r11E(clk,rst,~stallE,flushE,alucontrolD, alucontrolE);
    flopenrc #(7)  r12E(clk,rst,~stallE,flushE,
                    {memtoregD,memwriteD,alusrcD,regdstD,regwriteD,branchD,jumpD},
                    {memtoregE,memwriteE,alusrcE,regdstE,regwriteE,branchE,jumpE}
                    );
    flopenrc #(4)  r13E(clk,rst,~stallE,flushE,
                    {memenD,pc8toregD,writereg31D,jumptoRsD},
                    {memenE,pc8toregE,writereg31E,jumptoRsE}
                    );
    // debug
    flopenrc #(32) r14E(clk,rst,~stallE,flushE,pcD,pcE);

    /////////////// Execute stage /////////////////
    mux3 #(32) forwardaemux(srcaE,resultW,aluoutM,forwardaE,srca2E);
    mux3 #(32) forwardbemux(srcbE,resultW,aluoutM,forwardbE,srcb2E);
    mux2 #(32) srcbmux(srcb2E,signimmE,alusrcE,srcb3E);
    alu alu(clk,rst,srca2E,srcb3E,saE,alucontrolE,aluoutE_old,overflowE,tobranchE,
            hi_outE,lo_outE,hilowriteE,hi_inE,lo_inE,divstallE); // out是输入in是输出别弄反了
    mux2 #(5) wrmux(rtE,rdE,regdstE,writeregE_old);

    assign pcjumpE = jumptoRsE? srca2E:pcjumpE_old;  // 要和寄存器rs选一个。
    assign aluoutE = pc8toregE? pcplus8E:aluoutE_old; // 从pc+8和alu结果选一个写
    assign writeregE = writereg31E? 5'd31:writeregE_old; // 和31里面写一个

    sl2 immsh(signimmE,signimmshE);
    adder pcaddE(pcplus4E,signimmshE,pcbranchE);  

    /////////////// Execute to Mem ////////////////
    flopenrc #(32) r1M(clk,rst,~stallM,flushM,srcb2E,writedata_inM); // srcb2E就是writedataE
    flopenrc #(32) r2M(clk,rst,~stallM,flushM,aluoutE,aluoutM);
    flopenrc #(32) r3M(clk,rst,~stallM,flushM,hi_inE,hi_inM);
    flopenrc #(32) r4M(clk,rst,~stallM,flushM,lo_inE,lo_inM);
    flopenrc #(32) r5M(clk,rst,~stallM,flushM,pcbranchE,pcbranchM);
    flopenrc #(32) r6M(clk,rst,~stallM,flushM,pcjumpE,pcjumpM);
    flopenrc #(8)  r7M(clk,rst,~stallM,flushM,alucontrolE,alucontrolM);
    flopenrc #(5)  r8M(clk,rst,~stallM,flushM,writeregE,writeregM);
    flopenrc #(8)  r9M(clk,rst,~stallM,flushM,
                    {memtoregE,memwriteE,memenE,regwriteE,hilowriteE,branchE,tobranchE,jumpE},
                    {memtoregM,memwriteM,memenM,regwriteM,hilowriteM,branchM,tobranchM,jumpM}
                    );
    // debug
    flopenrc #(32) r10M(clk,rst,~stallM,flushM,pcE,pcM);

    /////////////// Mem stage /////////////////////

    assign pcsrcM = branchM & tobranchM;  
    assign jumpbranchM = jumpM | tobranchM; 

    // 在mem时写hilo，代码在上面的Others部分
    wire read_addr_error,write_addr_error; // TODO 后面处理异常的时候要处理
    // “过滤”访存写存数据
    memdec memd(alucontrolM,aluoutM[1:0],
                readdataM,writedata_inM,
                readdata_outM,writedataM,
                memwenM,read_addr_error,write_addr_error);


    
    /////////////// Mem to Writeback //////////////
    flopenrc #(32) r1W(clk,rst,~stallW,flushW,aluoutM,aluoutW);
    flopenrc #(32) r2W(clk,rst,~stallW,flushW,readdata_outM,readdataW); // readdataW已经是过滤过的了
    flopenrc #(5)  r3W(clk,rst,~stallW,flushW,writeregM,writeregW);
    flopenrc #(2)  r4W(clk,rst,~stallW,flushW,
                    {memtoregM,regwriteM},
                    {memtoregW,regwriteW}
                    );
    // debug
    flopenrc #(32) r5W(clk,rst,~stallW,flushW,pcM,pcW);

    /////////////// Writeback stage ///////////////

    assign regwriteW4 = {4{regwriteW}};
    mux2 #(32) resmux(aluoutW,readdataW,memtoregW,resultW);
    
endmodule
