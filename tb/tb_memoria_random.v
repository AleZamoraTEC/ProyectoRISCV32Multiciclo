`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_memoria_random
// Modulo bajo prueba (DUT): memoria
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// OBJETIVO DE LA PRUEBA:
//   Complementar tb_memoria comprobando las 16 combinaciones posibles de
//   WE[3:0] (de 0000 a 1111), y verificar que una escritura NO modifica
//   ninguna otra palabra de la memoria.
//
// ESTIMULOS (en orden):
//   1. Limpieza: se escriben 0x00000000 con WE = 1111 en las 256 palabras
//      (0x000 a 0x3FC), usando los puertos del modulo. Despues de cada
//      escritura se revisa que la palabra quedo en 0.
//   2. Escrituras: para cada mascara WE = 0000, 0001, ..., 1111 se elige una
//      direccion distinta con $random y semilla fija (12345), y se escribe el
//      dato WD = 0xA1B2C3D4. La semilla fija hace la prueba repetible.
//   3. Revision: se leen las 256 palabras y se comparan con lo esperado.
//      El resultado de cada palabra se guarda en dump_tb_memoria_random.txt.
//
// RESULTADOS ESPERADOS:
//   - En la palabra que recibio la mascara WE, solo cambian los bytes
//     habilitados:  esperado = 0xA1B2C3D4 AND {WE[3],WE[2],WE[1],WE[0]} por byte.
//     Ejemplos: WE = 0000 -> 0x00000000   WE = 0101 -> 0x00B200D4
//               WE = 1000 -> 0xA1000000   WE = 1111 -> 0xA1B2C3D4
//   - Las otras 240 palabras siguen en 0x00000000.
//   - Mensaje final: "PRUEBA EXITOSA: 16 mascaras y 256 palabras verificadas."
//==============================================================================
module tb_memoria_random;
    localparam integer DEPTH = 256;
    localparam [31:0] PALABRA = 32'hA1B2_C3D4;
    localparam integer SEMILLA_INICIAL = 12345;

    reg clk = 0;
    reg [31:0] Adr = 0, WD = 0;
    reg [3:0] WE = 0;
    wire [31:0] ReadData;

    integer semilla = SEMILLA_INICIAL;
    integer indice, mascara, archivo;
    integer errores = 0;
    reg [DEPTH-1:0] seleccionada = 0;
    reg [3:0] mascara_por_palabra [0:DEPTH-1];
    reg [3:0] we_esperado;
    reg [31:0] mascara_bytes, esperado;

    memoria #(.DEPTH(DEPTH), .MEM_FILE("programa.mem")) dut (
        .clk(clk), .Adr(Adr), .WD(WD), .WE(WE), .ReadData(ReadData)
    );

    always #5 clk = ~clk;

    task escribir(input [31:0] direccion, input [31:0] dato, input [3:0] habilita);
        begin
            @(negedge clk);
            Adr = direccion;
            WD = dato;
            WE = habilita;
            @(posedge clk);
            #1 WE = 0;
        end
    endtask

    initial begin
        // El DUT carga programa.mem al arrancar. Borrarlo por sus puertos
        // permite partir de cero sin cambiar el modulo ni el archivo .mem.
        for (indice = 0; indice < DEPTH; indice = indice + 1) begin
            escribir(indice * 4, 32'b0, 4'b1111);
            if (ReadData !== 32'b0)
                $fatal(1, "La palabra en 0x%03h no se pudo limpiar: %08h", Adr, ReadData);
            mascara_por_palabra[indice] = 0;
        end

        for (mascara = 0; mascara < 16; mascara = mascara + 1) begin
            indice = $random(semilla) & 32'hFF;
            while (seleccionada[indice])
                indice = $random(semilla) & 32'hFF;
            seleccionada[indice] = 1;
            mascara_por_palabra[indice] = mascara[3:0];
            escribir(indice * 4, PALABRA, mascara[3:0]);
        end

        archivo = $fopen("dump_tb_memoria_random.txt", "w");
        if (!archivo)
            $fatal(1, "No se pudo abrir dump_tb_memoria_random.txt");

        $display("Semilla=%0d  WD=0x%08h", SEMILLA_INICIAL, PALABRA);
        $fdisplay(archivo, "Semilla=%0d  WD=0x%08h", SEMILLA_INICIAL, PALABRA);
        $fdisplay(archivo, "Direccion  Probada  WE    Esperado    Leido       Estado");

        // Revisar todas las palabras tambien detecta escrituras fuera del destino.
        for (indice = 0; indice < DEPTH; indice = indice + 1) begin
            Adr = indice * 4;
            #1;
            we_esperado = mascara_por_palabra[indice];
            mascara_bytes = {{8{we_esperado[3]}}, {8{we_esperado[2]}},
                             {8{we_esperado[1]}}, {8{we_esperado[0]}}};
            esperado = PALABRA & mascara_bytes;
            $fdisplay(archivo, "0x%03h      %b        %04b  0x%08h  0x%08h  %s",
                      Adr[11:0], seleccionada[indice], we_esperado, esperado, ReadData,
                      (ReadData === esperado) ? "OK" : "ERROR");
            if (seleccionada[indice] || ReadData !== esperado)
                $display("Adr=0x%03h WE=%04b esperado=0x%08h leido=0x%08h %s",
                         Adr[11:0], we_esperado, esperado, ReadData,
                         (ReadData === esperado) ? "OK" : "ERROR");
            if (ReadData !== esperado)
                errores = errores + 1;
        end

        $fclose(archivo);
        if (errores != 0)
            $fatal(1, "PRUEBA FALLIDA: %0d diferencias. Revisar dump_tb_memoria_random.txt", errores);
        $display("PRUEBA EXITOSA: 16 mascaras y 256 palabras verificadas.");
        $display("Dump escrito en dump_tb_memoria_random.txt");
        $finish;
    end
endmodule
