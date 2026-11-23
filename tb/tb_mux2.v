`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_mux2
// Modulo bajo prueba (DUT): mux2
//
// OBJETIVO DE LA PRUEBA:
//   Verificar que el multiplexor de 2 entradas entrega d0 con s = 0 y d1 con
//   s = 1, y que la salida sigue a la entrada seleccionada cuando esta cambia.
//   Se usan los valores del mux AdrSrc en el programa: PC = 0x00000034 y
//   Result = 0x000003E8 (direccion de la variable i).
//
// ESTIMULOS (en orden) Y RESULTADOS ESPERADOS:
//   M1. d0 = 0x00000034, d1 = 0x000003E8, s = 0  -> y = 0x00000034 (PC)
//   M2. mismas entradas, s = 1                   -> y = 0x000003E8 (Result)
//   M3. s = 1, d1 cambia a 0x000003EC            -> y = 0x000003EC
//   M4. s = 0, d0 cambia a 0x00000038            -> y = 0x00000038
//==============================================================================
module tb_mux2;

    reg  [31:0] d0, d1;       // entradas de datos (las da el testbench)
    reg         s;            // selector
    wire [31:0] y;            // salida (se observa)

    integer errores = 0;      // contador de fallos

    // DUT de 32 bits
    mux2 #(32) dut (.d0(d0), .d1(d1), .s(s), .y(y));

    // Aplica las entradas, espera y compara. No hay reloj: es combinacional,
    // basta con esperar unos ns para que el simulador propague el cambio.
    task probar(input [8*2-1:0] etiqueta, input [31:0] a0, input [31:0] a1,
                input sel, input [31:0] esperado);
        begin
            d0 = a0; d1 = a1; s = sel;                 // aplicar estimulo
            #10;                                       // esperar propagacion
            if (y === esperado)
                $display("[OK]    %s  s=%b  y = 0x%08h", etiqueta, s, y);
            else begin
                $display("[ERROR] %s  s=%b  y = 0x%08h, se esperaba 0x%08h",
                         etiqueta, s, y, esperado);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        //     caso  d0            d1            s  esperado
        probar("M1", 32'h00000034, 32'h000003E8, 0, 32'h00000034);
        probar("M2", 32'h00000034, 32'h000003E8, 1, 32'h000003E8);
        probar("M3", 32'h00000034, 32'h000003EC, 1, 32'h000003EC);
        probar("M4", 32'h00000038, 32'h000003EC, 0, 32'h00000038);

        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
