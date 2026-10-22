Leyenda:

* C \= confirmado  
* P \= parcialmente confirmado  
* R \= refutado frente al árbol vivo  
* S \= ya declarado en paper/plan y no hace falta repararlo como código

| ID | Afirmación / hallazgo | Estado | Qué dice la evidencia | Impacto real |
| :---- | :---- | :---- | :---- | :---- |
| E-01 | La raíz Merkle y la prueba ZK no están ancladas de forma end-to-end al tensor real | C | El bridge es off-chain; hay un link, pero no una prueba on-chain que haga de source-of-truth | Alta |
| E-02 | El data layer es un punto de falla sistémica | C | Ingesta y adjudica fuera del contrato; la autenticidad del origen no se verifica on-chain | Alta |
| E-03 | El risk principal es semántico, no clásico (overflow, reentrancy, etc.) | C | No se observa un bug clásico; el riesgo es de integridad de state y trust boundary | Alta |
| E-04 | La forma del statement no es la que el mapa asume | R | En HEAD el statement ya no es \[root, epoch, certifiedNorm\]; tiene más campos y ya no coincide con la lectura del mapa | N/A |
| E-05 | La idea “publicar más campos” no cierra la brecha | C | Publicar campos no es probar propiedades; el circuito no puede derivar muchas cosas de las entradas | Alta |
| E-06 | La fórmula certifiedNorm \= floor(√ΣT\_i²) no es una solución aceptable | R | Contradice la decisión ya registrada en P-03 y en el árbol actual | Alta |
| E-07 | La identidad persistente no está resuelta | C | La reputación está ligada a la dirección y al epoch, no a una identidad duradera y verificable | Media/Alta |
| E-08 | La custodia opcional es débil | C | custody puede no configurarse; el path de “declared, not backed” existe | Media |
| E-09 | El slash completo por estado cero es un diseño serio | C | El contrato hace amount \= available y ceroes el balance; el diseño es explícito | Media |
| E-10 | La pausa de emergencia no existe | C | No hay un fail-closed path para la admisión ni para rotaciones críticas | Baja/Media |
| E-11 | El root \+ proof \+ state no tienen a dónde ligarse sin usar el tensor | C | El bridge off-chain lo reconoce; el problema sigue no cerrado on-chain | Alta |
| E-12 | El versionado de f\_c necesita un canal público de exposicion | P | Existen parameters\_digest y chain() off-chain, pero no viajan con el registry en una forma on-chain requerida | Media |
| E-13 | Los roles guardian/sequencer son sensibles | P | Se separan y tienen delay, pero no son un diseño completo de governance | Media |
| E-14 | El tree actual y el paper ya no coinciden con el mapa desactualizado | C | El mapa fue escrito sin ver HEAD ni la decisión M4d | N/A |
| E-15 | El plan de parche del mapa no es la solución adecuada | C | El parche añade superficie pública sin aumentar la prueba real | Alta |
| E-16 | El bridge off-chain es una solución parcial, no global | C | Es una mejor causa de enlace, pero no reemplaza un vínculo semántico de verdad | Alta |
| E-17 | El proyecto es un buen prototipo de investigación | C | Hay paper, verification, arquitectura y código con disciplina | Media/Alta |
| E-18 | El proyecto no está listo para producción completa | C | Falta hardening de orígen, custodia, identidad, slash authority y fail-safe | Alta |

2. Qué está resuelto y qué sigue abierto

2.1 Resuelto / ya cubierto

* La disciplina del repositorio: paper \+ scripts \+ claims \+ auditoría  
* La estructura de módulos  
* La teoría del mecanismo  
* El uso de verification/ como evidencia externa  
* El hecho de que la brecha principal no es técnica clásica  
* El hecho de que hay un bridge off-chain de conexión entre raíces

2.2 Pendiente / abierto

* source-chain authenticity  
* root/tensor/proof semántica  
* identity binding  
* custody mandatory  
* slash authority threshold / multi-signature  
* pause mechanism  
* formula versioning on-chain  
* mejores invariantes de producción  
3. Prioridad de segunda iteración

La segunda iteración debe centrarse en esto:  
A. Cerrar la integridad del origen

* source chain authenticity  
* formula versioning  
* canonical state hash  
* metadata in the proof statement

B. Cerrar la política de seguridad operativa

* custody mandatory  
* identity binding  
* threshold slash authority  
* fail-safe / pause

C. Decidir qué dejar como diseño y qué dejar como código

* ¿se toma sourceChainId como constante inmutable?  
* ¿se toma formulaDigest como inmutable?  
* ¿se deja el bridge off-chain o se fuerza un flow más fuerte?  
* ¿se pone identityCommitment en la ruta crítica o se retrasa?  
4. Recomendación de estrategia para la segunda iteración  
* No repetir el diagnóstico del mapa.  
* No atacar el parche que falla.  
* Enfocarse en:  
  1. el state real que se publica  
  2. la prueba que certifica ese state  
  3. los permisos y la custodia que lo hacen entrar al sistema  
  4. la operativa de failure / slash / identity

