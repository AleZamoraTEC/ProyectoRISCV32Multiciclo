`timescale 1ns / 1ps
//==============================================================================
// Modulo: prep_store
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   "Preparacion de escritura SW y SB" del avance. Combinacional.
//   A partir del dato de rs2, de los 2 bits bajos de la direccion y de funct3,
//   genera el dato acomodado y los permisos de escritura por byte para la
//   memoria.
//     - sw (funct3 = 010): escribe la palabra completa -> WE = 1111.
//     - sb (funct3 = 000): toma rs2[7:0], lo coloca en el byte indicado por
//       Adr[1:0] y habilita solo ese byte -> WE = 0001, 0010, 0100 o 1000.
//   Si MemWrite = 0, WE = 0000 y la memoria no cambia.
//
// POR QUE EXISTE:
//   La memoria guarda palabras de 32 bits, pero sb debe modificar UN solo
//   byte sin tocar los otros tres. En el programa: sb a5,-29(s0) guarda la
//   variable char a.
//
// ENTRADAS:
//   WriteData[31:0]  Dato de rs2 (registro WriteData).
//   Adr[1:0]         Dos bits bajos de la direccion: que byte de la palabra.
//   funct3[2:0]      Distingue sb (000) de sw (010). Se usa funct3[1].
//   MemWrite         Permiso global de escritura de la unidad de control.
//
// SALIDAS:
//   WD[31:0]         Dato acomodado para la memoria.
//   WE[3:0]          Permiso de escritura por byte.
//==============================================================================
module prep_store (
    input  wire [31:0] WriteData,
    input  wire [1:0]  Adr,
    input  wire [2:0]  funct3,
    input  wire        MemWrite,
    output reg  [31:0] WD,
    output reg  [3:0]  WE
);

    always @(*) begin
        if (funct3[1]) begin
            // sw (funct3 = 010): palabra completa
            WD = WriteData;                        // el dato pasa sin cambios
            WE = MemWrite ? 4'b1111 : 4'b0000;     // los 4 bytes, si hay permiso
        end else begin
            // sb (funct3 = 000): un solo byte
            // Se toma el byte bajo, se extiende con ceros a 32 bits y se
            // desplaza 0, 8, 16 o 24 posiciones segun Adr[1:0].
            // {Adr, 3'b000} = Adr * 8  (ej. Adr = 11 -> 11000 = 24)
            WD = {24'b0, WriteData[7:0]} << {Adr, 3'b000};
            // Se habilita solo el byte correspondiente: 0001 desplazado Adr veces.
            WE = MemWrite ? (4'b0001 << Adr) : 4'b0000;
        end
    end

endmodule
