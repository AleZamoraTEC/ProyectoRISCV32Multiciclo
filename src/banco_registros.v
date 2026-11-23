`timescale 1ns / 1ps
//==============================================================================
// Modulo: banco_registros
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   Banco de 32 registros de 32 bits (x0 a x31).
//   - Dos lecturas combinacionales: RD1 = x[A1], RD2 = x[A2].
//   - Una escritura sincrona: en el flanco de subida, si WE3 = 1,
//     x[A3] <= WD3.
//   - x0 siempre vale 0: se ignoran las escrituras a x0.
//   - Con reset todos los registros quedan en 0, excepto x2 (sp), que se
//     carga con SP_INIT porque el programa nunca le da valor inicial.
//
// POR QUE EXISTE:
//   Todas las instrucciones usan registros: addi/andi/slli/lw/lui/jal
//   escriben en rd; sw/sb/bne/bge leen rs1 y rs2.
//
// PARAMETROS:
//   SP_INIT   Valor inicial del stack pointer. 0x400 = final de la memoria de
//             1 KB, asi la pila (0x3E0-0x3FF) no se cruza con el programa.
//
// ENTRADAS:
//   clk, rst     Reloj y reset asincrono activo en alto.
//   A1[4:0]      Numero de rs1 (Instr[19:15]).
//   A2[4:0]      Numero de rs2 (Instr[24:20]).
//   A3[4:0]      Numero de rd  (Instr[11:7]).
//   WD3[31:0]    Dato a escribir (Result).
//   WE3          RegWrite de la unidad de control.
//
// SALIDAS:
//   RD1[31:0]    Valor de rs1 -> registro A.
//   RD2[31:0]    Valor de rs2 -> registro WriteData.
//==============================================================================
module banco_registros #(
    parameter [31:0] SP_INIT = 32'h0000_0400
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [4:0]  A1,
    input  wire [4:0]  A2,
    input  wire [4:0]  A3,
    input  wire [31:0] WD3,
    input  wire        WE3,
    output wire [31:0] RD1,
    output wire [31:0] RD2
);

    reg [31:0] x [0:31];      // los 32 registros: x[0] ... x[31]
    integer i;                // indice para el for del reset

    // Escritura sincrona y reset asincrono
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                x[i] <= 32'b0;              // todos en 0...
            x[2] <= SP_INIT;                // ...menos sp (x2)
        end
        else if (WE3 && (A3 != 5'd0))       // escribir solo si hay permiso
            x[A3] <= WD3;                   // y el destino NO es x0
    end

    // Lectura combinacional. Si se pide x0 se devuelve 0 directamente.
    assign RD1 = (A1 == 5'd0) ? 32'b0 : x[A1];
    assign RD2 = (A2 == 5'd0) ? 32'b0 : x[A2];

endmodule
