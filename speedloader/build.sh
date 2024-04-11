#!/bin/sh


./do_asm.sh zx81loader 207

gcc -o speedloader util.c speedloader.c

gcc -o regdump regdump.c

gcc -o binterm binterm.c

gcc -o break break.c util.c

gcc -o keysend keysend.c util.c
