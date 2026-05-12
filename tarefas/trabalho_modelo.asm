
.text

 # leia o arquivo com as instruções e carregue no segmento de texto
 # leia o arquivo com as instruções e carregue no segmento de dados
 # while (!fim_programa){
 #   busca a instrução
 #   extrai da instrução os campos e incrementa PC (soma 4)
 #   if(intrução é uma chamada aos serviços exit ou exit2)
 #       fim_programa = veradeiro
 #   else{
 #       executa a instrução
 #   }
 #}
 # termina o programa

 .data

 # vetores representando os segmentos de memória simulados
 # vetor representando o banco de registradores de uso geral
 # variáveis PC e IR
 # variáveis dos campos das instruções
