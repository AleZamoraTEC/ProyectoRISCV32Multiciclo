`timescale 1ns / 1ps
//==============================================================================
// Modulo: pc_write_logic  (PC Write Logic y mascara JALR en el avance)
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   1. Genera PCWrite, el permiso para actualizar el PC:
//        PCWrite = PCUpdate OR (Branch AND tomar)
//      donde "tomar" indica si se cumple la condicion del salto B, a partir
//      de las banderas de la ALU (calculadas con rs1 - rs2) y de funct3:
//        funct3  Instr  Condicion          tomar
//        000     beq    rs1 == rs2         Z
//        001     bne    rs1 != rs2         !Z
//        100     blt    rs1 <  rs2         N xor V
//        101     bge    rs1 >= rs2         !(N xor V)
//      Formula compacta: cond = funct3[2] ? (N xor V) : Z
//                        tomar = cond xor funct3[0]
//      (funct3[0] = 1 invierte la condicion: beq->bne, blt->bge)
//
//   2. Genera PCNext = Result con el bit 0 forzado a 0 (mascara de jalr).
//      CORRECCION respecto al avance: la mascara se aplica SIEMPRE, sin mux.
//      El selector propuesto (funct3[0] AND Branch) siempre daba 0 en jalr.
//      PC+4, los destinos B y los de jal siempre son pares, asi que la
//      mascara no los cambia; solo afecta a jalr, que es donde se necesita.
//
// ENTRADAS:
//   PCUpdate      Salto incondicional (Fetch, JAL, JALR), de la FSM.
//   Branch        Estado BRANCH, de la FSM.
//   funct3[2:0]   Tipo de salto B.
//   Zero          Bandera Z de la ALU.
//   Negative      Bandera N de la ALU.
//   Overflow      Bandera V de la ALU.
//   Result[31:0]  Salida del mux ResultSrc (nueva direccion).
//
// SALIDAS:
//   PCWrite       Habilitacion del registro PC.
//   PCNext[31:0]  Direccion que carga el PC.
//==============================================================================
module pc_write_logic (
    input  wire        PCUpdate,
    input  wire        Branch,
    input  wire [2:0]  funct3,
    input  wire        Zero,
    input  wire        Negative,
    input  wire        Overflow,
    input  wire [31:0] Result,
    output wire        PCWrite,
    output wire [31:0] PCNext
);

    // menor: rs1 < rs2 con signo. N xor V corrige el signo si hubo overflow.
    wire menor = Negative ^ Overflow;

    // cond: funct3[2] = 1 -> comparacion de orden (blt/bge); 0 -> igualdad (beq/bne)
    wire cond  = funct3[2] ? menor : Zero;

    // tomar: funct3[0] = 1 invierte la condicion (bne, bge)
    wire tomar = cond ^ funct3[0];

    // Permiso de escritura del PC
    assign PCWrite = PCUpdate | (Branch & tomar);

    // Mascara: bits [31:1] de Result y el bit 0 en 0
    assign PCNext = {Result[31:1], 1'b0};

endmodule
