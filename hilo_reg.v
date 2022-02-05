`timescale 1ns / 1ps


module hilo_reg(
    input wire clk,rst,we,
    input wire [31:0] hi_in, lo_in,  
    output reg [31:0] hi_out, lo_out
    );

    

    always @(negedge clk) begin
        if(rst) begin
            hi_out <= 0;
            lo_out <= 0;
        end
        else if (we) begin
            hi_out <= hi_in;
            lo_out <= lo_in;
        end
    end

endmodule
