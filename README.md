# VaultASM — x86 Assembly File Encryptor
 
A command-line file encryption and decryption tool written entirely in **8086 Assembly (MASM/TASM syntax)**. It uses a Vigenère-style XOR cipher with a user-supplied key, appends an authenticated footer to encrypted files, and enforces brute-force protection with a 3-attempt lockout.
 
---
 
## Features
 
- **XOR-based Vigenère cipher** — each byte of the file is XORed with a rotating key character, making the cipher key-length dependent and harder to brute-force than simple single-byte XOR
- **Magic signature authentication** — encrypted files are stamped with a 4-byte magic header (`KEYX`) in the footer so the program can automatically detect whether a file is encrypted or plaintext
- **Obfuscated key storage** — the encryption key is XORed with `0x55` before being written to the file footer, so it is never stored in plaintext
- **Brute-force lockout** — 3 consecutive wrong key attempts trigger an automatic exit
- **Auto mode detection** — no need to specify encrypt or decrypt; the program reads the file footer and decides automatically
- **Batch processing** — after each operation, prompts the user to process another file without restarting
- **Masked key input** — key is typed with `*` masking and supports backspace correction
- **In-place processing** — operates directly on the file without creating a separate output file
---
 
## How It Works
 
### Encryption
1. User provides a filename and a key (1–20 characters)
2. Program reads the file byte by byte, adding each byte to the corresponding key character (cyclically)
3. After processing, it appends a **footer** to the file:
   ```
   [KEYX magic] [obfuscated key bytes] [key length byte]
   ```
4. The key bytes are obfuscated by XORing each character with `0x55`
### Decryption
1. Program reads the last byte of the file to get the stored key length
2. Seeks back and reads the magic signature — if `KEYX` is not found, treats the file as plaintext and encrypts instead
3. Reads the obfuscated stored key and compares it against the user-entered key (after XOR with `0x55`)
4. If keys match, subtracts key bytes from file content to restore original data, then truncates the footer
5. If keys don't match, increments the attempt counter — 3 failures triggers lockout
### Footer Structure (appended to encrypted file)
```
+----------+------------------+-----------+
|  4 bytes |  1–20 bytes      |  1 byte   |
|  'KEYX'  |  XOR'd key data  | key_len   |
+----------+------------------+-----------+
```
 
---
 
## Usage
 
Assemble and run using DOSBox or any 8086-compatible environment:
 
```bash
# Assemble (TASM example)
tasm fileguard.asm
tlink fileguard.obj
 
# Or with MASM
masm fileguard.asm
link fileguard.obj
```
 
Run `fileguard.exe` and follow the prompts:
 
```
Enter a file: secret.txt
Enter a key: ********
Operation Success!
Would you like to process another file? (y/n):
```
 
Run the same command on an already-encrypted file to decrypt it — mode is detected automatically.
 
---
 
## Technical Details
 
| Property | Detail |
|---|---|
| Architecture | x86 (8086) |
| Syntax | MASM / TASM compatible |
| Cipher | Vigenère-style additive XOR |
| Key length | 1–20 characters |
| Max filename | 30 characters |
| File access | DOS INT 21h (read/write/seek) |
| Max wrong attempts | 3 before lockout |
 
---
 
## Limitations
 
- Designed for DOS/DOSBox environments using INT 21h system calls
- Operates on files up to 65535 bytes (16-bit file size register)
- In-place encryption means original file is overwritten — keep backups
- The cipher is educational and not cryptographically secure for sensitive data
---
 
## What I Learned
 
- Low-level file I/O using DOS interrupts (`INT 21h`)
- Manual string and memory manipulation without standard libraries
- Implementing a stateful cipher loop in pure assembly
- Designing a binary file format (footer structure) from scratch
- Managing registers carefully across a multi-stage program with no high-level abstractions
