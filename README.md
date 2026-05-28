# Simulador MIPS em Assembly

Simulador completo de processador MIPS em linguagem MIPS assembly, compatível com **MARS 4.5+**.

## Estrutura Implementada

### Segmentos de Memória
- **text_seg**: 4096 bytes - armazena instruções (carregadas de `ex-000-073.bin`)
- **data_seg**: 4096 bytes - armazena dados (carregados de `ex-000-073.dat`)
- **stack_seg**: 4096 bytes - espaço disponível para pilha

### Registradores
- **reg_file[32]**: 32 registradores de uso geral ($0-$31)
- **pc**: Program Counter - offset simples (bytes, 0 a 4096)
- **ir**: Instruction Register - armazena instrução atual
- **ciclos**: contador de ciclos executados
- **text_size**: tamanho total do arquivo `.bin` carregado (em bytes)

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
- Extrai todos os campos da instrução IR:
  - **opcode**: bits 31-26 (tipo de instrução)
  - **rs**: bits 25-21 (registrador source)
  - **rt**: bits 20-16 (registrador target)
  - **rd**: bits 15-11 (registrador destino)
  - **shamt**: bits 10-6 (shift amount)
  - **funct**: bits 5-0 (função, para R-type)
  - **immediate**: bits 15-0 (valor imediato, estendido com sinal)
  - **address**: bits 25-0 (endereço para J-type)
- Armazena tudo em variáveis globais para acesso pelo executor

### 8. `executar`
- Decodifica e executa instrução com base em opcode/funct
- Suporta múltiplos tipos:
  - **R-type** (opcode=0): add, sub, and, or, sll, srl, syscall
  - **I-type** (opcode≠0): addi, andi, ori, lw, sw, beq, bne
  - **J-type** (opcode=2): j
- Exibe checkpoint de debug para cada tipo de instrução
- Protege $zero ($0) contra escrita accidental

## Instruções Suportadas

| Tipo | Instrução | Opcode | Funct | Descrição |
|------|-----------|--------|-------|-----------|
| R    | add       | 0      | 32    | `$rd = $rs + $rt` |
| R    | sub       | 0      | 34    | `$rd = $rs - $rt` |
| R    | and       | 0      | 36    | `$rd = $rs & $rt` |
| R    | or        | 0      | 37    | `$rd = $rs \| $rt` |
| R    | sll       | 0      | 0     | `$rd = $rt << shamt` |
| R    | srl       | 0      | 2     | `$rd = $rt >> shamt` |
| I    | addi      | 8      | -     | `$rt = $rs + imm` |
| I    | andi      | 12     | -     | `$rt = $rs & imm` |
| I    | ori       | 13     | -     | `$rt = $rs \| imm` |
| I    | lw        | 35     | -     | `$rt = mem[$rs + off]` |
| I    | sw        | 43     | -     | `mem[$rs + off] = $rt` |
| I    | beq       | 4      | -     | `if $rs == $rt: PC += off*4` |
| I    | bne       | 5      | -     | `if $rs != $rt: PC += off*4` |
| J    | j         | 2      | -     | `PC = target * 4` |
| R    | syscall   | 0      | 12    | Encerra simulação |

## Como Usar

### Pré-requisitos
- **MARS 4.5 ou superior** (deve suportar syscalls de arquivo: 13, 14, 16)
- Arquivos de entrada: `ex-000-073.bin` e `ex-000-073.dat` na **pasta raiz de trabalho do MARS**

### Passo-a-Passo

#### 1. Preparar Arquivos
Certifique-se de que os arquivos estão na pasta **raiz** (mesma pasta que você abre o MARS):
```
sua-pasta-de-trabalho/
├── simulador.asm       ← arquivo principal
├── ex-000-073.bin      ← instruções (OBRIGATÓRIO)
└── ex-000-073.dat      ← dados (OBRIGATÓRIO)
```

#### 2. Abra no MARS
```
File → Open → simulador.asm
```

#### 3. Assemble
```
Ctrl+F3  (ou  Assemble)
```

#### 4. Execute
```
Ctrl+F5  (ou  Run → Go)
```
Verá a saída no console:
```
=== SIMULADOR MIPS INICIADO ===
Carregando arquivo TEXT (instruções)...
Arquivo TEXT carregado
Carregando arquivo DATA (dados)...
Arquivo DATA carregado
Aquivos carregados. Iniciando execucao...
Tamanho do arquivo: XXX bytes
--- CICLO 1 | PC: 0x00000000 | IR: 0x[...]
[INSTRUÇÃO] ...
```

#### 5. (Opcional) Depuração com Breakpoint

Coloque breakpoint na linha do `main_loop`:
```
Clique no número da linha esquerda
Ctrl+F5 para executar até o breakpoint
```

#### 6. Verifique Registradores e Memória

Menu: **Window → Data Segment**

Procure por:
- `text_seg` - instruções carregadas do `.bin`
- `data_seg` - dados carregados do `.dat`
- `reg_file` - estado dos registradores (32 words)
- `pc` - Program Counter (offset atual)
- `ir` - Instruction Register (instrução sendo executada)
- `ciclos` - contador de execução

## Funcionamento

### Loop Principal
```
Enquanto PC < tamanho_do_arquivo:
  1. fetch: buscar instrução em text_seg[PC] → IR
  2. decode: extrair opcode, rs, rt, rd, shamt, funct da instrução
  3. executar: executar instrução de acordo com opcode
  4. PC += 4 (para próxima instrução)
  [repetir]
```

### Saída de Debug
Cada ciclo imprime:
```
--- CICLO N | PC: 0xZZZZZZZZ | IR: 0xZZZZZZZZ
[INSTRUÇÃO] ...
```

### Encerramento do Simulador
O programa encerra quando:
- **PC >= text_size**: Atingiu o fim do arquivo de instruções
- **syscall**: Instrução de encerramento executada (reg[2] = 10)
- **Proteção**: Máximo de 10.000 ciclos (proteção contra loops infinitos)

## Arquitetura Interna

### Sistema de Endereçamento
- **Offsets Simples**: PC e endereços em `lw`/`sw` usam offsets relativos (0 a 4096)
- **Base text_seg**: Instruções estão no segmento `text_seg` do MARS
- **Base data_seg**: Dados estão no segmento `data_seg` do MARS
- Sem conversões complexas de endereços absolutos ✅

### Tratamento Especial
- **$zero ($0)**: Sempre 0, protegido contra escrita
- **Immediate**: Estendido com sinal (16 bits → 32 bits)
- **Branches**: Offset multiplicado por 4 antes de somar ao PC
- **Jump (J)**: Address multiplicado por 4 e carregado no PC

## Formato dos Arquivos

### `ex-000-073.bin` (segmento de texto)
- Contém instruções MIPS em formato binário
- Lido como sequência de bytes (little-endian para big-endian)
- Cada instrução: 4 bytes (word)
- Multiplicidade de 4 bytes é recomendada

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

## Limitações e Extensões Futuras

### Limitações Atuais
- **Segmentos de memória**: máximo 4096 bytes cada
- **Registradores**: 32 registradores (padrão MIPS)
- **Syscalls**: apenas terminação do programa (reg[2] = 10, 1, ou 17)
- **Cache**: não implementado (sem relevância para simulador simples)

### Possíveis Extensões
- Adicionar syscalls de I/O (print, read)
- Suportar chamadas de função (`jal`, `jr`) com pilha
- Implementar interrupções e exceções
- Adicionar cache L1/L2 com políticas de substituição
- Suportar arquivos de memória SRAM/DRAM simulate
- Análise de desempenho (CPI, throughput)

## Troubleshooting

| Problema | Causa | Solução |
|----------|-------|---------|
| "ERRO: Falha ao abrir arquivo!" | Arquivos não estão no diretório correto | Coloque `.bin` e `.dat` na pasta raiz de trabalho do MARS |
| Simulação não avança | Arquivo vazio ou inválido | Verifique que o arquivo `.bin` contém instruções válidas |
| Registradores sempre zero | Nenhuma instrução foi executada | Verificar se há instruções de escrita em registradores |
| PC fica muito grande | Jump (J) para endereço inválido | Verificar corretude do programa MIPS original |

## Autores e Data

**Bruna Caetano** e **Renata Fonseca**

Disciplina: Organização de Computadores 
Universidade Federal de Santa Maria - UFSM  
Maio 2026
