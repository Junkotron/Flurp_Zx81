
#include "util.h"

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h> 
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <assert.h>

static int dbg=0;


static void usage()
{
  fprintf(stderr, "Usage: speedloader <ser device> <flag> <name>\n");
  fprintf(stderr, "c - create speedload file\n");
  fprintf(stderr, "l - load speedload file\n");
  exit(1);
}

int main(int argc, char *argv[])
{

  // memory dump file
  char fname[1024];

  // reg dump file
  char regfname[1024];

  const int ram_size = 16384;

  const char* asmbin="../asm/zx81loader.bin";

  const char* xref="../asm/zx81loader.xref";

  int ram_write = 0;

  if (argc!=4)
    {
      usage();
    }

  switch (argv[2][0])
    {
    case 'c':
      {
	  break;
      }
    case 'l':
      {
	  ram_write = 1;
	  break;
      }
    default:
      {
	usage();
      }
    }

  const char* dev=argv[1];

  sprintf(fname, "%s_memdump16k.bin", argv[3]);
  sprintf(regfname, "%s_regs.bin", argv[3]);

  // *** no argc/argv mongering beyond this point!!! ***
  
  char xreftext[4096];

  int xreflen = load_mem_filelen(xref, xreftext, 4096);

  // Below must exist in assembler program
  int xref_PIVOT = xref_lookup("PIVOT", xreftext);
  int xref_SEMA = xref_lookup("SEMA", xreftext);
  int xref_REGISTERS = xref_lookup("REGISTERS", xreftext);
  int xref_REGEND = xref_lookup("REGEND", xreftext);
  int xref_RWFLAG = xref_lookup("RWFLAG", xreftext);
  
  char chars[1024];
  
  int serial = open (dev, O_RDWR | O_NOCTTY | O_SYNC);
  if(-1 == serial)
    {
      fprintf(stderr, "Error opening serial port");
      exit(1);
    }

  struct termios serio;
  cfmakeraw(&serio);
  serio.c_cflag = B115200;
  if(0 != tcsetattr(serial, TCSANOW, &serio))
    {
      fprintf(stderr, "Error configuring serial port");
      exit(1);
    }

  
  // Activate ram injection
  grab_bus(serial);

  int asmlen=load_asm(asmbin, xref, serial, !dbg);

  // test readback:
  unsigned char binback[1000];
  unsigned char binfromfile[1000];

  load_mem_filelen(asmbin, binfromfile, 4096);
  
  readmemshort(binback, 0x4000 + xref_PIVOT, asmlen, serial, !dbg);
  for (int i=0;i<asmlen;i++)
    {
      if ((binfromfile+10)[i] != binback[i])
	{
	  fprintf(stderr, "Error, readback of asm util failed!\n");
	  fprintf(stderr, "index=%d, value=%.2x, should have been: %.2x\n",
		  i, binback[i], (binfromfile+10)[i]);
	  exit(1);
	}
    }
  
  // disable ram inject and
  // return bus back to cpu (busrq_n high)
  release_bus(serial);
  
  break_addr(serial, xref_PIVOT);

  if (ram_write)
    {

      keytype(-1, 0, serial); // release all keys

      keytype(1, '1', serial); // Discard line junk
      keytype(0, '^', serial);

      sleep(1);

      break_flag(serial, 1);
      
      keytype(0, 'A', serial); // NEW <newline>
      sleep(1);
      keytype(0, '^', serial);
      printf("Speedloading file...");
      fflush(stdout);
      
      sleep(2);
    }
  else
    {
      printf("Starting load on machine..\n");
      keytype(-1, 0, serial); // release all keys

      keytype(1, ' ', serial); // Break any ongoing loading...
      
      keytype(1, '1', serial); // Discard line junk
      keytype(0, '^', serial);

      sleep(1);
      
      keytype(0, 'J', serial); // LOAD ""<newline>
      keytype(1, 'P', serial);
      keytype(1, 'P', serial);
      keytype(0, '^', serial);

      break_flag(serial, 1);
    }
  
  if (!ram_write)
    {
      printf("Please load program the normal way via cassette or wav file then press <enter> here, when program has loaded...\n");
      fflush(stdin);
      getchar();
    }

  grab_bus(serial);

  if (ram_write)
    {
      char wbuff[ram_size];
      assert(ram_size == load_mem(fname, wbuff, ram_size));
      writemem(wbuff, ram_size, serial);
    }
  else
    {
      printf("Reading out the RAM...\n");
      // Read out the 16 k mem
      char rbuff[ram_size];
      readmem(rbuff, ram_size, serial);  
      assert(ram_size==save_mem(fname, rbuff, ram_size));
    }

  
  // Current length of register dump
  int reglen=xref_REGEND - xref_REGISTERS;

  if (ram_write)
    {
      char ch=1;
      // Set the byte at "RWFLAG" to one
      writememshort(&ch, 0x4000+xref_RWFLAG, 1, serial, !dbg);

      // Read in regs-file 
      unsigned char regbuff[1000];
      load_mem(regfname, regbuff, reglen);

      // Send register data to mem ready for loading
      writememshort(&ch, 0x4000+xref_REGISTERS, reglen, serial, !dbg);
      
    }
  else
    {
      // Dump regs
      unsigned char regbuff[1024];

      printf("Dumping registers...\n");
      readmemshort(regbuff, 0x4000+xref_REGISTERS, reglen, serial, !dbg);
      save_mem(regfname, regbuff, reglen);
    }
  
  // Semaphore address
  char ch=1;
  writememshort(&ch, 0x4000+xref_SEMA, 1, serial, !dbg);

  // De activate break
  break_flag(serial, 0);

  release_bus(serial);
  wait_ok(serial, !dbg);
  
  close(serial);
}
