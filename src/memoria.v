`timescale 1ns / 1ps
//==============================================================================
// Modulo: memoria
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   Memoria UNIFICADA de instrucciones y datos (como en la Figura 2 del avance).
//   - Tamano: DEPTH palabras de 32 bits (256 palabras = 1 KB, direcciones
//     0x000 a 0x3FF).
//   - Lectura combinacional (asincrona): ReadData cambia apenas cambia Adr.
//     La arquitectura multiciclo lo necesita asi: el dato se captura en los
//     registros Instr o Data al final del mismo ciclo.
//   - Escritura sincrona por bytes: en el flanco de subida se escriben solo
//     los bytes cuyo bit de WE esta en 1 (necesario para sb).
//   - Formato little endian: el byte 0 de una palabra es el menos significativo.
//   - Al iniciar la simulacion se carga el programa desde MEM_FILE con
//     $readmemh. Este archivo es lo UNICO que se cambia en la defensa.
//   - Incluye la tarea "dump" que escribe el contenido en un archivo de texto.
//
// MAPA DE MEMORIA:
//   0x000 - 0x08C  Programa (36 instrucciones del main).
//   0x3E0 - 0x3FF  Pila de main (sp inicial = 0x400, ver banco_registros.v).
//
// PARAMETROS:
//   DEPTH      Numero de palabras de 32 bits.
//   MEM_FILE   Archivo hexadecimal con el programa (una palabra por linea).
//
// ENTRADAS:
//   clk          Reloj (solo para escribir).
//   Adr[31:0]    Direccion en bytes (sale del mux AdrSrc).
//   WD[31:0]     Dato a escribir, ya acomodado por prep_store.
//   WE[3:0]      Habilitacion por byte (sale de prep_store). 0000 = no escribir.
//
// SALIDAS:
//   ReadData[31:0]  Palabra que contiene la direccion Adr. Va a Instr y Data.
//==============================================================================
module memoria #(
    parameter DEPTH    = 256,
    parameter MEM_FILE = "programa.mem"
)(
    input  wire        clk,
    input  wire [31:0] Adr,
    input  wire [31:0] WD,
    input  wire [3:0]  WE,
    output wire [31:0] ReadData
);

    // Arreglo de memoria: DEPTH palabras de 32 bits cada una.
    // RAM[0] es la direccion 0x0, RAM[1] la 0x4, RAM[2] la 0x8, etc.
    reg [31:0] RAM [0:DEPTH-1];

    // Indice de palabra: la direccion esta en bytes y cada palabra tiene 4
    // bytes, asi que se descartan los 2 bits bajos (dividir entre 4).
    // Se usan solo los bits necesarios segun DEPTH:
    //   AW = log2(DEPTH) redondeado hacia arriba.
    //   DEPTH = 256 da AW = 8, o sea Adr[9:2].
    localparam AW = $clog2(DEPTH);
    wire [AW-1:0] indice = Adr[AW+1:2];

    integer i;                                   // variable para el for

    // Inicializacion (solo existe en simulacion):
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            RAM[i] = 32'h0000_0000;              // 1. llenar todo con ceros
        $readmemh(MEM_FILE, RAM);                // 2. cargar el programa desde 0x0
    end

    // LECTURA combinacional: siempre muestra la palabra de la direccion actual.
    assign ReadData = RAM[indice];

    // ESCRITURA sincrona por bytes, en el flanco de subida.
    // Cada bit de WE habilita un byte de la palabra:
    //   WE[0] -> bits [7:0]    (byte en direccion terminada en ...00)
    //   WE[1] -> bits [15:8]   (byte en direccion terminada en ...01)
    //   WE[2] -> bits [23:16]  (byte en direccion terminada en ...10)
    //   WE[3] -> bits [31:24]  (byte en direccion terminada en ...11)
    always @(posedge clk) begin
        if (WE[0]) RAM[indice][7:0]   <= WD[7:0];
        if (WE[1]) RAM[indice][15:8]  <= WD[15:8];
        if (WE[2]) RAM[indice][23:16] <= WD[23:16];
        if (WE[3]) RAM[indice][31:24] <= WD[31:24];
    end

    //--------------------------------------------------------------------------
    // TAREA DE DUMP DE MEMORIA (solo simulacion)
    // Escribe en "archivo" una linea por palabra con direccion y valor:
    //     Direccion   Valor
    //     0x000       0xFE010113
    // Se llama desde un testbench con:  dut.<instancia>.dump("archivo.txt");
    // Solo imprime las palabras distintas de cero para que el archivo sea corto.
    //--------------------------------------------------------------------------
    task dump(input [8*64-1:0] archivo);         // nombre de hasta 64 caracteres
        integer f, k;
        begin
            f = $fopen(archivo, "w");            // abrir archivo para escribir
            $fdisplay(f, "Direccion de Memoria    Valor en hexadecimal");
            for (k = 0; k < DEPTH; k = k + 1)
                if (RAM[k] != 32'h0)             // omitir palabras vacias
                    $fdisplay(f, "0x%08h              0x%08h", k*4, RAM[k]);
            $fclose(f);                          // cerrar y guardar el archivo
        end
    endtask

endmodule
