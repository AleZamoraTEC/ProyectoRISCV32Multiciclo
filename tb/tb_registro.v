`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns (un "#5" = 5 ns), precision 1 ps.

//==============================================================================
// Testbench: tb_registro
// Modulo bajo prueba (DUT): registro
//
// OBJETIVO DE LA PRUEBA:
//   Verificar el registro generico que se usa como OldPC, Instr, A,
//   WriteData, ALUOut y Data:
//     1. El reset lo pone en 0.
//     2. Con en = 1 guarda d en el flanco de subida.
//     3. Con en = 0 conserva su valor aunque d cambie (caso OldPC/Instr
//        fuera de Fetch).
//     4. No cambia entre flancos aunque d cambie (solo captura en el flanco).
//
// ESTIMULOS (en orden):
//   R1. rst = 1, en = 1, d = 0xFFFFFFFF.
//   R2. rst = 0, en = 1, d = 0xFE010113 (primera instruccion del programa).
//   R3. en = 0, d = 0x12345678.
//   R4. en = 1, d = 0x00112E23 (segunda instruccion), se revisa ANTES del flanco.
//   R5. el mismo dato, se revisa DESPUES del flanco.
//
// RESULTADOS ESPERADOS:
//   R1 -> q = 0x00000000   R2 -> q = 0xFE010113   R3 -> q = 0xFE010113
//   R4 -> q = 0xFE010113   R5 -> q = 0x00112E23
//==============================================================================
module tb_registro;
// ^ Modulo de prueba sin puertos: es el nivel mas alto de la simulacion.

    reg         clk;          // reloj generado por el testbench
    reg         rst;          // reset generado por el testbench
    reg         en;           // habilitacion generada por el testbench
    reg  [31:0] d;            // dato de entrada generado por el testbench
    wire [31:0] q;            // salida del registro: solo se observa (wire)

    integer errores = 0;      // cuenta los casos que fallan

    // Instancia del DUT con WIDTH = 32. "#(32)" fija el parametro WIDTH.
    registro #(32) dut (
        .clk(clk),            // reloj del testbench  -> puerto clk
        .rst(rst),            // reset del testbench  -> puerto rst
        .en (en),             // habilitacion         -> puerto en
        .d  (d),              // dato                 -> puerto d
        .q  (q)               // puerto q (salida)    -> cable q
    );

    initial clk = 0;          // el reloj arranca en 0
    always #5 clk = ~clk;     // se invierte cada 5 ns: periodo 10 ns

    // Tarea de verificacion: compara q con el valor esperado.
    task revisar(input [31:0] esperado, input [8*2-1:0] etiqueta);
        begin
            if (q === esperado)                         // === compara tambien x y z
                $display("[OK]    %s  q = 0x%08h", etiqueta, q);
            else begin
                $display("[ERROR] %s  q = 0x%08h, se esperaba 0x%08h",
                         etiqueta, q, esperado);
                errores = errores + 1;                  // sumar un error
            end
        end
    endtask

    initial begin
        // R1: reset activo con datos basura en la entrada
        rst = 1; en = 1; d = 32'hFFFF_FFFF;
        @(posedge clk); #1 revisar(32'h0000_0000, "R1");  // tras el flanco: 0

        // R2: se suelta el reset y se carga una instruccion
        @(negedge clk); rst = 0; en = 1; d = 32'hFE01_0113; // cambiar en flanco de bajada
        @(posedge clk); #1 revisar(32'hFE01_0113, "R2");     // la capturo

        // R3: sin habilitacion, el dato nuevo NO debe entrar
        @(negedge clk); en = 0; d = 32'h1234_5678;
        @(posedge clk); #1 revisar(32'hFE01_0113, "R3");     // conserva

        // R4: con habilitacion, pero se revisa antes del flanco de subida
        @(negedge clk); en = 1; d = 32'h0011_2E23;
        #1 revisar(32'hFE01_0113, "R4");                     // aun no hay flanco

        // R5: despues del flanco ya debe tener el dato nuevo
        @(posedge clk); #1 revisar(32'h0011_2E23, "R5");

        // Resumen final
        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;                                             // terminar simulacion
    end

endmodule
