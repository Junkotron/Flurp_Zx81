#!/bin/sh

set -e

iverilog -o cmdline ../src/sys/cmdline.v cmdline_test.v 
./cmdline  < finito.txt 

# A cmdline.vcd file should now have been produced, use gtkwave or..

# svcd from https://github.com/MuratovAS/simpleVCD/blob/main/README.md

# Use -t 1 or some value like that if svcd ends up in infinity loop
gcc -o svcd svcd.c
./svcd cmdline.vcd
