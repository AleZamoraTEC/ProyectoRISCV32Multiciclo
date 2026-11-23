`timescale 1ns / 1ps
//==============================================================================
// Modulo: mux2
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   Multiplexor de 2 entradas de WIDTH bits. Combinacional.
//   s = 0 -> y = d0
//   s = 1 -> y = d1
//
// POR QUE EXISTE:
//   En el modulo principal, AdrSrc elige entre PC (Fetch) y Result
//   (direccion efectiva de lw/sw/sb).
//
// ENTRADAS:
//   d0[WIDTH-1:0]  Entrada 0.
//   d1[WIDTH-1:0]  Entrada 1.
//   s              Selector.
//
// SALIDAS:
//   y[WIDTH-1:0]   Entrada seleccionada.
//==============================================================================
module mux2 #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] d0,
    input  wire [WIDTH-1:0] d1,
    input  wire             s,
    output wire [WIDTH-1:0] y
);

    // Operador ternario: (condicion) ? valor_si_1 : valor_si_0
    // "assign" crea una conexion permanente (circuito combinacional).
    assign y = s ? d1 : d0;

endmodule
