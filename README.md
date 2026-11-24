# Microarquitectura RV32I multiciclo

El procesador implementa las 11 instrucciones necesarias para el programa C del proyecto MT-7003. El módulo [`riscv_top`](src/riscv_top.v) tiene dos entradas, `clk` y `rst`. La unidad de control reparte la ejecución de cada instrucción entre varios ciclos y reutiliza una sola ALU y una memoria unificada.


### Registros y flancos

- `PC` carga `PCNext` en un flanco ascendente si `PCWrite=1`. El reset activo en alto lo inicializa en cero.
- `OldPC` e `Instr` capturan simultáneamente con `IRWrite=1` en `FETCH`. En ese flanco, `OldPC` recibe el PC anterior, `Instr` recibe la palabra leída en esa dirección y `PC` recibe `PC+4`. `OldPC` e `Instr` se conservan hasta el siguiente `FETCH`.
- `A` y `WriteData` guardan las dos lecturas combinacionales del banco. `ALUOut` guarda el resultado de la ALU y `Data` guarda la lectura de memoria. Los cuatro capturan cada flanco. En un flanco de escritura, el consumidor usa el valor que estaba estable antes de ese flanco.
- El banco tiene 32 registros de 32 bits, dos puertos de lectura combinacional y un puerto de escritura al flanco ascendente. `x0` siempre devuelve cero e ignora escrituras. El reset pone `x2` (`sp`) en `0x400` y los demás registros en cero.

## Instrucciones y decodificación

| Instrucción | Formato | Opcode | `funct3` | Efecto |
|---|---|---|---|---|
| `ADDI` | I | `0010011` | `000` | Suma `rs1` e inmediato con signo |
| `ANDI` | I | `0010011` | `111` | AND de `rs1` e inmediato con signo |
| `SLLI` | I | `0010011` | `001` | Desplaza `rs1` a la izquierda por `Instr[24:20]` |
| `LW` | I | `0000011` | `010` | Lee una palabra en `rs1 + inmediato` |
| `JALR` | I | `1100111` | `000` | Escribe el enlace y salta a `(rs1 + inmediato) & 0xFFFFFFFE` |
| `SW` | S | `0100011` | `010` | Escribe una palabra de `rs2` |
| `SB` | S | `0100011` | `000` | Escribe los ocho bits bajos de `rs2` en un byte |
| `BNE` | B | `1100011` | `001` | Salta si `rs1 ≠ rs2` |
| `BGE` | B | `1100011` | `101` | Salta si `rs1 ≥ rs2` con signo |
| `LUI` | U | `0110111` | — | Escribe el inmediato en los bits altos de `rd` |
| `JAL` | J | `1101111` | — | Escribe el enlace y salta a `OldPC + inmediato` |

El decodificador extrae `opcode[6:0]` de `Instr[6:0]`, `rd` de `[11:7]`, `funct3` de `[14:12]`, `rs1` de `[19:15]`, `rs2` de `[24:20]` y `funct7b5` de `[30]`. Cada consumidor interpreta las posiciones según el opcode. Por ejemplo, en `JAL`, los bits que aparecen en el cable `funct3` también llegan intactos al ImmGen como parte del inmediato.

| Formato | `ImmSrc` | Construcción de `ImmExt` |
|---|---|---|
| I | `000` | `Instr[31:20]` extendido con signo |
| S | `001` | `{Instr[31:25], Instr[11:7]}` extendido con signo |
| B | `010` | `{Instr[31], Instr[7], Instr[30:25], Instr[11:8], 1'b0}` extendido con signo |
| U | `011` | `{Instr[31:12], 12'b0}` |
| J | `100` | `{Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'b0}` extendido con signo |

El RTL también incluye una ruta tipo R y lógica para `BEQ` y `BLT`. La tabla describe el subconjunto requerido y probado por el programa C. Las pseudoinstrucciones `j` y `ret` se ejecutan como `jal x0, destino` y `jalr x0, 0(ra)`.

## Señales de control

| Selector | `00` | `01` | `10` | `11` |
|---|---|---|---|---|
| `ALUSrcA` | `PC` | `OldPC` | `A` | Constante 0 |
| `ALUSrcB` | `WriteData` | `ImmExt` | Constante 4 | Constante 0 |
| `ResultSrc` | `ALUOut` | `Data` | `ALUResult` | Constante 0 |

| Señal | Función |
|---|---|
| `AdrSrc` | Selecciona `PC` con 0 y `Result` con 1 para direccionar memoria |
| `IRWrite` | Habilita la captura de `Instr` y `OldPC` |
| `RegWrite` | Habilita la escritura de `Result` en `rd` |
| `MemWrite` | Habilita la generación de la máscara de escritura `WE[3:0]` |
| `PCUpdate` | Solicita actualización incondicional del PC en `FETCH`, `JAL` y `JALR` |
| `Branch` | Habilita la condición de rama en `BRANCH` |
| `ALUOp` | Selector interno de control. `00` fuerza ADD, `01` fuerza SUB y `10` decodifica la operación |
| `ALUControl` | `0000` AND, `0001` OR, `0010` ADD, `0110` SUB, `0111` SLT con signo y `1111` SLL |

Para aritmética, el bit 30 selecciona SUB cuando corresponde al campo `funct7` de una instrucción tipo R. En `ADDI`, ese bit pertenece al inmediato. Esto permite que `addi sp,sp,-32` y `addi a5,a5,2015` sigan usando ADD.

## Máquina de estados

Toda instrucción empieza con `FETCH → DECODE`. Los ciclos de la tabla de rutas incluyen ambos estados y terminan cuando la FSM vuelve a `FETCH` para la instrucción siguiente.

| Código | Estado | Acción durante el ciclo |
|---|---|---|
| 0 | `FETCH` | Lee `Mem[PC]`, captura `Instr` y `OldPC` y actualiza `PC ← PC+4` |
| 1 | `DECODE` | Captura operandos, prepara `OldPC+ImmExt` en `ALUOut` para ramas y selecciona la ruta |
| 2 | `MEMADR` | Calcula la dirección efectiva `A+ImmExt` |
| 3 | `MEMREAD` | Usa `ALUOut` como dirección y captura la palabra en `Data` |
| 4 | `MEMWB` | Escribe `Data` en `rd` |
| 5 | `MEMWRITE` | Usa `ALUOut` como dirección y escribe con la máscara de SW o SB |
| 6 | `EXECUTER` | Ejecuta la operación entre `A` y `WriteData` |
| 7 | `EXECUTEI` | Ejecuta la operación entre `A` e `ImmExt` |
| 8 | `LUIWB` | Calcula `0+ImmExt` y escribe `ALUResult` en `rd` |
| 9 | `ALUWB` | Escribe `ALUOut` en `rd` |
| 10 | `EXECUTEIJ` | Escribe el enlace `OldPC+4` usando el PC ya incrementado |
| 11 | `JAL` | Carga el PC con `OldPC+ImmExt` |
| 12 | `JALR` | Carga el PC con `A+ImmExt` y fuerza a cero el bit bajo |
| 13 | `BRANCH` | Resta los operandos y, si corresponde, carga el destino guardado en `ALUOut` |

| Instrucciones | Estados después de `DECODE` | Ciclos totales |
|---|---|---|
| `LW` | `MEMADR → MEMREAD → MEMWB` | 5 |
| `SW`, `SB` | `MEMADR → MEMWRITE` | 4 |
| `ADDI`, `ANDI`, `SLLI` | `EXECUTEI → ALUWB` | 4 |
| Aritmética tipo R implementada | `EXECUTER → ALUWB` | 4 |
| `LUI` | `LUIWB` | 3 |
| `JAL` | `EXECUTEIJ → JAL` | 4 |
| `JALR` | `EXECUTEIJ → JALR` | 4 |
| `BNE`, `BGE` | `BRANCH` | 3 |

### Ramas y saltos

En `BRANCH`, la ALU resta `rs1-rs2` en el mismo ciclo en que el mux entrega el destino ya guardado en `ALUOut`. `BNE` se toma con `!Zero` y `BGE` con `!(Negative ^ Overflow)`. La lógica genera `PCWrite = PCUpdate | (Branch & tomar)` y forma `PCNext = {Result[31:1], 1'b0}`. La máscara afecta efectivamente a `JALR` cuando la suma produce una dirección impar.

En `JALR` con `rd=rs1`, el flanco que cierra `EXECUTEIJ` escribe el enlace y captura en `A` la lectura anterior del banco. Durante el estado `JALR`, la ALU usa ese valor original de `rs1`.

### LUI según el Avance 2

El ImmGen hace el desplazamiento de 12 bits al reconstruir el formato U. En `LUIWB`, `ALUSrcA=11` selecciona cero, `ALUSrcB=01` selecciona `ImmExt` y `ALUControl=0010` selecciona ADD. `ResultSrc=10` entrega el resultado combinacional y `RegWrite=1` lo escribe al flanco que devuelve la FSM a `FETCH`.

Con `lui a5,0xc`, `Instr=0x0000C7B7` y `OldPC=0x10`. El ImmGen entrega `0x0000C000` y `x[15]` captura ese valor en la transición `8 → 0`. El `ADDI` siguiente lo lleva a `0x0000C7DF`.

## Memoria

La configuración del top usa 256 palabras de 32 bits (1 KiB), con lectura combinacional, escritura al flanco ascendente y orden little-endian. El índice de palabra se toma de `Adr[9:2]`. La memoria se inicializa en cero y carga [`programa.mem`](tb/programa.mem) mediante `$readmemh`. El modelo usa los bits de índice indicados y no genera excepciones de alineación ni de acceso fuera de rango.

- `SW` entrega los 32 bits de `WriteData` con `WE=1111`.
- `SB` toma `WriteData[7:0]`, lo desplaza `8 × Adr[1:0]` bits y habilita únicamente ese byte. Por ejemplo, `Adr=0x3E3` y dato `0x62` producen `WD=0x62000000` y `WE=1000`.
- En `LW`, `MEMREAD` captura la lectura en `Data` y `MEMWB` escribe esa palabra en el banco.
- El programa ocupa las direcciones `0x000–0x08F` por bytes, con la última instrucción en `0x08C`. Al reservar 32 bytes desde `sp=0x400`, la pila queda en `0x3E0–0x3FF`.

## Módulos y archivos de prueba

| Módulo | Función | Testbench |
|---|---|---|
| [`riscv_top`](src/riscv_top.v) | Integra la ruta de datos y el control | [`tb_riscv_top`](tb/tb_riscv_top.v) |
| [`unidad_control`](src/unidad_control.v) | FSM y decodificación de la ALU | [`tb_unidad_control`](tb/tb_unidad_control.v) |
| [`pc_write_logic`](src/pc_write_logic.v) | Evalúa las ramas y genera `PCWrite` y `PCNext` | [`tb_pc_write_logic`](tb/tb_pc_write_logic.v) |
| [`pc`](src/pc.v) | Guarda el contador de programa | [`tb_pc`](tb/tb_pc.v) |
| [`registro`](src/registro.v) | Implementa `OldPC`, `Instr`, `A`, `WriteData`, `ALUOut` y `Data` | [`tb_registro`](tb/tb_registro.v) |
| [`memoria`](src/memoria.v) | Memoria unificada y dump a archivo | [`tb_memoria`](tb/tb_memoria.v) |
| [`prep_store`](src/prep_store.v) | Acomoda el dato y genera habilitaciones por byte | [`tb_prep_store`](tb/tb_prep_store.v) |
| [`banco_registros`](src/banco_registros.v) | Almacena `x0–x31` | [`tb_banco_registros`](tb/tb_banco_registros.v) |
| [`decodificador`](src/decodificador.v) | Extrae campos y genera `ImmSrc` | [`tb_decodificador`](tb/tb_decodificador.v) |
| [`unidad_signo`](src/unidad_signo.v) | Reconstruye inmediatos I/S/B/U/J | [`tb_unidad_signo`](tb/tb_unidad_signo.v) |
| [`alu`](src/alu.v) | Calcula resultados y banderas | [`tb_alu`](tb/tb_alu.v) |
| [`mux2`](src/mux2.v) | Selecciona la dirección con `AdrSrc` | [`tb_mux2`](tb/tb_mux2.v) |
| [`mux4`](src/mux4.v) | Selecciona operandos y resultado | [`tb_mux4`](tb/tb_mux4.v) |

## Verificación en Vivado

1. Crear el proyecto de Vivado fuera del repositorio. Agregar `src/*.v` en **Design Sources** y elegir `riscv_top` como top de diseño. Dejar desmarcada la opción **Copy sources into project** para que Vivado lea los Verilog del repositorio.
2. Agregar `tb/*.v` y `tb/programa.mem` en **Simulation Sources**. Elegir `tb_riscv_top` como top de simulación. Si XSim reporta que no puede abrir el archivo, comprobar que `programa.mem` esté disponible con ese nombre en el directorio de ejecución de XSim.
3. Ejecutar **Run Behavioral Simulation → Run All**. Para recompilar después de editar Verilog, usar **Relaunch Simulation**. Para volver a tiempo cero con la misma compilación y registrar las señales ya agregadas, usar **Restart → Run All**.
4. Abrir [la configuración de ondas de defensa](tb/tb_riscv_top_defensa.wcfg) en la simulación. Si se abre después de correrla, usar **Restart → Run All** para registrar las señales desde el inicio. La onda muestra el flujo de instrucciones, los accesos a memoria, las escrituras a registros y las cuatro palabras de RAM del programa original. Confirmar `PRUEBA EXITOSA` en la consola y revisar `dump_memoria.txt`.


| Variable | Dirección | Entrada RAM | Valor final |
|---|---|---|---|
| `a` | `0x3E3` dentro de la palabra en `0x3E0` | `RAM[248]` | `0x62000000`, con `a='b'` |
| `r` | `0x3E4` | `RAM[249]` | `0x0000C7DF` |
| `i` | `0x3E8` | `RAM[250]` | `0x00000002` |
| `b` | `0x3EC` | `RAM[251]` | `0x00000002` |

### Cambiar `b` o la dirección de `r`

Editá el `programa.mem` que usa Vivado y el parámetro correspondiente al inicio de [tb_riscv_top.v](tb/tb_riscv_top.v). Estos ejemplos mantienen las mismas instrucciones y el mismo recorrido.

| Cambio | En `programa.mem` | En el testbench |
|---|---|---|
| Empezar con `b = 7` | En la línea 10 (`0x24`), cambiar `02100793` por `00700793`. | Poner `B_INICIAL = 7`. El testbench comprueba la primera escritura y calcula `(7 << 1) & 0xF = 0xE` al final. |
| Guardar `r` en `0x3F0` | En la línea 7 (`0x18`), cambiar `FEF42223` por `FEF42823`. El `sw` usa el offset `-16(s0)`. | Poner `DIR_R = 32'h3F0`. Se comprueba `0xC7DF` en esa dirección. Para verla en la onda, agregá `RAM[252]`. |

Volvé a lanzar la simulación con **Relaunch Simulation → Run All**. Los valores de `a` e `i`, el valor de `r` y los conteos de 47 instrucciones y 193 ciclos se mantienen para ambos cambios.



