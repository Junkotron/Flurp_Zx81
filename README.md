# "Flurp zx81" on an fpga lots of stuff borrowed from "Blackice MX ZX81"
# Now for use on the Olimex ice40 8k board.

Second release some cleanup done but some elephants still remain

Features so far of the "Flurp"

* 16k or 1k ZX81 running at 3.2MHz
* PAL/NTSC output
* mic/ear/line for playing and recording sound files
* PS/2 keyboard connector (works with most USB keyboards)
* A debug port for a logic analyzer
* Serial port can now fairly reliably quick load programs
* 5 volt in from mobile charger, USB or similar

"Flurp" PCB drawings in kicad all in 0.1" grid so "banana finger" is no excuse
anymore, all hole-mounted like in the old days. If you, like me, fiddled
together a Zeddy at twelve you should be able to do this. Actually it is 
easier since no nerve-wrecking 40 pinners need be pressed in their sockets.
Components as far as I know can still be obtained, caps, connectors,
resistors and a single diode for over-voltage from the cassette interface
(could be omitted for the brave at heart).

First PCB is "in the air" as of this writing.

Since there is so many ideas of the connectors I made them as simple
pin and hole headers so there is no on-board fittings for RCA-jacks, 3.5mm
keyboard or similar since the chance of you obtaining whatever I got hold
of would be near-zero, just dive into that junkbox you got and see what
pops up!
I assume anyone attempting this should know their way around old-timer
connectors or if you are younger, wikipedia and google for info
on antiques :)

ZX81 currently only with 1k or 16k config, one major improvement with the
Olimex board is its 512k SRAM which we can use as we like.
Most other boards have SDRAM and although this probably also can
be made working I leave it as an excercise to the experts.
Currently only 16k is used. Plans to move the ROM here as well, this
currently resides in the internal FPGA memory.

As when mentioning the ROM I sucessfully replaced the original ROM with
the infamous "ASZMIC" rom image and got the example from the manual
working (see aszmic.sh in speedloader/) 

There is also an example of where the virtual keyboard produces a really
long 10 REM ... line suitable for storing machine code, in the old days
this would make your thumb go numb since this old piece of antique did not
have key repeat..

A composite output, there is an unfortunate "panache" with a wobble
on the first text line, dont know if this is due to the almost-PAL nature
of the ZX81 or something introduced later on. I tried a modulator (VHF) 
of some cheap no-brand type which would actually feed an older flatscreen
I got. Seems the really new flat screens cannot do PAL/NTSC anymore.
Not tried on a real fat-TV or monitor yet.

An "ear" input, changes from Sinclair original is some pulldown I seemed
to need on the FPGA side and some cowardly added zener 3.3 volts since
the FPGA is not 5v tolerant like the original ULA.

A "line" output, this is to be fed into a line input of some kind of PC 
soundblaster, I used the "aplay/arecord" utilities on Linux to act as the
tape recorder, it actually worked more or less out of the box.
I also added a modified bandbass filter for the line level that aims
as "doing the same thing" as the original "mic" circuitry but with a higher
level.

A PS/2 keyboard input with some resistors again to adapt to the
3.3 volt logic. It also works on most USB keyboards I tried, forcing them
into legacy PS/2 mode with some pullups.
If you take the usb connector, the wires in the schematic should align with
how the physical usb port is layed out so you can start with the plus which
use to be red and then work your way into whatever connector you have available
You could also get a PS/2 keyboard on ebay though this more obvious option
has not been tested.

The 34-pole connector for the FPGA module (Olimex) note that the notch in
the FPGA boards connector should face the nearest rim of the pcb, there is a 
"Notch!" silk screen marker. I'm not in any way a professional cad:er so
I may have broken some standard ways of working concerning the connectors.
Possibly you will use a female 0.1" headers with no notch. I found that
adding a small dot of hot glue, let it cool off some and then press the
module on will "mold" a notch without clogging the fpga board with glue.
This "notch" has been quite useful for avoiding gray smoke.

A "mic" output, this is made according to the originals but has as of yet
not worked. I added a 5 volt feed in case someone wants to try to make some
analog adaptions to it, I tried to amplify the signal with a 741 but to
no avail. Have not tested with a "real" tape recorder will do that when I
get a hold of one and some tape.

Some games require you to have only 1k so there is a connector that will
downgrade the Flurp to 1k after a reset, otherwise poking RAMTOP should
work for most such games.

Another connector will pull the "pin 22" on the "ULA" high which should
give you NTSC format, this is untested so far. In the old days most
american TV-sets would eat the PAL signal just as well.

Loading old games, I have been successful in using the "zx81putil" for
converting the p-file games available into wav files and then playing them
via the line-out of my PC sound blaster into the "ear" of the Flurp

.. Below here is some cool stuff that is not really necessary
.. these connectors can be omitted

A connector for a six-pin serial module which is popular with Arduinos
and similar. Now the speedloader is working and also you can "remote
type" on the ZX81 keyboard.

The olimex 32u4 or similar is used for programming the SPI flash of the
FPGA, we sometimes need to reset the FPGA, this can be done with the
reset button on the olimex ice40 board itself or with for instance
> sudo iceprogduino -t
Which reads the flash ID (but also does a full reset much faster than a full
 reprogram)

Speedloader can now both produce load files and fast load them
Check out "speedloader.txt" for more info

A way to run the ZX keyboard from this serial port is now implemented
the speeloader/keysend.c can be used to primitively execute commands
on the flurp, such as 'RUN' 'LOAD ""' 'NEW' etc.

A 10-pin connector for a Logic Probe, dirt cheap and really useful if you
want to dive into the FPGA firmware.

Thats all for now!

