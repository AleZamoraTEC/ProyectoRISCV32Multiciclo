`timescale 1ns / 1ps
// ^ Directiva de tiempo: "1ns / 1ps".
//   - 1ns : unidad de tiempo. Un "#5" en este archivo significa 5 nanosegundos.
//   - 1ps : precision. El simulador redondea los tiempos a 1 picosegundo.

//==============================================================================
// Testbench: tb_pc
// Modulo bajo prueba (DUT, Device Under Test): pc
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// QUE ES UN TESTBENCH:
//   Es un modulo de Verilog que NO se convierte en hardware. Solo existe en la
//   simulacion. Su trabajo es generar las entradas del modulo que se prueba
//   (reloj, reset, datos), observar sus salidas y compararlas con lo que
//   deberian ser. Por eso no tiene puertos de entrada ni de salida.
//
// OBJETIVO DE LA PRUEBA:
//   Verificar que el registro PC:
//     1. Se inicializa en 0x00000000 con el reset.
//     2. Carga PCNext en el flanco de subida solo cuando PCWrite = 1.
//     3. Conserva su valor cuando PCWrite = 0, aunque PCNext cambie.
//     4. Vuelve a 0x00000000 si se activa el reset en medio de la ejecucion,
//        sin esperar el flanco de reloj (reset asincrono).
//
// ESTIMULOS (en orden):
//   E1. rst = 1 durante 2 ciclos, con PCWrite = 1 y PCNext = 0xFFFFFFFF.
//   E2. rst = 0, PCWrite = 1, PCNext = 0x00000004   (simula Fetch: PC + 4).
//   E3. PCWrite = 0, PCNext = 0x00000099            (simula Decode/Execute).
//   E4. PCWrite = 0, PCNext = 0x00000123            (otro estado sin escritura).
//   E5. PCWrite = 1, PCNext = 0x00000048            (salto bne tomado a 0x48).
//   E6. PCWrite = 1, PCNext = 0x0000004C            (Fetch siguiente).
//   E7. rst = 1 a mitad de ciclo, sin flanco de reloj.
//
// RESULTADOS ESPERADOS:
//   E1 -> PC = 0x00000000 (el reset domina sobre PCWrite)
//   E2 -> PC = 0x00000004
//   E3 -> PC = 0x00000004 (se conserva)
//   E4 -> PC = 0x00000004 (se conserva)
//   E5 -> PC = 0x00000048
//   E6 -> PC = 0x0000004C
//   E7 -> PC = 0x00000000 inmediatamente
//
// COMO LEER EL RESULTADO:
//   En la consola (Tcl Console en Vivado) aparece una linea [OK] o [ERROR]
//   por cada caso, y al final "PRUEBA EXITOSA" o "PRUEBA FALLIDA".
//==============================================================================

module tb_pc;
// ^ Declaracion del modulo de prueba. No lleva lista de puertos ( ) porque el
//   testbench es el "nivel mas alto": nada externo se conecta a el.

    //--------------------------------------------------------------------------
    // 1. DECLARACION DE SENALES
    //--------------------------------------------------------------------------
    // Las ENTRADAS del modulo pc se declaran como "reg" en el testbench,
    // porque el testbench les asigna valores dentro de bloques initial/always,
    // y en Verilog solo las variables tipo reg pueden recibir asignaciones ahi.

    reg         clk;        // Reloj que se le da al PC.
    reg         rst;        // Reset que se le da al PC.
    reg         PCWrite;    // Permiso de escritura que se le da al PC.
    reg  [31:0] PCNext;     // Proxima direccion (32 bits: [31:0]).

    // La SALIDA del modulo pc se declara como "wire": es un cable que solo
    // se observa. Quien le da valor es el modulo pc, no el testbench.
    wire [31:0] PC;

    // Contador de casos fallidos. "integer" es un entero de 32 bits con signo,
    // util para contar. Arranca en 0.
    integer errores = 0;

    //--------------------------------------------------------------------------
    // 2. INSTANCIA DEL MODULO BAJO PRUEBA
    //--------------------------------------------------------------------------
    // "pc" es el nombre del modulo (el de pc.v) y "dut" es el nombre de esta
    // copia en particular. Cada ".puerto(senal)" conecta un puerto del modulo
    // con una senal del testbench. Se conecta por nombre para evitar errores
    // de orden.
    pc dut (
        .clk    (clk),      // puerto clk del PC    <- senal clk del testbench
        .rst    (rst),      // puerto rst del PC    <- senal rst del testbench
        .PCWrite(PCWrite),  // puerto PCWrite       <- senal PCWrite del testbench
        .PCNext (PCNext),   // puerto PCNext        <- senal PCNext del testbench
        .PC     (PC)        // puerto PC (salida)   -> cable PC del testbench
    );

    //--------------------------------------------------------------------------
    // 3. GENERACION DEL RELOJ
    //--------------------------------------------------------------------------
    // "initial" se ejecuta una sola vez, al inicio de la simulacion (t = 0).
    // Aqui solo fija el valor inicial del reloj en 0.
    initial clk = 0;

    // "always" se repite para siempre. "#5" espera 5 ns y luego invierte clk
    // (~ es la negacion bit a bit). Resultado: 5 ns en 0, 5 ns en 1...
    // Periodo = 10 ns -> frecuencia de 100 MHz.
    // Flancos de subida en t = 5, 15, 25, 35 ... ns.
    always #5 clk = ~clk;

    //--------------------------------------------------------------------------
    // 4. TAREA DE VERIFICACION
    //--------------------------------------------------------------------------
    // Una "task" es como una funcion que se puede llamar varias veces para no
    // repetir codigo. Esta recibe el valor que DEBERIA tener el PC y una
    // etiqueta de texto con el nombre del caso ("E1", "E2"...).
    //   - input [31:0] esperado      : valor esperado de 32 bits.
    //   - input [8*4-1:0] etiqueta   : texto de hasta 4 caracteres. En Verilog
    //     un texto se guarda como bits: 8 bits por caracter, por eso 8*4 = 32.
    task revisar(input [31:0] esperado, input [8*4-1:0] etiqueta);
        begin
            // "===" compara de forma exacta, incluyendo los valores x
            // (desconocido) y z (alta impedancia). Con "==" una salida en x
            // podria no detectarse como error.
            if (PC === esperado)
                // $display imprime en la consola.
                //   %s   -> imprime texto (la etiqueta)
                //   %08h -> imprime en hexadecimal con 8 digitos, rellenando
                //           con ceros a la izquierda (ej. 00000004)
                $display("[OK]    %s  PC = 0x%08h", etiqueta, PC);
            else begin
                // Si no coincide, se imprime lo obtenido y lo esperado...
                $display("[ERROR] %s  PC = 0x%08h, se esperaba 0x%08h",
                         etiqueta, PC, esperado);
                // ...y se suma 1 al contador de errores.
                errores = errores + 1;
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // 5. SECUENCIA DE ESTIMULOS
    //--------------------------------------------------------------------------
    // Este bloque initial corre una sola vez y aplica los casos en orden.
    // Palabras clave de tiempo que se usan:
    //   @(posedge clk) : esperar al proximo flanco de SUBIDA del reloj.
    //   @(negedge clk) : esperar al proximo flanco de BAJADA del reloj.
    //   #1             : esperar 1 ns.
    //
    // Regla que se sigue en todos los casos:
    //   - Las entradas se cambian en el flanco de BAJADA. Asi quedan estables
    //     medio ciclo antes del flanco de subida, que es cuando el PC captura.
    //     Si se cambiaran justo en el flanco de subida, no estaria claro si el
    //     PC captura el valor viejo o el nuevo (condicion de carrera).
    //   - La salida se revisa 1 ns DESPUES del flanco de subida, para darle
    //     tiempo al registro de actualizarse.
    initial begin

        // ---------------- E1: reset activo ----------------
        // Se activa el reset y, a proposito, tambien PCWrite = 1 con un
        // PCNext "basura" (0xFFFFFFFF). Si el reset tiene prioridad, el PC
        // debe quedar en 0 y NO en 0xFFFFFFFF.
        rst = 1; PCWrite = 1; PCNext = 32'hFFFF_FFFF;
        // 32'hFFFF_FFFF significa: numero de 32 bits, en hexadecimal (h).
        // El guion bajo "_" solo separa los digitos para leer mejor.

        repeat (2) @(posedge clk);  // mantener el reset durante 2 flancos
        #1 revisar(32'h0000_0000, "E1");   // esperado: PC = 0

        // ---------------- E2: primer Fetch (PC + 4) ----------------
        @(negedge clk);             // esperar flanco de bajada
        rst = 0;                    // soltar el reset
        PCWrite = 1;                // la UC da permiso de escritura
        PCNext = 32'h0000_0004;     // proxima direccion: 0 + 4
        @(posedge clk);             // en este flanco el PC captura PCNext
        #1 revisar(32'h0000_0004, "E2");   // esperado: PC = 4

        // ---------------- E3: estado sin escritura ----------------
        // Simula Decode o Execute: PCNext cambia (en el procesador real la
        // ALU sigue calculando cosas), pero PCWrite = 0, asi que el PC
        // debe ignorarlo.
        @(negedge clk);
        PCWrite = 0;                // sin permiso
        PCNext = 32'h0000_0099;     // valor que NO debe entrar
        @(posedge clk);
        #1 revisar(32'h0000_0004, "E3");   // esperado: sigue en 4

        // ---------------- E4: otro estado sin escritura ----------------
        // Se repite con otro valor para confirmar que no fue casualidad.
        @(negedge clk);
        PCWrite = 0;
        PCNext = 32'h0000_0123;
        @(posedge clk);
        #1 revisar(32'h0000_0004, "E4");   // esperado: sigue en 4

        // ---------------- E5: salto tomado ----------------
        // Simula el bne de la direccion 0x38 del programa, que salta a 0x48.
        @(negedge clk);
        PCWrite = 1;                // la logica de saltos habilita escritura
        PCNext = 32'h0000_0048;     // destino del salto
        @(posedge clk);
        #1 revisar(32'h0000_0048, "E5");   // esperado: PC = 0x48

        // ---------------- E6: Fetch siguiente ----------------
        @(negedge clk);
        PCWrite = 1;
        PCNext = 32'h0000_004C;     // 0x48 + 4
        @(posedge clk);
        #1 revisar(32'h0000_004C, "E6");   // esperado: PC = 0x4C

        // ---------------- E7: reset asincrono ----------------
        // Se espera el flanco de bajada (clk = 0) y 2 ns mas, y se activa
        // el reset. En ese momento NO hay flanco de subida del reloj.
        // Si el reset es asincrono, el PC debe volver a 0 de inmediato.
        // Si fuera sincrono, seguiria en 0x4C hasta el siguiente flanco.
        @(negedge clk);
        #2 rst = 1;
        #1 revisar(32'h0000_0000, "E7");   // esperado: PC = 0 sin reloj

        //--------------------------------------------------------------------
        // 6. RESUMEN Y FIN DE LA SIMULACION
        //--------------------------------------------------------------------
        if (errores == 0)
            $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else
            // %0d imprime un entero en decimal sin espacios de relleno.
            $display("PRUEBA FALLIDA: %0d errores.", errores);

        // $finish detiene la simulacion. Sin esto, el "always" del reloj
        // seguiria corriendo indefinidamente.
        $finish;
    end

endmodule
