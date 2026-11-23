`timescale 1ns / 1ps
//==============================================================================
// Modulo: mux4
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   Multiplexor de 4 entradas de WIDTH bits. Combinacional.
//   s = 00 -> d0,  s = 01 -> d1,  s = 10 -> d2,  s = 11 -> d3
//
// POR QUE EXISTE:
//   Se usa tres veces en el modulo principal:
//     - Mux ALUSrcA : 00 = PC, 01 = OldPC, 10 = A, 11 = constante 0 (LUI)
//     - Mux ALUSrcB : 00 = WriteData, 01 = ImmExt, 10 = 4, 11 = 0
//     - Mux ResultSrc: 00 = ALUOut, 01 = Data, 10 = ALUResult, 11 = sin uso (0)
//
// ENTRADAS:
//   d0..d3[WIDTH-1:0]  Las cuatro entradas.
//   s[1:0]             Selector de 2 bits.
//
// SALIDAS:
//   y[WIDTH-1:0]       Entrada seleccionada.
//==============================================================================
module mux4 #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    input  wire [WIDTH-1:0] d2,
    input  wire [WIDTH-1:0] d3,
    input  wire [1:0]       s,
    output reg  [WIDTH-1:0] y           // reg porque se asigna dentro de always
);

    // always @(*): bloque combinacional, se reevalua si cambia cualquier entrada.
    always @(*) begin
        case (s)                        // segun el valor del selector...
            2'b00:   y = d0;
            2'b01:   y = d1;
            2'b10:   y = d2;
            default: y = d3;            // 2'b11 (default cubre todo lo demas)
        endcase
    end

endmodule
