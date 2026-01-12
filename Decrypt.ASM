.Model small            
.stack 100h             
.data                   

;;;;;;;;;;;;;; Messages ;;;;;;;;;;;;;;;;;;;;;
msg           db 13,10,'Enter a file: $'                      
msg1          db 13,10,'Operation Success! $'                 
msg2          db 13,10,'Enter a key: $'                       
msg3          db 13,10,'Error accessing file! Check filename.', 13, 10, '$'               
msg_wrong_key db 13,10,'Access Denied: Wrong Key!$'           
msg_limit     db 13,10,'Too many incorrect tries! Exiting...$' 
msg_again     db 13,10,'Would you like to process another file? (y/n): $' 

;;;;;;;;;;;;;; Variables ;;;;;;;;;;;;;;;;;;;;
filename      db 30, ?, 31 dup (?)   
handle        dw 0                   
buffer        db ?                   
key           db 20, ?, 21 dup (?)   
key_ind       dw 0                   
f_size        dw ?                   
stored_key_len db ?                  
stored_key    db 20 dup (?)          
tries         db 0                   
mode          db 0                   ; 0 = Addition (Enc), 1 = Subtraction (Dec)
magic_sig     db 'K','E','Y','X'     
magic_buf     db 4 dup (?)           

.code                   
main proc               
    mov ax, @data       
    mov ds, ax          

program_start:          
    mov tries, 0        
    mov handle, 0       

file_input_stage:       
    mov ah, 09h         
    lea dx, msg         
    int 21h             
    mov ah, 0ah         
    lea dx, filename    
    int 21h             

    lea si, filename    
    mov cl, [si+1]      
    mov ch, 0           
    add si, 2           
    add si, cx          
    mov byte ptr [si], 0 

    mov ah, 3dh         
    mov al, 2           
    lea dx, filename+2  
    int 21h             
    jnc open_ok         
    
    mov ah, 09h
    lea dx, msg3
    int 21h
    jmp file_input_stage 

open_ok:
    mov handle, ax      

ask_key_only:           
    mov ah, 09h         
    lea dx, msg2        
    int 21h             
    lea di, key+2       
    xor cx, cx          
input_key:              
    mov ah, 08h         
    int 21h             
    cmp al, 13          
    je end_input        
    cmp al, 8           
    je handle_backspace 
    cmp cx, 19          
    jae input_key       
    mov [di], al        
    inc di              
    inc cx              
    mov ah, 02h         
    mov dl, '*'         
    int 21h             
    jmp input_key       

handle_backspace:       
    cmp cx, 0           
    je input_key        
    dec di              
    dec cx              
    mov ah, 02h         
    mov dl, 8           
    int 21h             
    mov dl, ' '         
    int 21h             
    mov dl, 8           
    int 21h             
    jmp input_key       

end_input:              
    mov [key+1], cl     

key_check_start:        
    ; Always reset pointer to end to get actual current size
    mov ah, 42h         
    mov al, 2           
    mov bx, handle      
    xor cx, cx          
    xor dx, dx          
    int 21h             
    mov f_size, ax      

    ; Minimum size for encrypted file: Magic(4) + Key(1 min) + LenByte(1) = 6 bytes
    cmp f_size, 6
    jae nest
    jmp jump_to_enc
    nest:

    ; Read the last byte (stored length)
    mov ah, 42h         
    mov al, 2           
    mov bx, handle      
    mov dx, -1          
    mov cx, -1          
    int 21h             

    mov ah, 3fh         
    mov bx, handle      
    lea dx, stored_key_len 
    mov cx, 1           
    int 21h             

    ; Check if stored_key_len is valid (1-20)
    mov al, stored_key_len
    cmp al, 1
    jb jump_to_enc
    cmp al, 20
    ja jump_to_enc

    ; Seek to Magic Signature location
    mov al, stored_key_len
    xor ah, ah
    add ax, 5                 ; key_len + 4(magic) + 1(len_byte)
    neg ax
    mov dx, ax
    mov cx, -1
    mov ah, 42h
    mov al, 2                 
    mov bx, handle
    int 21h

    ; Read and Verify Magic
    mov ah, 3fh
    mov bx, handle
    lea dx, magic_buf
    mov cx, 4
    int 21h

    lea si, magic_buf
    lea di, magic_sig
    mov cx, 4
check_magic:
    mov al, [si]
    cmp al, [di]
    jne jump_to_enc
    inc si
    inc di
    loop check_magic

    ; If magic matches, we are in Decryption Mode. 
    ; NOW verify the key entered matches the footer.
    mov ah, 3fh         
    mov bx, handle      
    lea dx, stored_key  
    mov cl, stored_key_len 
    xor ch, ch          
    int 21h             

    mov al, stored_key_len 
    cmp al, [key+1]     
    jne near_wrong_key   

    lea si, stored_key  
    lea di, key+2       
    mov cl, stored_key_len 
    xor ch, ch
verify_loop:            
    mov al, [si]        
    xor al, 55h         
    cmp al, [di]        
    jne near_wrong_key  
    inc si              
    inc di              
    loop verify_loop    

    jmp start_dec       

jump_to_enc: jmp start_enc
near_wrong_key: jmp wrong_key

start_enc:              
    mov mode, 0         
    mov cx, f_size      
    call process_file   
    
    mov ah, 42h         
    mov al, 2           
    mov bx, handle      
    xor cx, cx          
    xor dx, dx          
    int 21h             

    ; 1. Write Magic
    mov ah, 40h
    mov bx, handle
    lea dx, magic_sig
    mov cx, 4
    int 21h

    ; 2. Write Obfuscated Key
    lea si, key+2       
    mov cl, [key+1]     
    xor ch, ch          
    lea di, stored_key  
prep_loop:               
    mov al, [si]        
    xor al, 55h         
    mov [di], al        
    inc si              
    inc di              
    loop prep_loop       

    mov ah, 40h         
    mov bx, handle      
    lea dx, stored_key  
    mov cl, [key+1]     
    xor ch, ch          
    int 21h             

    ; 3. Write Length
    mov ah, 40h         
    mov bx, handle      
    lea dx, key+1       
    mov cx, 1           
    int 21h             
    jmp finish          

start_dec:              
    mov mode, 1         
    mov bl, stored_key_len 
    xor bh, bh          
    add bx, 5              
    mov ax, f_size      
    sub ax, bx          
    mov cx, ax          
    call process_file   

    ; Remove Trailer
    mov ax, f_size      
    mov bl, stored_key_len 
    xor bh, bh          
    add bx, 5              
    sub ax, bx          
    mov dx, ax          
    mov ah, 42h         
    mov al, 0           
    mov bx, handle      
    xor cx, cx          
    int 21h             

    mov ah, 40h         
    mov bx, handle      
    mov cx, 0           
    int 21h             
    jmp finish          

wrong_key:              
    inc tries           
    mov ah, 09h         
    lea dx, msg_wrong_key 
    int 21h             
    
    cmp tries, 3        
    jae limit_reached   
    jmp ask_key_only    

limit_reached:          
    mov ah, 09h         
    lea dx, msg_limit   
    int 21h             
    jmp final_exit      

finish:                 
    mov ah, 09h         
    lea dx, msg1        
    int 21h             

ask_again:              
    mov ah, 3eh         
    mov bx, handle      
    int 21h             
    mov handle, 0       

    mov ah, 09h         
    lea dx, msg_again   
    int 21h             

    mov ah, 01h         
    int 21h             
    
    cmp al, 'y'         
    je restart_jmp    
    cmp al, 'Y'         
    je restart_jmp    
    jmp final_exit

restart_jmp: jmp program_start

final_exit:             
    cmp handle, 0       
    je real_exit        
    mov ah, 3eh         
    mov bx, handle      
    int 21h             
real_exit:
    mov ah, 4ch         
    int 21h             
main endp               

process_file proc       
    jcxz done_p         
    mov key_ind, 0      
    push cx             
    mov ah, 42h         
    mov al, 0           
    mov bx, handle      
    xor cx, cx          
    xor dx, dx          
    int 21h             
    pop cx              
p_loop:                 
    push cx             
    mov ah, 3fh         
    mov bx, handle      
    lea dx, buffer      
    mov cx, 1           
    int 21h             
    
    mov bl, [key+1]     
    xor bh, bh          
    mov ax, key_ind     
    xor dx, dx          
    div bx              
    mov bx, dx          
    lea si, key+2       
    mov al, [si+bx]     

    cmp mode, 0         
    je do_encrypt
    sub buffer, al      
    jmp do_save
do_encrypt:
    add buffer, al      
do_save:
    
    inc key_ind         
    
    mov ah, 42h         
    mov al, 1           
    mov bx, handle      
    mov dx, -1          
    mov cx, -1          
    int 21h             
    
    mov ah, 40h         
    mov bx, handle      
    lea dx, buffer      
    mov cx, 1           
    int 21h             
    
    pop cx              
    loop p_loop         
done_p:
    ret                 
process_file endp

end main