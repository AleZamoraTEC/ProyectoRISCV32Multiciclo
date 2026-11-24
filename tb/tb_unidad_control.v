`timescale 1ns / 1ps
// ^ Unidad de tiempo 1 ns, precision 1 ps.

//==============================================================================
// Testbench: tb_unidad_control
// Modulo bajo prueba (DUT): unidad_control (FSM + decodificador ALU)
//
// OBJETIVO DE LA PRUEBA:
//   1. Verificar la SECUENCIA DE ESTADOS de cada tipo de instruccion del
//      programa, desde FETCH hasta volver a FETCH.
//   2. Verificar senales clave en estados especificos, en particular las dos
//      correcciones respecto al avance:
//        - addi con bit 30 = 1 debe dar ALUControl = ADD (no SUB).
//        - JAL y JALR deben tener PCUpdate = 1 y Branch = 0.
//
// CODIGOS DE ESTADO:
//   0 FETCH  1 DECODE  2 MEMADR  3 MEMREAD  4 MEMWB  5 MEMWRITE  6 EXECUTER
//   7 EXECUTEI  8 LUIWB  9 ALUWB  10 EXECUTEIJ  11 JAL  12 JALR  13 BRANCH
//
// ESTIMULOS (en orden) Y RESULTADOS ESPERADOS (estados visitados):
//   C1 lw   (0000011)            0 1 2 3 4 0
//   C2 sw   (0100011)            0 1 2 5 0
//   C3 addi (0010011, f3=000, bit30=1)  0 1 7 9 0   y ALUControl = 0010 en EXECUTEI
//   C4 andi (0010011, f3=111)    0 1 7 9 0          y ALUControl = 0000 en EXECUTEI
//   C5 slli (0010011, f3=001)    0 1 7 9 0          y ALUControl = 1111 en EXECUTEI
//   C6 lui  (0110111)            0 1 8 0            y escritura directa de ALUResult
//   C7 jal  (1101111)            0 1 10 11 0        y PCUpdate = 1, Branch = 0 en JAL
//   C8 jalr (1100111)            0 1 10 12 0        y PCUpdate = 1, Branch = 0 en JALR
//   C9 bne  (1100011, f3=001)    0 1 13 0           y Branch = 1, ALUControl = 0110
//   C10 R add (0110011, f3=000, bit30=0) 0 1 6 9 0  y ALUControl = 0010
//   C11 R sub (0110011, f3=000, bit30=1) 0 1 6 9 0  y ALUControl = 0110 en EXECUTER
//
//   Parte 1 recorre las 11 secuencias (en el orden C1..C11).
//   Parte 2 vuelve a ejecutar instrucciones y, al llegar al estado indicado,
//   revisa las senales de control de ese estado.
//==============================================================================
module tb_unidad_control;

    reg        clk, rst;                 // reloj y reset
    reg  [6:0] opcode;                   // entradas que normalmente da el
    reg  [2:0] funct3;                   // decodificador de instrucciones
    reg        funct7b5;

    // Salidas de la unidad de control
    wire       AdrSrc, IRWrite, RegWrite, MemWrite, PCUpdate, Branch;
    wire [1:0] ALUSrcA, ALUSrcB, ResultSrc;
    wire [3:0] ALUControl, estado;

    integer errores = 0;
    integer n;                            // contador de estados visitados

    unidad_control dut (
        .clk(clk), .rst(rst), .opcode(opcode), .funct3(funct3), .funct7b5(funct7b5),
        .AdrSrc(AdrSrc), .IRWrite(IRWrite), .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB),
        .ResultSrc(ResultSrc), .RegWrite(RegWrite), .MemWrite(MemWrite),
        .PCUpdate(PCUpdate), .Branch(Branch),
        .ALUControl(ALUControl), .estado(estado)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    //--------------------------------------------------------------------------
    // Tarea: ejecutar una instruccion completa y comparar la secuencia.
    //   Se registra el estado actual (FETCH) y luego, en cada flanco, el
    //   estado nuevo, hasta volver a FETCH. Cada estado ocupa 4 bits (un digito
    //   hexadecimal), asi que la secuencia se puede escribir en hexadecimal:
    //   lw = 0,1,2,3,4,0 -> 24'h012340.   jal = 0,1,A,B,0 -> 24'h001AB0
    //   (A = 10 = EXECUTEIJ, B = 11 = JAL, C = 12 = JALR, D = 13 = BRANCH)
    //--------------------------------------------------------------------------
    task ejecutar(input [8*4-1:0] etiqueta, input [6:0] op, input [2:0] f3,
                  input f7, input [23:0] esperada);
        reg [23:0] obtenida;              // estados realmente visitados
        begin
            opcode = op; funct3 = f3; funct7b5 = f7;    // "cargar" la instruccion
            obtenida = {20'b0, estado};                 // primer estado (FETCH)
            n = 0;
            // avanzar hasta volver a FETCH (maximo 6 estados por seguridad)
            while ((n == 0 || estado != 4'd0) && n < 6) begin
                @(posedge clk); #1;                     // siguiente estado
                obtenida = {obtenida[19:0], estado};    // desplazar y agregar
                n = n + 1;
            end
            if (obtenida === esperada)
                $display("[OK]    %s  estados: %h", etiqueta, obtenida);
            else begin
                $display("[ERROR] %s  estados: %h, se esperaba %h",
                         etiqueta, obtenida, esperada);
                errores = errores + 1;
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Tarea: avanzar hasta un estado y revisar una condicion en ese momento
    //--------------------------------------------------------------------------
    task esperar_estado(input [3:0] e);
        begin
            while (estado !== e) begin @(posedge clk); #1; end
        end
    endtask

    task chequear(input [8*4-1:0] etiqueta, input cond, input [8*40-1:0] texto);
        begin
            if (cond) $display("[OK]    %s  %s", etiqueta, texto);
            else begin
                $display("[ERROR] %s  fallo: %s", etiqueta, texto);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        // Reset: la FSM debe arrancar en FETCH
        rst = 1; opcode = 0; funct3 = 0; funct7b5 = 0;
        #12 rst = 0; #1;                  // soltar reset entre flancos

        // ---- 1. Secuencias de estados
        //       etiqueta opcode      f3      f7 estados esperados (hex)
        ejecutar("C1",  7'b0000011, 3'b010, 1, 24'h012340);   // lw
        ejecutar("C2",  7'b0100011, 3'b010, 1, 24'h001250);   // sw
        ejecutar("C3",  7'b0010011, 3'b000, 1, 24'h001790);   // addi
        ejecutar("C4",  7'b0010011, 3'b111, 0, 24'h001790);   // andi
        ejecutar("C5",  7'b0010011, 3'b001, 0, 24'h001790);   // slli
        ejecutar("C6",  7'b0110111, 3'b000, 0, 24'h000180);   // lui
        ejecutar("C7",  7'b1101111, 3'b000, 0, 24'h001AB0);   // jal
        ejecutar("C8",  7'b1100111, 3'b000, 0, 24'h001AC0);   // jalr
        ejecutar("C9",  7'b1100011, 3'b001, 0, 24'h0001D0);   // bne
        ejecutar("C10", 7'b0110011, 3'b000, 0, 24'h001690);   // add tipo R
        ejecutar("C11", 7'b0110011, 3'b000, 1, 24'h001690);   // sub tipo R

        // ---- 2. Senales en estados especificos
        // C3: addi con bit 30 = 1 debe SUMAR (correccion)
        opcode = 7'b0010011; funct3 = 3'b000; funct7b5 = 1;
        esperar_estado(4'd7);
        chequear("C3", ALUControl === 4'b0010, "addi bit30=1 -> ADD");

        // C4: andi
        esperar_estado(4'd0); funct3 = 3'b111;
        esperar_estado(4'd7);
        chequear("C4", ALUControl === 4'b0000, "andi -> AND");

        // C5: slli
        esperar_estado(4'd0); funct3 = 3'b001; funct7b5 = 0;
        esperar_estado(4'd7);
        chequear("C5", ALUControl === 4'b1111, "slli -> SLL");

        // C6: lui
        esperar_estado(4'd0); opcode = 7'b0110111;
        esperar_estado(4'd8);
        chequear("C6", ALUSrcA === 2'b11 && ALUSrcB === 2'b01 &&
                       ALUControl === 4'b0010, "LUIWB suma cero e inmediato");
        chequear("C6", ResultSrc === 2'b10 && RegWrite === 1'b1,
                 "LUIWB escribe ALUResult en rd");
        chequear("C6", {MemWrite, PCUpdate, Branch, IRWrite} === 4'b0000,
                 "LUIWB solo escribe rd");

        // C7: jal (correccion PCUpdate = 1, Branch = 0)
        esperar_estado(4'd0); opcode = 7'b1101111;
        esperar_estado(4'd10);
        chequear("C7", RegWrite === 1'b1, "Execute IJ escribe el retorno");
        esperar_estado(4'd11);
        chequear("C7", PCUpdate === 1'b1 && Branch === 1'b0, "JAL -> PCUpdate=1 Branch=0");

        // C8: jalr
        esperar_estado(4'd0); opcode = 7'b1100111;
        esperar_estado(4'd12);
        chequear("C8", PCUpdate === 1'b1 && Branch === 1'b0, "JALR -> PCUpdate=1 Branch=0");

        // C9: bne
        esperar_estado(4'd0); opcode = 7'b1100011; funct3 = 3'b001;
        esperar_estado(4'd13);
        chequear("C9", Branch === 1'b1 && ALUControl === 4'b0110, "BRANCH -> Branch=1 y SUB");

        // C11: tipo R sub (opcode[5] = 1 y bit 30 = 1)
        esperar_estado(4'd0); opcode = 7'b0110011; funct3 = 3'b000; funct7b5 = 1;
        esperar_estado(4'd6);
        chequear("C11", ALUControl === 4'b0110, "sub tipo R -> SUB");

        // C2 extra: en MEMWRITE se escribe memoria y no registros
        esperar_estado(4'd0); opcode = 7'b0100011; funct3 = 3'b010;
        esperar_estado(4'd5);
        chequear("C2", MemWrite === 1'b1 && RegWrite === 1'b0 && AdrSrc === 1'b1,
                 "MEMWRITE -> MemWrite=1 RegWrite=0");

        if (errores == 0) $display("PRUEBA EXITOSA: todos los casos pasaron.");
        else              $display("PRUEBA FALLIDA: %0d errores.", errores);
        $finish;
    end

endmodule
