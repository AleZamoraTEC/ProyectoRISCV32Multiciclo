`timescale 1ns / 1ps
//==============================================================================
// Modulo: registro
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   Registro generico de WIDTH bits con reset asincrono y habilitacion (en).
//   En el flanco de subida del reloj guarda la entrada d si en = 1.
//
// POR QUE EXISTE:
//   La arquitectura multiciclo divide cada instruccion en varios ciclos, y
//   necesita guardar resultados intermedios de un ciclo al siguiente. En vez
//   de escribir seis modulos casi iguales, se usa este mismo modulo seis veces
//   (seis "instancias") en el modulo principal:
//     - OldPC     : en = IRWrite. Guarda la direccion de la instruccion actual.
//     - Instr     : en = IRWrite. Guarda la instruccion leida en Fetch.
//     - A         : en = 1. Guarda RD1 (rs1) del banco de registros.
//     - WriteData : en = 1. Guarda RD2 (rs2) del banco de registros.
//     - ALUOut    : en = 1. Guarda el resultado de la ALU.
//     - Data      : en = 1. Guarda el dato leido de memoria (lw).
//
// PARAMETROS:
//   WIDTH   Ancho del registro en bits (32 por defecto).
//
// ENTRADAS:
//   clk           Reloj. Captura en el flanco de subida.
//   rst           Reset asincrono, activo en alto. Pone q en 0.
//   en            Habilitacion: 1 = cargar d, 0 = conservar.
//   d[WIDTH-1:0]  Dato de entrada.
//
// SALIDAS:
//   q[WIDTH-1:0]  Dato guardado.
//==============================================================================
module registro #(
    parameter WIDTH = 32                 // ancho configurable al instanciar
)(
    input  wire             clk,         // reloj
    input  wire             rst,         // reset asincrono activo en alto
    input  wire             en,          // habilitacion de escritura
    input  wire [WIDTH-1:0] d,           // dato que entra
    output reg  [WIDTH-1:0] q            // dato guardado (reg: se asigna en always)
);

    // Bloque secuencial: se ejecuta en el flanco de subida del reloj
    // o en el flanco de subida del reset (por eso el reset es asincrono).
    always @(posedge clk or posedge rst) begin
        if (rst)
            q <= {WIDTH{1'b0}};          // reset: todos los bits en 0
                                         // {WIDTH{1'b0}} repite el bit 0 WIDTH veces
        else if (en)
            q <= d;                      // habilitado: guarda el dato nuevo
        // sin else: si en = 0, q conserva su valor
    end

endmodule
