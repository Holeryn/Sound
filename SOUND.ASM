;####################################################;
;# sound.asm                                        #;
;# gestione speaker attrafverso il timer 2 - pit 1  #;
;####################################################;
;# nasm -f obj sound.asm                            #;
;# tlink sound.obj + exelib.obj                     #;
;####################################################;

;#################SEGMENT STACKSEGM PUBLIC USE16 CLASS=STACK## direttive per l'assembler ###################
CPU     386                 ; SET DI ISTRUZIONI A 32 BIT
%include    "exelib.inc"    ;inclusione libreria per l'i/o

;################### dichiarazioi tipi e costanti ###################
%define STACK_SIZE  0400h   ;1024 byte per lo STACK_SIZE

%assign INT_1Ch     1Ch     ;int 1ch vector (eseguita dopo la 08h)
%assign PIT_FREQ    1193181 ;FREQUENZA DI CLK DEL PIT 1
%assign SPK_PORT    61h     ;PORTA speaker
%assign SPK_ON  00000011b   ;bit mask speaker on
%assign SPK_OFF 11111100b   ;bit mask speaker off
%assign t2p1_port   42h     ;porta timer 2 - pit 1
%assign CWP1_PORT   43h     ;PORTA CWR PIT 1

;################### SEGMENTO DATI ###################
SEGMENT DATASEGM ALIGN=16 PUBLIC USE16 CLASS=DATA

;################### INIZIO DEFINIZIONE VARIABILIE STATICHE ###################
old_int1ch  dd  0   ;indirizzo veccchio vettore 1ch

;vettore note formato da coppie (durata in ticks, frequenza in hz)
note    dw      6, 392, 6, 392, 6, 392, 5, 314, 5, 471, 13, 392
        dw      5, 314, 5, 471, 25, 392, 6, 294, 6, 294, 6, 294      
        dw      5, 314, 5, 471, 25, 392, 13, 392, 5, 392, 5, 392
        dw      13, 392, 5, 368, 5, 349, 5,327, 5, 304, 5, 327
        dw      13, 392, 13, 279, 5, 262, 5, 491, 5, 471, 5, 436
        dw      5, 471, 13, 314, 13, 382, 5, 314, 5, 382, 13, 471, 25, 294 
        dw      13, 392, 5, 392, 5, 392
        dw      13, 392, 5, 368, 5, 349, 5,327, 5, 304, 5, 327
        dw      13, 392, 13, 279, 5, 262, 5, 491, 5, 471, 5, 436
        dw      5, 471, 13, 314, 13, 382, 5, 314, 5, 382, 13, 471, 25, 392 

MAX_NOTE    equ ($ - note) / 4;numero totale note

index_nota  dw  0   ;indice nota corrente
durata      dw  0   ;durata nota corrente

save_port61h    db  0   ;stato originale porta 61h
str_info    db  "nota n. XXXXX, f = XXXXX Hz, durata = XXXXX ticks ",0
;################### FINE DEFIIZIONE VARIABILI STATICHE ###################

;################### SEGMENTO CODICE ###################
SEGMENT CODESEGM ALIGN=16 PUBLIC USE16 CLASS=CODE
..start:    ;entry point
;---riallocazione del psp
    mov ah,4Ah  ;servizio resize memory
    mov bx,350  ;nuova dimensione in paragrafi
    int 21h     ;chiama il dos
;---fine riallocazione del psp

    mov ax,DATASEGM ;TRASFERTISCE DATASEGM
    mov ds,ax       ;in ds attraverso ax

;################### inizio blocco principale istrzioni ###################

    call    far hideCursor  ;nasconde il cursore
    call    far clearScreen ;pulisce lo schermo

; salvataggio stato originale porta 61h

    in  al,SPK_PORT ;LEGGE LA PORTA 61h
    mov [save_port61h],al   ;e salva lo stato originale

; installazione nuova isr per int 1ch

    cli         ;disabilita le int mascherabili
    xor ax,ax   ;ax = 0
    mov es,ax   ;es = paragrafo 0000h
    mov eax,[es:(INT_1Ch * 4)]  ;legge il vecchio vettore 1ch
    mov [old_int1ch],eax    ;e lo salva in old_int1ch

    mov ax,cs   ;ax = Seg(new_int1ch)
    shl eax,16  ;sposta nella word alta di eax
    mov ax,new_int1ch   ;ax = offset(new_int1ch)
    mov [es:(INT_1Ch * 4)],eax  ;installa in lnuovo vettore 1ch

    sti         ;riabilita le int mascherabili

    push    ds  ;copia ds
    pop     es  ;in es (per writeString)
;visualizza una stringa inforamazioni
    mov di,str_info ;es:di punta a str_info
    mov dx,0400h    ;riga 4,colonna 0
    call    far writeString ;mostra la stringa
;loop principale del programma
music_loop:
    cmp word [index_nota],MAX_NOTE  ;ALTRE NOTE DA SUONARE ?
    jb  music_loop  ;controllo loop
;ripristiono stato originale porta 61 h
    mov al,[save_port61h]   ;al = stato originale porta 61h
    and al,SPK_OFF          ;PONE A 0 I BIT 0 E 1 DI AL
    out SPK_PORT,al         ;scrive nella porta 61h
;ripristinop vecchia isr per int 1ch
    cli         ;disabilita le int mascherabili

    xor ax,ax   ; ax = 0
    mov es,ax   ;ax = 0
    mov eax,[old_int1ch]    ;eax = indirizzo vecchio vettore 1ch
    mov [es:(INT_1Ch * 4)],eax  ;ripristina il vecchio vettore 1ch

    sti         ;riabilita le int mascherabili

    call    far showCursor  ;ripristina il cursore
;################### fine blocco principale istruzioni ###################
    mov ah,4ch  ;servizio terminate program
    mov al,0    ;exit code = 0
    int 21h     ;chiama i servizi di dos
;################### inizio blocco procedure ###################
;nuova isrper int1ch
new_int1ch:
    push    eax  ; preserva eax   
    push    ebx  ; preserva ebx
    push    ecx  ; preserva ecx
    push    edx  ; preserva edx
    push    ds   ; preserva ds
    push    es   ; preserva es

    mov ax,DATASEGM ;trasferisce datasegm
    mov ds,ax       ;in ds
    mov es,ax       ;e in es

    cmp word [durata],0 ; la nota dura ancora ?
    ja  exit_isr1ch     ;si

    mov al,[save_port61h]   ; al = statp originale porta 61h
    and al,SPK_OFF          ;PONE A 0 IL BIT 0 E 1 DI AL
    out SPK_PORT,al         ;scrive nella porta 61h

    mov eax,PIT_FREQ        ; EAX = FREQUENZA DI CLK DEL PIT 1
    xor edx,edx             ;edx = 0
    mov bx,[index_nota]     ;indice vettore note
    shl bx,2                ;offset drata vettore note
    mov cx,[note + bx]      ;cx = durata prossima nota
    mov [durata],cx         ;salva in durata
    add bx,2                ;offset frequenza vettore note
    movzx   ecx,word [note + bx]    ;ecx = frequenza prossima nota
    div ecx                 ;valore iniziale contatore (n)
    mov cx,ax               ;salva in cx

    mov al,10111110b        ;cw 0 timer 2 , modo 6, LSB+MSB
    out CWP1_PORT,al        ;scrive la cw nel pit pit 1

    mov al,cl               ;LSB CONTATORE
    out t2p1_port,al        ;scrive LSB nel timer 2
    mov al,ch               ;msb contatore
    out t2p1_port,al        ;scrive msb nel timer 2

    mov al,[save_port61h]   ;al = stato originale porta 61h
    or  al,SPK_ON           ;PONE A 1 I BIT 0 E 1 DI AL
    out SPK_PORT,al         ;scrive nella porta 61h
    
    mov ax,[index_nota]     ;ax = indice nota corrente
    mov bx,ax               ;salva in bx
    mov dx,0408h            ;riga 4,colonna 8
    call    far writeUdec16 ;mostra l'indice

    shl bx,2                ;prossima coppia vettore note
    mov ax,[note+bx+2]      ;ax = frequenza nota cortrente
    mov dx,0413h            ;riga 4,colonna 19
    call    far writeUdec16 ;mostra la frequenza

    inc word [index_nota]   ;incremento indice vettore note

exit_isr1ch:
    mov ax,[durata]         ;ax = duratas nota corrente
    mov dx,0426h            ;riga 4, colonna 38
    call    far writeUdec16 ;mostra la durata

    dec word [durata]       ;decremento durata ad ogni tick

    pop      es       ; ripristina eax  
    pop      ds       ; ripristina ebx
    pop      edx      ; ripristina ecx
    pop      ecx      ; ripristina edx
    pop      ebx      ; ripristina ds
    pop      eax      ; ripristina es
    iret        ;return from interrupt
;################### fine blocco procedure ###################
;################### segmento stack ###################
SEGMENT  STACKSEGM  ALIGN=16    STACK USE16 CLASS=STACK
    resb    STACK_SIZE  ;1024 byteper lo stack
;#########################################################
