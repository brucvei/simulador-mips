# Simulador MIPS em Assembly

Simulador completo de processador MIPS em linguagem MIPS assembly, compatível com **MARS 4.5+**.

## Estrutura Implementada

### Segmentos de Memória
- **text_seg**: 4096 bytes - armazena instruções (carregadas de `ex-000-073.bin`)
- **data_seg**: 4096 bytes - armazena dados (carregados de `ex-000-073.dat`)
- **stack_seg**: 4096 bytes - espaço disponível para pilha

### Registradores
- **reg_file[32]**: 32 registradores de uso geral ($0-$31)
- **pc**: Program Counter - offset de bytes relativo ao início de text_seg
- **ir**: Instruction Register - armazena instrução atual
- **ciclos**: contador de ciclos (máx. 10.000)

## Procedimentos Implementados

### 1. `inicializar`
- Zera todos os 32 registradores
- Seta PC para 0

### 2. `carregar_arquivo_binario(a0=filename, a1=destino)`
- Abre arquivo especificado em `a0` (syscall 13)
- Carrega bytes em blocos de 1024 para o segmento em `a1`
- Usa syscalls MARS:
    - **13**: open (modo 0 = leitura)
    - **14**: read (até 1024 bytes por vez)
    - **16**: close

### 3. `verifica_endereco(a0=endereco, a1=tipo)`
- Valida se um endereço pertence a um segmento
- Retorna: `v0=1` (válido) ou `v0=0` (inválido)
- Tipos: 0=text, 1=data, 2=stack

### 4. `memoria_leitura(a0=endereco)`
- Lê uma palavra (32-bit) de um endereço
- Retorna: `v0` = valor lido

### 5. `memoria_escrita(a0=endereco, a1=valor)`
- Escreve uma palavra (32-bit) em um endereço

### 6. `fetch`
- Busca instrução apontada por PC
- Armazena em IR
- Incrementa PC em 4 bytes

### 7. `decode`
- Extrai opcode da instrução (IR >> 26)
- Armazena em `opcode_store`

### 8. `executar`
- Decodifica e executa instrução com base em opcode/funct
- Suporta: add, addi, lw, sw, beq, j, syscall

## Instruções Suportadas

| Tipo | Instrução | Opcode | Funct | Descrição |
|------|-----------|--------|-------|-----------|
| R    | add       | 0      | 32    | `$rd = $rs + $rt` |
| I    | addi      | 8      | -     | `$rt = $rs + imm` |
| I    | lw        | 35     | -     | `$rt = mem[$rs + off]` |
| I    | sw        | 43     | -     | `mem[$rs + off] = $rt` |
| I    | beq       | 4      | -     | `if $rs == $rt: PC += off*4` |
| J    | j         | 2      | -     | `PC = target * 4` |
| R    | syscall   | 0      | 12    | Encerra simulação |

## Como Usar

### Pré-requisitos
- **MARS 4.5 ou superior** (precisa suportar syscalls de arquivo)
- Arquivos de entrada: `ex-000-073.bin` e `ex-000-073.dat` na pasta de trabalho

### Passo-a-Passo

#### 1. Abra no MARS
```
File → Open → simulador.asm
```

#### 2. Configure o ambiente de arquivo (IMPORTANTE!)
```
Settings → Assembler options
Certifique-se de que a pasta de trabalho contém:
- ex-000-073.bin
- ex-000-073.dat
```

#### 3. Assemble
```
Ctrl+F3  ou  Assemble
```

#### 4. Execute
```
Ctrl+F5  ou  Run → Go
```

#### 5. (Opcional) Depuração com Breakpoint

Coloque breakpoint na linha do `main_loop` para inspecionar estado após carregamento:
```
Clique no número da linha (próximo a "main_loop:")
Ctrl+F5 para executar até o breakpoint
```

#### 6. Verifique Registradores e Memória

Menu: **Window → Data Segment**

Procure por:
- `text_seg` - instruções carregadas
- `data_seg` - dados carregados
- `reg_file` - estado dos registradores
- `pc` - Program Counter
- `ir` - Instruction Register
- `ciclos` - contador de execução

## Funcionamento

### Loop Principal
```
Enquanto ciclos < 10000:
  1. fetch: PC → IR (buscar instrução)
  2. decode: extrair opcode de IR
  3. executar: executar instrução
  [repetar]
```

Encerra quando:
- Encontra instrução `syscall` (encerra imediatamente)
- Atinge 10.000 ciclos (proteção contra loops infinitos)

## Formato dos Arquivos

### `ex-000-073.bin` (segmento de texto)
- Contém instruções MIPS em formato binário
- Lido como sequência de bytes
- Cada instrução: 4 bytes (word)

### `ex-000-073.dat` (segmento de dados)
- Contém dados do programa em formato binário
- Lido como sequência de bytes

## Registradores MIPS Simulados

```
$0 = $zero   (sempre 0)          $16 = $s0    (salvo)
$1 = $at     (reservado)         $17 = $s1    (salvo)
$2 = $v0     (retorno)           $18 = $s2    (salvo)
$3 = $v1     (retorno)           $19 = $s3    (salvo)
$4 = $a0     (argumento)         $20 = $s4    (salvo)
$5 = $a1     (argumento)         $21 = $s5    (salvo)
$6 = $a2     (argumento)         $22 = $s6    (salvo)
$7 = $a3     (argumento)         $23 = $s7    (salvo)
$8 = $t0     (temporário)        $24 = $t8    (temporário)
$9 = $t1     (temporário)        $25 = $t9    (temporário)
$10 = $t2    (temporário)        $26 = $k0    (kernel)
$11 = $t3    (temporário)        $27 = $k1    (kernel)
$12 = $t4    (temporário)        $28 = $gp    (global pointer)
$13 = $t5    (temporário)        $29 = $sp    (stack pointer)
$14 = $t6    (temporário)        $30 = $fp    (frame pointer)
$15 = $t7    (temporário)        $31 = $ra    (return address)
```

## Autores
Bruna Caetano e Renata Fonseca

## Data
Maio 2026
