
#include "util.h"

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h> 
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <assert.h>


int main(int argc, char *argv[])
{

  if (argc!=3)
    {
      fprintf(stderr, "Usage: %s <ser dev><addr>\n", argv[0]);
      exit(1);
    }
  
  const char* dev=argv[1];

  const int ram_size = 16384;

  char addrs[10];
  int addr;
  
  sscanf(argv[2], "%x", &addr);

  sprintf(addrs, "%.4x", addr);
  
  printf("padded addr: %s\n", addrs);
  
  // End of argc/argv mongering
  
  // Compile for this specific break point
  char syscmdbuff[1024];
  sprintf(syscmdbuff, "./do_break.sh zx81loader %s", addrs);
  system(syscmdbuff);
  
  char cmdbuff[1024];
  char chars[100];
    
  char xreftext[4096];
  int xreflen = load_mem_filelen("../asm/break.xref", xreftext, 4096);

  // Below must exist in assembler program
  int xref_RWFLAG = xref_lookup("RWFLAG", xreftext);
  int xref_REGISTERS = xref_lookup("REGISTERS", xreftext);
  int xref_REGEND = xref_lookup("REGEND", xreftext);
  int xref_SEMA = xref_lookup("SEMA", xreftext);
  int reglen=xref_REGEND - xref_REGISTERS;

  int serial = open(dev, O_RDWR | O_NOCTTY | O_SYNC);

  //  send_wait_ok("h", serial, 0);
  grab_bus(serial);

  // Load up assembler in shadow rom
  load_asm("../asm/break.bin", "../asm/break.xref", serial, 0);

  release_bus(serial);
  
  // sprintf(cmdbuff, "b 1 %s.", addrs);
  // send_wait_ok(cmdbuff, serial, 0);
  break_addr(serial, addr);
  break_flag(serial, 1);
  
  printf("Press <enter> when zx screen goes blank\n");
  getchar();
  
  grab_bus(serial);
  //send_wait_ok("h", serial, 0);

  unsigned char regbuff[1024];
  /*  sprintf(chars, "r %.5x %.3x.", 0x4000 + xref_REGISTERS, reglen);
      do_read(chars, regbuff, reglen, serial, 0);*/
  readmemshort(regbuff, 0x4000+xref_REGISTERS, reglen, serial, 0);
  save_mem("breakregs.bin", regbuff, reglen);

  // Dump sysvars
  /*
  sprintf(chars, "r 00000 100.");
  do_read(chars, regbuff, 256, serial, 0);
  */
  readmemshort(regbuff, 0, 256, serial, 0);
  save_mem("sysvars.bin", regbuff, 256);
  
  // Semaphore address
  /*sprintf(chars, "w %.5x 01.", 0x4000 + xref_SEMA);
    send_wait_ok(chars, serial, 1);*/
  // Semaphore address
  char ch=1;
  writememshort(&ch, 0x4000+xref_SEMA, 1, serial, 0);
  
  //send_wait_ok("g", serial, 0);
  release_bus(serial);

  /*
  sprintf(cmdbuff, "b 0 %s.", addrs);
  send_wait_ok(cmdbuff, serial, 0);
  */
  break_flag(serial, 0);

  close(serial);
}
