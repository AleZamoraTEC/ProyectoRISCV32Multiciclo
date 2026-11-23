`timescale 1ns / 1ps
//==============================================================================
// Modulo: alu
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   Unidad Aritmetico-Logica de 32 bits. Es combinacional: no tiene reloj ni
//   memoria; su salida cambia apenas cambian sus entradas.
//
// POR QUE EXISTE:
//   En la arquitectura multiciclo la MISMA ALU se reutiliza en varios estados:
//     - Fetch:        PC + 4                      (ADD)
//     - Decode:       OldPC + ImmExt, destino B   (ADD)
//     - MemAdr:       rs1 + inmediato, direccion de lw/sw/sb (ADD)
//     - Execute I:    addi (ADD), andi (AND), slli (SLL)
//     - Saltos B:     rs1 - rs2 para comparar     (SUB) -> banderas
//     - jal / jalr:   calculo del destino         (ADD)
//
// ENTRADAS:
//   SrcA[31:0]        Primer operando (sale del mux ALUSrcA).
//   SrcB[31:0]        Segundo operando (sale del mux ALUSrcB).
//   ALUControl[3:0]   Operacion a realizar (viene del decodificador ALU de la UC).
//                     Codigos segun la Tabla 3 del avance:
//                       0000 AND   0001 OR    0010 ADD
//                       0110 SUB   0111 SLT   1111 SLL
//
// SALIDAS:
//   ALUResult[31:0]   Resultado de la operacion.
//   Zero              1 si ALUResult = 0. Lo usan beq y bne.
//   Negative          Bit 31 del resultado (signo). Lo usa bge.
//   Overflow          1 si hubo desbordamiento con signo en ADD o SUB.
//                     Lo usa bge: A >= B  <=>  Negative == Overflow tras A - B.
//==============================================================================
module alu (
    input  wire [31:0] SrcA,
    input  wire [31:0] SrcB,
    input  wire [3:0]  ALUControl,
    output reg  [31:0] ALUResult,
    output wire        Zero,
    output wire        Negative,
    output reg         Overflow
);

    // Nombres para los codigos de operacion: el codigo se lee mejor con
    // "OP_ADD" que con "4'b0010".
    localparam [3:0] OP_AND = 4'b0000,
                     OP_OR  = 4'b0001,
                     OP_ADD = 4'b0010,
                     OP_SUB = 4'b0110,
                     OP_SLT = 4'b0111,
                     OP_SLL = 4'b1111;

    // Suma y resta se calculan aparte porque tambien se necesitan para
    // detectar el desbordamiento.
    wire [31:0] suma  = SrcA + SrcB;
    wire [31:0] resta = SrcA - SrcB;

    // always @(*) = bloque combinacional: se reevalua cada vez que cambia
    // cualquier senal que se lee adentro.
    always @(*) begin
        // Valores por defecto: evitan que Vivado infiera latches (memorias
        // no deseadas) si algun caso no asigna todas las salidas.
        ALUResult = 32'b0;
        Overflow  = 1'b0;

        case (ALUControl)
            OP_AND: ALUResult = SrcA & SrcB;              // andi
            OP_OR:  ALUResult = SrcA | SrcB;
            OP_ADD: begin                                  // addi, direcciones, PC+4
                ALUResult = suma;
                // Desbordamiento en suma: los dos operandos tienen el mismo
                // signo y el resultado tiene un signo distinto.
                Overflow = (SrcA[31] == SrcB[31]) && (suma[31] != SrcA[31]);
            end
            OP_SUB: begin                                  // comparacion de saltos
                ALUResult = resta;
                // Desbordamiento en resta: los operandos tienen signos
                // distintos y el resultado tiene un signo distinto al de A.
                Overflow = (SrcA[31] != SrcB[31]) && (resta[31] != SrcA[31]);
            end
            OP_SLT: ALUResult = ($signed(SrcA) < $signed(SrcB)) ? 32'd1 : 32'd0;
            OP_SLL: ALUResult = SrcA << SrcB[4:0];         // slli: solo 5 bits de
                                                           // desplazamiento (0-31)
            default: ALUResult = 32'b0;                    // codigo no usado
        endcase
    end

    // Banderas que dependen solo del resultado (asignaciones continuas)
    assign Zero     = (ALUResult == 32'b0);
    assign Negative = ALUResult[31];

endmodule
