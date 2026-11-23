`timescale 1ns / 1ps
//==============================================================================
// Modulo: riscv_top  (modulo principal)
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   Une todos los modulos en la microarquitectura multiciclo de la Figura 3
//   del avance. Cumple el requisito del proyecto: SOLO dos entradas, clk y rst.
//   El programa se carga en la memoria desde MEM_FILE.
//
// RUTA DE DATOS (de izquierda a derecha en el circuito):
//   PC -> mux AdrSrc -> memoria -> Instr / Data
//   Instr -> decodificador -> banco de registros / unidad de signo
//   banco -> A / WriteData -> mux ALUSrcA / ALUSrcB -> ALU
//   ALU -> ALUOut -> mux ResultSrc -> Result -> banco (WD3), PC, AdrSrc
//
// ENTRADAS:
//   clk   Reloj.
//   rst   Reset asincrono, activo en alto.
//==============================================================================
module riscv_top #(
    parameter MEM_FILE = "programa.mem"
)(
    input wire clk,
    input wire rst
);

    //--------------------------------------------------------------------------
    // Cables internos (wire): conectan la salida de un modulo con la entrada
    // de otro. Los nombres son los mismos del circuito.
    //--------------------------------------------------------------------------
    wire [31:0] PC, PCNext, OldPC, Adr, ReadData, Instr, Data;
    wire [31:0] RD1, RD2, A, WriteData, ImmExt;
    wire [31:0] SrcA, SrcB, ALUResult, ALUOut, Result;
    wire [31:0] WD;                         // dato acomodado para la memoria
    wire [3:0]  WE;                         // permisos por byte
    wire        Zero, Negative, Overflow;

    // Campos de la instruccion
    wire [6:0]  opcode;
    wire [4:0]  rd, rs1, rs2;
    wire [2:0]  funct3, ImmSrc;
    wire        funct7b5;

    // Senales de control
    wire        AdrSrc, IRWrite, RegWrite, MemWrite, PCUpdate, Branch, PCWrite;
    wire [1:0]  ALUSrcA, ALUSrcB, ResultSrc;
    wire [3:0]  ALUControl, estado;

    //==========================================================================
    // UNIDAD DE CONTROL
    //==========================================================================
    unidad_control u_control (
        .clk(clk), .rst(rst),
        .opcode(opcode), .funct3(funct3), .funct7b5(funct7b5),
        .AdrSrc(AdrSrc), .IRWrite(IRWrite),
        .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB), .ResultSrc(ResultSrc),
        .RegWrite(RegWrite), .MemWrite(MemWrite),
        .PCUpdate(PCUpdate), .Branch(Branch),
        .ALUControl(ALUControl), .estado(estado)
    );

    pc_write_logic u_pcwl (
        .PCUpdate(PCUpdate), .Branch(Branch), .funct3(funct3),
        .Zero(Zero), .Negative(Negative), .Overflow(Overflow),
        .Result(Result), .PCWrite(PCWrite), .PCNext(PCNext)
    );

    //==========================================================================
    // FETCH: PC, memoria, Instr, OldPC
    //==========================================================================
    pc u_pc (
        .clk(clk), .rst(rst), .PCWrite(PCWrite), .PCNext(PCNext), .PC(PC)
    );

    // Mux de direccion de memoria: 0 = PC (Fetch), 1 = Result (lw/sw/sb)
    mux2 #(32) u_mux_adr (.d0(PC), .d1(Result), .s(AdrSrc), .y(Adr));

    // Preparacion de escritura SW/SB
    prep_store u_prep (
        .WriteData(WriteData), .Adr(Adr[1:0]), .funct3(funct3),
        .MemWrite(MemWrite), .WD(WD), .WE(WE)
    );

    // Memoria unificada de instrucciones y datos
    memoria #(.DEPTH(256), .MEM_FILE(MEM_FILE)) u_mem (
        .clk(clk), .Adr(Adr), .WD(WD), .WE(WE), .ReadData(ReadData)
    );

    // Registros que se cargan solo en Fetch (IRWrite)
    registro #(32) u_oldpc (.clk(clk), .rst(rst), .en(IRWrite), .d(PC),       .q(OldPC));
    registro #(32) u_instr (.clk(clk), .rst(rst), .en(IRWrite), .d(ReadData), .q(Instr));

    // Registro Data: guarda lo leido de memoria en cada ciclo (lw lo usa en MemWB)
    registro #(32) u_data  (.clk(clk), .rst(rst), .en(1'b1),    .d(ReadData), .q(Data));

    //==========================================================================
    // DECODE: decodificador, banco de registros, unidad de signo, A, WriteData
    //==========================================================================
    decodificador u_dec (
        .Instr(Instr), .opcode(opcode), .rd(rd), .funct3(funct3),
        .rs1(rs1), .rs2(rs2), .funct7b5(funct7b5), .ImmSrc(ImmSrc)
    );

    banco_registros #(.SP_INIT(32'h0000_0400)) u_regs (
        .clk(clk), .rst(rst),
        .A1(rs1), .A2(rs2), .A3(rd),
        .WD3(Result), .WE3(RegWrite),
        .RD1(RD1), .RD2(RD2)
    );

    unidad_signo u_signo (.Instr(Instr[31:7]), .ImmSrc(ImmSrc), .ImmExt(ImmExt));

    registro #(32) u_a  (.clk(clk), .rst(rst), .en(1'b1), .d(RD1), .q(A));
    registro #(32) u_wd (.clk(clk), .rst(rst), .en(1'b1), .d(RD2), .q(WriteData));

    //==========================================================================
    // EXECUTE: muxes de operandos, ALU, ALUOut
    //==========================================================================
    // ALUSrcA: 00 PC, 01 OldPC, 10 A, 11 cero
    mux4 #(32) u_mux_srca (.d0(PC), .d1(OldPC), .d2(A), .d3(32'd0),
                           .s(ALUSrcA), .y(SrcA));
    // ALUSrcB: 00 WriteData, 01 ImmExt, 10 cuatro, 11 cero
    mux4 #(32) u_mux_srcb (.d0(WriteData), .d1(ImmExt), .d2(32'd4), .d3(32'd0),
                           .s(ALUSrcB), .y(SrcB));

    alu u_alu (
        .SrcA(SrcA), .SrcB(SrcB), .ALUControl(ALUControl),
        .ALUResult(ALUResult), .Zero(Zero), .Negative(Negative), .Overflow(Overflow)
    );

    registro #(32) u_aluout (.clk(clk), .rst(rst), .en(1'b1), .d(ALUResult), .q(ALUOut));

    //==========================================================================
    // WRITEBACK: mux ResultSrc
    //==========================================================================
    // 00 ALUOut, 01 Data, 10 ALUResult, 11 sin uso
    mux4 #(32) u_mux_result (.d0(ALUOut), .d1(Data), .d2(ALUResult), .d3(32'd0),
                             .s(ResultSrc), .y(Result));

endmodule
