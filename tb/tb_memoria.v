`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_memoria
// Modulo bajo prueba (DUT): memoria
//
// REQUISITO: el archivo programa.mem debe estar agregado como simulation
// source en Vivado (o en la misma carpeta de la simulacion).
//
// OBJETIVO DE LA PRUEBA:
//   1. Verificar que $readmemh carga el programa: la palabra 0x0 debe ser la
//      primera instruccion y la 0x8C la ultima.
//   2. Verificar la lectura combinacional (sin esperar reloj).
//   3. Verificar la escritura de palabra completa (sw, WE = 1111).
//   4. Verificar la escritura de un solo byte (sb) en las cuatro posiciones,
//      sin modificar los otros bytes.
//   5. Verificar que con WE = 0000 la memoria no cambia.
//   6. Generar el dump de memoria en el archivo dump_tb_memoria.txt.
//
// ESTIMULOS (en orden) Y RESULTADOS ESPERADOS:
//   L1. Adr = 0x000, sin escribir         -> ReadData = 0xFE010113
//   L2. Adr = 0x08C, sin escribir         -> ReadData = 0x00008067
//   W1. Adr = 0x3E4, WD = 0x0000C7DF, WE = 1111 (sw de r) -> 0x0000C7DF
//   W2. Adr = 0x3E3, WD = 0x63000000, WE = 1000 (sb de a = 'c')
//                                         -> palabra 0x3E0 = 0x63000000
//   W3. Adr = 0x3E0, WD = 0x000000AA, WE = 0001 (byte 0) -> 0x630000AA
//   W4. Adr = 0x3E1, WD = 0x0000BB00, WE = 0010 (byte 1) -> 0x6300BBAA
//   W5. Adr = 0x3E2, WD = 0x00CC0000, WE = 0100 (byte 2) -> 0x63CCBBAA
//   W6. Adr = 0x3E4, WD = 0xFFFFFFFF, WE = 0000          -> sigue 0x0000C7DF
//   D1. dump: el archivo debe listar el programa y las palabras 0x3E0 y 0x3E4.
//==============================================================================
module tb_memoria;

    reg         clk;            // reloj (solo se usa para escribir)
    reg  [31:0] Adr;            // direccion en bytes
    reg  [31:0] WD;             // dato a escribir
    reg  [3:0]  WE;             // habilitacion por byte
    wire [31:0] ReadData;       // dato leido

    integer errores = 0;

    // DUT: memoria de 256 palabras que carga programa.mem
    memoria #(.DEPTH(256), .MEM_FILE("programa.mem")) dut (
        .clk(clk), .Adr(Adr), .WD(WD), .WE(WE), .ReadData(ReadData)
    );

    initial clk = 0;            // reloj de 10 ns
    always #5 clk = ~clk;

    // Compara ReadData con el valor esperado
    task revisar(input [31:0] esperado, input [8*2-1:0] etiqueta);
        begin
            if (ReadData === esperado)
                $display("[OK]    %s  Mem[0x%03h] = 0x%08h", etiqueta, Adr[9:0], ReadData);
            else begin
                $display("[ERROR] %s  Mem[0x%03h] = 0x%08h, se esperaba 0x%08h",
                         etiqueta, Adr[9:0], ReadData, esperado);
                errores = errores + 1;
            end
        end
    endtask

    // Escribe en un flanco de subida y luego deja WE en 0
    task escribir(input [31:0] dir, input [31:0] dato, input [3:0] we);
        begin
            @(negedge clk);                 // preparar en el flanco de bajada
            Adr = dir; WD = dato; WE = we;
            @(posedge clk);                 // la memoria escribe aqui
            #1 WE = 4'b0000;                // quitar el permiso
        end
    endtask

    initial begin
        WE = 4'b0000; WD = 32'b0;           // al inicio no se escribe nada

        // L1 y L2: lectura del programa cargado (combinacional, sin reloj)
        Adr = 32'h000; #2 revisar(32'hFE01_0113, "L1");
        Adr = 32'h08C; #2 revisar(32'h0000_8067, "L2");

        // W1: sw de la variable r (palabra completa)
        escribir(32'h3E4, 32'h0000_C7DF, 4'b1111);
        Adr = 32'h3E4; #2 revisar(32'h0000_C7DF, "W1");

        // W2: sb de la variable a = 'c' (0x63) en el byte 3 (direccion 0x3E3).
        // prep_store ya entrega el byte desplazado a la posicion [31:24].
        escribir(32'h3E3, 32'h6300_0000, 4'b1000);
        Adr = 32'h3E0; #2 revisar(32'h6300_0000, "W2");

        // W3 a W5: un byte en cada posicion; los demas bytes no deben cambiar
        escribir(32'h3E0, 32'h0000_00AA, 4'b0001);
        Adr = 32'h3E0; #2 revisar(32'h6300_00AA, "W3");
        escribir(32'h3E1, 32'h0000_BB00, 4'b0010);
        Adr = 32'h3E0; #2 revisar(32'h6300_BBAA, "W4");
        escribir(32'h3E2, 32'h00CC_0000, 4'b0100);
        Adr = 32'h3E0; #2 revisar(32'h63CC_BBAA, "W5");

        // W6: WE = 0000, la palabra no debe cambiar
        escribir(32'h3E4, 32'hFFFF_FFFF, 4'b0000);
        Adr = 32'h3E4; #2 revisar(32'h0000_C7DF, "W6");

        // D1: dump de memoria a archivo (se revisa abriendo el archivo)
        dut.dump("dump_tb_memoria.txt");
        $display("[INFO]  D1  dump escrito en dump_tb_memoria.txt");

        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
