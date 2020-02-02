// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


`include "vunit_defines.svh"

module tb_kronos_ID_ut;

import kronos_types::*;

logic clk;
logic rstz;
pipeIFID_t pipe_IFID;
logic pipe_in_vld;
logic pipe_in_rdy;
pipeIDEX_t pipe_IDEX;
logic pipe_out_vld;
logic pipe_out_rdy;
logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;

kronos_ID u_id (
    .clk         (clk         ),
    .rstz        (rstz        ),
    .pipe_IFID   (pipe_IFID   ),
    .pipe_in_vld (pipe_in_vld ),
    .pipe_in_rdy (pipe_in_rdy ),
    .pipe_IDEX   (pipe_IDEX   ),
    .pipe_out_vld(pipe_out_vld),
    .pipe_out_rdy(pipe_out_rdy),
    .regwr_data  (regwr_data  ),
    .regwr_sel   (regwr_sel   ),
    .regwr_en    (regwr_en    )
);

default clocking cb @(posedge clk);
    default input #10s output #10ps;
    input pipe_out_vld, pipe_IDEX;
    input negedge pipe_in_rdy;
    output pipe_in_vld, pipe_IFID;
    output negedge pipe_out_rdy;
endclocking

// ============================================================

logic [31:0] REG [32];

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        pipe_IFID = '0;
        pipe_in_vld = 0;
        pipe_out_rdy = 0;
        regwr_data = '0;
        regwr_en = 0;
        regwr_sel = 0;

        // init regfile with random values
        for(int i=0; i<32; i++) begin
            u_id.REG1[i] = $urandom;
            u_id.REG2[i] = u_id.REG1[i];
            REG[i] = u_id.REG1[i];
        end

        // Zero out TB's REG[0] (x0)
        REG[0] = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("decode") begin
        pipeIFID_t tinstr;
        pipeIDEX_t tdecode, rdecode;
        string optype;

        repeat (1024) begin

            rand_instr(tinstr, tdecode, optype);

            $display("OPTYPE=%s", optype);
            $display("IFID: PC=%h, IR=%h", tinstr.pc, tinstr.ir);
            $display("Expected IDEX:");
            $display("  op1: %h", tdecode.op1);
            $display("  op2: %h", tdecode.op2);
            $display("  rs1_read: %h", tdecode.rs1_read);
            $display("  rs2_read: %h", tdecode.rs2_read);
            $display("  rs1: %h", tdecode.rs1);
            $display("  rs2: %h", tdecode.rs2);
            $display("  neg: %h", tdecode.neg);
            $display("  rev: %h", tdecode.rev);
            $display("  cin: %h", tdecode.cin);
            $display("  uns: %h", tdecode.uns);
            $display("  gte: %h", tdecode.gte);
            $display("  sel: %h", tdecode.sel);

            fork 
                begin
                    @(cb);
                    cb.pipe_IFID <= tinstr;
                    cb.pipe_in_vld <= 1;
                    repeat (16) begin
                        @(cb) if (cb.pipe_in_rdy) begin
                            cb.pipe_in_vld <= 0;
                            break;
                        end
                    end
                end

                begin
                    @(cb iff pipe_out_vld) begin
                        //check
                        rdecode = pipe_IDEX;

                        $display("Got IDEX:");
                        $display("  op1: %h", rdecode.op1);
                        $display("  op2: %h", rdecode.op2);
                        $display("  rs1_read: %h", rdecode.rs1_read);
                        $display("  rs2_read: %h", rdecode.rs2_read);
                        $display("  rs1: %h", rdecode.rs1);
                        $display("  rs2: %h", rdecode.rs2);
                        $display("  neg: %h", rdecode.neg);
                        $display("  rev: %h", rdecode.rev);
                        $display("  cin: %h", rdecode.cin);
                        $display("  uns: %h", rdecode.uns);
                        $display("  gte: %h", rdecode.gte);
                        $display("  sel: %h", rdecode.sel);

                        cb.pipe_out_rdy <= 1;
                        ##1 cb.pipe_out_rdy <= 0;

                        assert(rdecode == tdecode);
                    end
                end
            join

            $display("-----------------\n\n");
        end

        ##64;
    end

end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic rand_instr(output pipeIFID_t instr, output pipeIDEX_t decode, output string optype);
    /*
    Generate constrained-random instr

    Note: This would have been a breeze with SV constraints.
        However, the "free" version of modelsim doesn't support
        that feature (along with many other things, like 
        coverage, properties, sequenes, etc)
        Hence, we get by with just the humble $urandom
    */

    int op;

    logic [6:0] opcode;
    logic [4:0] rs1, rs2, rd;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [31:0] imm;

    op = $urandom_range(0,8);
    imm = $urandom();
    rs1 = $urandom();
    rs2 = $urandom();
    rd = $urandom();

    instr.pc = $urandom;

    // painstakingly build random-valid instructions
    // and expected decode
    case(op)
        0: begin
            optype = "ADDI";

            instr.ir = {imm[11:0], rs1, 3'b000, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.gte = 0;
            decode.sel = 0;
        end

        1: begin
            optype = "SLTI";

            instr.ir = {imm[11:0], rs1, 3'b010, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.neg = 1;
            decode.rev = 0;
            decode.cin = 1;
            decode.uns = 0;
            decode.gte = 0;
            decode.sel = 3'd4;
        end

        2: begin
            optype = "SLTIU";

            instr.ir = {imm[11:0], rs1, 3'b011, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.neg = 1;
            decode.rev = 0;
            decode.cin = 1;
            decode.uns = 1;
            decode.gte = 0;
            decode.sel = 4;
        end

        3: begin
            optype = "XORI";

            instr.ir = {imm[11:0], rs1, 3'b100, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.gte = 0;
            decode.sel = 3;
        end

        4: begin
            optype = "ORI";

            instr.ir = {imm[11:0], rs1, 3'b110, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.gte = 0;
            decode.sel = 2;
        end

        5: begin
            optype = "ANDI";

            instr.ir = {imm[11:0], rs1, 3'b111, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.gte = 0;
            decode.sel = 1;
        end

        6: begin
            optype = "SLLI";

            instr.ir = {7'b0, imm[4:0], rs1, 3'b001, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'({7'b0, imm[4:0]});
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.neg = 0;
            decode.rev = 1;
            decode.cin = 0;
            decode.uns = 0;
            decode.gte = 0;
            decode.sel = 5;
        end

        7: begin
            optype = "SRLI";

            instr.ir = {7'b0, imm[4:0], rs1, 3'b101, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'({7'b0,imm[4:0]});
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.gte = 0;
            decode.sel = 5;
        end

        8: begin
            optype = "SRAI";

            instr.ir = {7'b0100000, imm[4:0], rs1, 3'b101, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'({7'b0100000,imm[4:0]});
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 1;
            decode.uns = 0;
            decode.gte = 0;
            decode.sel = 5;
        end
    endcase // instr
endtask

endmodule