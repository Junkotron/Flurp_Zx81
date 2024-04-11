#!/bin/sh

# This works if directly from reset otherwise make sure it is _not_
# in edit mode :-)

# Now we enter edit mode...
./keysend "_E"

./keysend "_ FILE^"
./keysend " ORG _Z4400^"
./keysend "START LD HL_.0^"
./keysend " LD DE_.0^"
./keysend " LD B_.10^"
./keysend "LOOP INC DE^"
./keysend " ADD HL_.DE^"
./keysend "LOOPEND DJNZ LOOP^"
./keysend " RST 0^"
./keysend "_ ^"

./keysend "_ REGFILE^"
./keysend "IN CASE U FORGOT _Z_J_O^"
./keysend " _X PC  HL  HL_B BC_B DE_B AF_B^"
./keysend " _X AF  BC  DE  IX  IY  SP^"
./keysend "_ ^"


# debug mode...
./keysend "_9"
./keysend "A _ FILE 1^"

./keysend "_T"
./keysend "O"

./keysend "_9"
./keysend "D _Z4400 14^"


./keysend "_9"
./keysend "J _Z4400"

