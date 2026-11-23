`timescale 1ns / 1ps
//==============================================================================
// Modulo: unidad_control  (FSM y decodificador ALU del control en el avance)
// Proyecto: Microarquitectura multiciclo RV32I - MT-7003, II Semestre 2026
//
// FUNCION:
//   1. MAQUINA DE ESTADOS (FSM): decide en que paso de la instruccion se esta
//      y genera las senales de control de la ruta de datos para ese paso.
//   2. DECODIFICADOR ALU: a partir de ALUOp (que da la FSM), funct3 y
//      funct7b5, elige la operacion de la ALU (ALUControl).
//
// SECUENCIAS DE ESTADOS (seccion "Secuencia de estados" del avance):
//   Todas:          FETCH -> DECODE -> ...
//   lw:             MEMADR -> MEMREAD -> MEMWB -> FETCH
//   sw, sb:         MEMADR -> MEMWRITE -> FETCH
//   addi/andi/slli: EXECUTEI -> ALUWB -> FETCH
//   tipo R:         EXECUTER -> ALUWB -> FETCH
//   lui:            LUIWB -> FETCH
//   jal:            EXECUTEIJ -> JAL -> FETCH
//   jalr:           EXECUTEIJ -> JALR -> FETCH
//   bne, bge:       BRANCH -> FETCH
//
// CORRECCIONES RESPECTO A LA TABLA 2 DEL AVANCE:
//   - Estados JAL y JALR: PCUpdate = 1 y Branch = 0. Con Branch = 1 y
//     PCUpdate = 0 el salto dependia de las banderas de una suma y no se
//     tomaba.
//   - Decodificador ALU: con ALUOp = 10 y funct3 = 000 se resta SOLO si es
//     tipo R (opcode[5] = 1) y funct7b5 = 1. En addi el bit 30 es parte del
//     inmediato: addi sp,sp,-32 y addi a5,a5,2015 tienen el bit 30 en 1 y se
//     ejecutaban como resta.
//
// ENTRADAS:
//   clk, rst      Reloj y reset asincrono activo en alto (reset -> FETCH).
//   opcode[6:0]   Instr[6:0].
//   funct3[2:0]   Instr[14:12].
//   funct7b5      Instr[30].
//
// SALIDAS (valores segun el estado, ver tabla en el case):
//   AdrSrc        0 = memoria lee en PC, 1 = memoria usa Result.
//   IRWrite       1 = cargar Instr y OldPC.
//   ALUSrcA[1:0]  00 PC, 01 OldPC, 10 A, 11 cero.
//   ALUSrcB[1:0]  00 WriteData, 01 ImmExt, 10 cuatro, 11 cero.
//   ResultSrc[1:0] 00 ALUOut, 01 Data, 10 ALUResult.
//   RegWrite      1 = escribir Result en rd.
//   MemWrite      1 = escribir en memoria (prep_store define los bytes).
//   PCUpdate      1 = actualizar el PC sin condicion.
//   Branch        1 = actualizar el PC si se cumple la condicion del salto.
//   ALUControl[3:0] operacion de la ALU (codigos de la Tabla 3).
//   estado[3:0]   estado actual (para observarlo en simulacion).
//==============================================================================
module unidad_control (
    input  wire       clk,
    input  wire       rst,
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       funct7b5,
    output reg        AdrSrc,
    output reg        IRWrite,
    output reg  [1:0] ALUSrcA,
    output reg  [1:0] ALUSrcB,
    output reg  [1:0] ResultSrc,
    output reg        RegWrite,
    output reg        MemWrite,
    output reg        PCUpdate,
    output reg        Branch,
    output reg  [3:0] ALUControl,
    output reg  [3:0] estado
);

    //--------------------------------------------------------------------------
    // Codificacion de los estados (4 bits alcanzan para 14 estados)
    //--------------------------------------------------------------------------
    localparam [3:0] FETCH      = 4'd0,
                     DECODE     = 4'd1,
                     MEMADR     = 4'd2,
                     MEMREAD    = 4'd3,
                     MEMWB      = 4'd4,
                     MEMWRITE   = 4'd5,
                     EXECUTER   = 4'd6,
                     EXECUTEI   = 4'd7,
                     LUIWB      = 4'd8,
                     ALUWB      = 4'd9,
                     EXECUTEIJ  = 4'd10,
                     JAL        = 4'd11,
                     JALR       = 4'd12,
                     BRANCH     = 4'd13;

    // Opcodes que usa la FSM para decidir el camino en DECODE
    localparam [6:0] OP_LW   = 7'b0000011,
                     OP_SW   = 7'b0100011,
                     OP_R    = 7'b0110011,
                     OP_I    = 7'b0010011,
                     OP_LUI  = 7'b0110111,
                     OP_JAL  = 7'b1101111,
                     OP_JALR = 7'b1100111,
                     OP_B    = 7'b1100011;

    // Codigos de ALUControl (Tabla 3 del avance)
    localparam [3:0] ALU_AND = 4'b0000, ALU_OR  = 4'b0001, ALU_ADD = 4'b0010,
                     ALU_SUB = 4'b0110, ALU_SLT = 4'b0111, ALU_SLL = 4'b1111;

    reg [3:0] siguiente;   // proximo estado (combinacional)
    reg [1:0] ALUOp;       // senal interna entre la FSM y el decodificador ALU

    //==========================================================================
    // 1. REGISTRO DE ESTADO: en cada flanco pasa al estado siguiente.
    //==========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) estado <= FETCH;      // reset: empezar buscando instruccion
        else     estado <= siguiente;
    end

    //==========================================================================
    // 2. LOGICA DE ESTADO SIGUIENTE (combinacional)
    //==========================================================================
    always @(*) begin
        case (estado)
            FETCH:  siguiente = DECODE;
            DECODE: case (opcode)                       // aqui se ramifica
                        OP_LW, OP_SW: siguiente = MEMADR;
                        OP_R:         siguiente = EXECUTER;
                        OP_I:         siguiente = EXECUTEI;
                        OP_LUI:       siguiente = LUIWB;
                        OP_JAL,
                        OP_JALR:      siguiente = EXECUTEIJ;
                        OP_B:         siguiente = BRANCH;
                        default:      siguiente = FETCH; // opcode no soportado
                    endcase
            // opcode[5] distingue lw (0) de sw/sb (1)
            MEMADR:     siguiente = opcode[5] ? MEMWRITE : MEMREAD;
            MEMREAD:    siguiente = MEMWB;
            EXECUTER,
            EXECUTEI:   siguiente = ALUWB;
            // opcode[3] distingue jal (1) de jalr (0)
            EXECUTEIJ:  siguiente = opcode[3] ? JAL : JALR;
            // estos estados terminan la instruccion
            MEMWB, MEMWRITE, ALUWB,
            LUIWB, JAL, JALR, BRANCH: siguiente = FETCH;
            default:    siguiente = FETCH;
        endcase
    end

    //==========================================================================
    // 3. SALIDAS DE LA FSM (combinacionales, dependen solo del estado)
    //    Primero se ponen todas en un valor seguro (nada se escribe) y luego
    //    cada estado cambia solo las que necesita.
    //==========================================================================
    always @(*) begin
        // valores por defecto
        AdrSrc = 1'b0;  IRWrite = 1'b0;
        ALUSrcA = 2'b00; ALUSrcB = 2'b00; ResultSrc = 2'b00;
        RegWrite = 1'b0; MemWrite = 1'b0;
        PCUpdate = 1'b0; Branch = 1'b0;
        ALUOp = 2'b00;

        case (estado)
            FETCH: begin            // Instr <- Mem[PC];  PC <- PC + 4
                AdrSrc = 1'b0;      // la memoria lee en la direccion PC
                IRWrite = 1'b1;     // guardar instruccion y OldPC
                ALUSrcA = 2'b00;    // A de la ALU = PC
                ALUSrcB = 2'b10;    // B de la ALU = 4
                ALUOp = 2'b00;      // sumar
                ResultSrc = 2'b10;  // Result = ALUResult (PC + 4)
                PCUpdate = 1'b1;    // el PC carga PC + 4
            end
            DECODE: begin           // ALUOut <- OldPC + ImmExt (destino de B)
                ALUSrcA = 2'b01;    // OldPC
                ALUSrcB = 2'b01;    // ImmExt
                ALUOp = 2'b00;      // sumar
            end
            MEMADR: begin           // ALUOut <- rs1 + inmediato
                ALUSrcA = 2'b10;    // A (rs1)
                ALUSrcB = 2'b01;    // ImmExt
                ALUOp = 2'b00;      // sumar
            end
            MEMREAD: begin          // Data <- Mem[ALUOut]
                ResultSrc = 2'b00;  // Result = ALUOut (la direccion)
                AdrSrc = 1'b1;      // la memoria usa Result como direccion
            end
            MEMWB: begin            // rd <- Data
                ResultSrc = 2'b01;  // Result = Data
                RegWrite = 1'b1;
            end
            MEMWRITE: begin         // Mem[ALUOut] <- rs2
                ResultSrc = 2'b00;  // Result = ALUOut (la direccion)
                AdrSrc = 1'b1;
                MemWrite = 1'b1;
            end
            EXECUTER: begin         // ALUOut <- rs1 op rs2
                ALUSrcA = 2'b10;    // A
                ALUSrcB = 2'b00;    // WriteData (rs2)
                ALUOp = 2'b10;      // operacion segun funct3/funct7
            end
            EXECUTEI: begin         // ALUOut <- rs1 op inmediato
                ALUSrcA = 2'b10;    // A
                ALUSrcB = 2'b01;    // ImmExt
                ALUOp = 2'b10;      // operacion segun funct3
            end
            LUIWB: begin            // rd <- 0 + ImmExt (ya desplazado)
                ALUSrcA = 2'b11;    // constante 0
                ALUSrcB = 2'b01;    // inmediato U
                ALUOp = 2'b00;      // ADD
                ResultSrc = 2'b10;  // ALUResult del ciclo actual
                RegWrite = 1'b1;
            end
            ALUWB: begin            // rd <- ALUOut
                ResultSrc = 2'b00;
                RegWrite = 1'b1;
            end
            EXECUTEIJ: begin        // rd <- PC + 0 (PC ya vale OldPC + 4)
                ALUSrcA = 2'b00;    // PC
                ALUSrcB = 2'b11;    // 0
                ALUOp = 2'b00;      // sumar
                ResultSrc = 2'b10;  // Result = ALUResult
                RegWrite = 1'b1;    // guardar direccion de retorno
            end
            JAL: begin              // PC <- OldPC + ImmExt
                ALUSrcA = 2'b01;    // OldPC
                ALUSrcB = 2'b01;    // ImmExt (formato J)
                ALUOp = 2'b00;
                ResultSrc = 2'b10;  // Result = ALUResult
                PCUpdate = 1'b1;    // CORRECCION: salto incondicional
            end
            JALR: begin             // PC <- (rs1 + ImmExt) con bit 0 en 0
                ALUSrcA = 2'b10;    // A (rs1, capturado antes de escribir rd)
                ALUSrcB = 2'b01;    // ImmExt (formato I)
                ALUOp = 2'b00;
                ResultSrc = 2'b10;
                PCUpdate = 1'b1;    // CORRECCION: salto incondicional
            end
            BRANCH: begin           // si se cumple: PC <- ALUOut (destino)
                ALUSrcA = 2'b10;    // A (rs1)
                ALUSrcB = 2'b00;    // WriteData (rs2)
                ALUOp = 2'b01;      // restar para generar banderas
                ResultSrc = 2'b00;  // Result = ALUOut = destino calculado en DECODE
                Branch = 1'b1;      // pc_write_logic decide con las banderas
            end
            default: ;              // valores por defecto
        endcase
    end

    //==========================================================================
    // 4. DECODIFICADOR ALU (Tabla 3 del avance, con la correccion de addi)
    //==========================================================================
    always @(*) begin
        case (ALUOp)
            2'b00: ALUControl = ALU_ADD;           // Fetch, direcciones, saltos J
            2'b01: ALUControl = ALU_SUB;           // comparacion de saltos B
            default:                               // 2'b10: depende de funct3
                case (funct3)
                    3'b000: ALUControl = (opcode[5] & funct7b5) ? ALU_SUB  // sub (tipo R)
                                                                : ALU_ADD; // add, addi
                    3'b001: ALUControl = ALU_SLL;  // sll, slli
                    3'b010: ALUControl = ALU_SLT;  // slt, slti
                    3'b110: ALUControl = ALU_OR;   // or, ori
                    3'b111: ALUControl = ALU_AND;  // and, andi
                    default: ALUControl = ALU_ADD;
                endcase
        endcase
    end

endmodule
