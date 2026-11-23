`timescale 1ns / 1ps
//==============================================================================
// Modulo: unidad_signo  (ImmGen en el avance)
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   Arma el inmediato de 32 bits (ImmExt) a partir de los bits de la
//   instruccion, segun su formato. Combinacional.
//   En I, S, B y J se extiende el signo: se copia Instr[31] en los bits altos.
//
//   ImmSrc  Formato  ImmExt                                         Instrucciones
//   000     I        {20{Instr[31]}, Instr[31:20]}                  addi andi slli lw jalr
//   001     S        {20{Instr[31]}, Instr[31:25], Instr[11:7]}     sw sb
//   010     B        {19{Instr[31]}, Instr[31], Instr[7],           bne bge
//                     Instr[30:25], Instr[11:8], 1'b0}
//   011     U        {Instr[31:12], 12'b0}                          lui
//   100     J        {11{Instr[31]}, Instr[31], Instr[19:12],       jal
//                     Instr[20], Instr[30:21], 1'b0}
//
//   NOTA U: ImmGen coloca el inmediato en [31:12] y llena [11:0] con ceros.
//   NOTA B y J: el bit 0 siempre es 0 porque los saltos son a direcciones pares.
//
// POR QUE EXISTE:
//   Cada formato guarda el inmediato en posiciones distintas de la instruccion
//   (en S y B esta partido en pedazos), y la ALU necesita un numero completo
//   de 32 bits.
//
// ENTRADAS:
//   Instr[31:7]   Bits de la instruccion que pueden contener el inmediato.
//   ImmSrc[2:0]   Formato, generado por el decodificador de instrucciones.
//
// SALIDAS:
//   ImmExt[31:0]  Inmediato extendido -> mux ALUSrcB.
//==============================================================================
module unidad_signo (
    input  wire [31:7] Instr,
    input  wire [2:0]  ImmSrc,
    output reg  [31:0] ImmExt
);

    always @(*) begin
        case (ImmSrc)
            // I: 12 bits [31:20], signo extendido
            3'b000: ImmExt = {{20{Instr[31]}}, Instr[31:20]};
            // S: el inmediato esta partido en [31:25] y [11:7]
            3'b001: ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};
            // B: bits reordenados, bit 0 = 0
            3'b010: ImmExt = {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0};
            // U: inmediato en los 20 bits altos, listo para LUIWB.
            3'b011: ImmExt = {Instr[31:12], 12'b0};
            // J: bits reordenados, bit 0 = 0
            3'b100: ImmExt = {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21], 1'b0};
            // codigo no usado
            default: ImmExt = 32'b0;
        endcase
    end

endmodule
