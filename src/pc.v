`timescale 1ns / 1ps
//==============================================================================
// Modulo: pc
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// Funcion:
//   Registro de 32 bits que guarda el Contador de Programa (PC), es decir,
//   la direccion de la instruccion que se va a buscar en memoria.
//
// Por que existe:
//   Toda instruccion de RV32I comienza en el estado Fetch leyendo la memoria
//   en la direccion que indica el PC. En la arquitectura multiciclo el PC no
//   cambia en todos los ciclos: solo se actualiza cuando la unidad de control
//   lo habilita con PCWrite:
//     - Fetch:            PCNext = PC + 4 (calculado por la ALU)
//     - Saltos B tomados: PCNext = destino del salto (bne, bge)
//     - jal / jalr:       PCNext = destino del salto
//   En los demas estados el PC debe conservar su valor.
//
// Entradas:
//   clk          Reloj del sistema. El registro se actualiza en el flanco de subida.
//   rst          Reset asincrono, activo en alto. Pone el PC en 0x00000000,
//                direccion donde inicia main en la memoria de instrucciones.
//   PCWrite      Habilitacion de escritura (viene de la logica PC Write).
//                1 = cargar PCNext, 0 = conservar el valor actual.
//   PCNext[31:0] Proxima direccion (viene del mux ResultSrc).
//
// Salidas:
//   PC[31:0]     Direccion actual. Va al mux de direccion de memoria (AdrSrc),
//                al registro OldPC y al mux ALUSrcA.
//==============================================================================
module pc (
    input  wire        clk,
    input  wire        rst,
    input  wire        PCWrite,
    input  wire [31:0] PCNext,
    output reg  [31:0] PC
);

    // Direccion de arranque del programa
    localparam [31:0] RESET_ADDR = 32'h0000_0000;

    // Registro con reset asincrono y habilitacion
    always @(posedge clk or posedge rst) begin
        if (rst)
            PC <= RESET_ADDR;   // reset: volver al inicio del programa
        else if (PCWrite)
            PC <= PCNext;       // la UC habilita la actualizacion
        // si PCWrite = 0 no se asigna nada: el PC conserva su valor
    end

endmodule
