`timescale 1ns / 1ps
//==============================================================================
// Modulo: decodificador  (Decodificador de instrucciones en el avance)
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   Separa la instruccion guardada en Instr en sus campos y, a partir del
//   opcode, indica el formato del inmediato (ImmSrc). Combinacional.
//
//   Campo     Bits        Lo usa
//   opcode    [6:0]       unidad de control (FSM)
//   rd        [11:7]      banco de registros, A3
//   funct3    [14:12]     decodificador ALU, prep_store, pc_write_logic
//   rs1       [19:15]     banco de registros, A1
//   rs2       [24:20]     banco de registros, A2
//   funct7b5  [30]        decodificador ALU (solo vale como funct7 en tipo R)
//
//   opcode    Instrucciones           Formato  ImmSrc
//   0000011   lw                      I        000
//   0010011   addi andi slli          I        000
//   1100111   jalr                    I        000
//   0100011   sw sb                   S        001
//   1100011   bne bge                 B        010
//   0110111   lui                     U        011
//   1101111   jal                     J        100
//
// POR QUE EXISTE:
//   Agrupa en un solo lugar "que significa cada bit" de la instruccion. Es
//   solo cableado y una tabla; no guarda nada.
//
// ENTRADAS:
//   Instr[31:0]   Instruccion actual (registro Instr).
//
// SALIDAS:
//   opcode, rd, funct3, rs1, rs2, funct7b5, ImmSrc (ver tabla).
//==============================================================================
module decodificador (
    input  wire [31:0] Instr,
    output wire [6:0]  opcode,
    output wire [4:0]  rd,
    output wire [2:0]  funct3,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire        funct7b5,
    output reg  [2:0]  ImmSrc
);

    // Extraccion de campos: solo cables, no hay logica.
    assign opcode   = Instr[6:0];
    assign rd       = Instr[11:7];
    assign funct3   = Instr[14:12];
    assign rs1      = Instr[19:15];
    assign rs2      = Instr[24:20];
    assign funct7b5 = Instr[30];

    // Formato del inmediato segun el opcode
    always @(*) begin
        case (opcode)
            7'b0000011: ImmSrc = 3'b000;   // lw    -> I
            7'b0010011: ImmSrc = 3'b000;   // addi andi slli -> I
            7'b1100111: ImmSrc = 3'b000;   // jalr  -> I
            7'b0100011: ImmSrc = 3'b001;   // sw sb -> S
            7'b1100011: ImmSrc = 3'b010;   // bne bge -> B
            7'b0110111: ImmSrc = 3'b011;   // lui   -> U
            7'b1101111: ImmSrc = 3'b100;   // jal   -> J
            default:    ImmSrc = 3'b000;   // otro: I por defecto
        endcase
    end

endmodule
