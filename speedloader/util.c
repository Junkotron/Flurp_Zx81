  
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h> 
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <assert.h>

#include "util.h"

static int dbg=0;

// Just output the traffic on serial
static int dbg_serial=0;

static int dbg_shadow=0;

// Shadow of write register 0 in fpga code,
// these values reside in "serperiph.v" for now
static unsigned char shadow0 = 1; // xxxxx001 

unsigned char shadow0_set(int bit)
{
  unsigned char mask=(1<<bit);
  if (dbg_shadow)
    {
      printf("shadow0, set, bit=%d\n", bit);
      printf("shadow0 before set: %.2x\n", shadow0);
      printf("mask : %.2x\n", mask);
    }
  shadow0 = ( shadow0 | mask);
  if (dbg_shadow) printf("shadow0 after set: %.2x\n", shadow0);
  return shadow0;
}

unsigned char shadow0_reset(int bit)
{
  unsigned char mask = (1<<bit)^0xff;
  if (dbg_shadow)
    {
      printf("shadow0, reset, bit=%d\n", bit);
      printf("shadow0 before reset: %.2x\n", shadow0);
      printf("mask : %.2x\n", mask);
    }
  shadow0 = ( shadow0 & mask );
  if (dbg_shadow) printf("shadow0 after reset: %.2x\n", shadow0);
  return shadow0;
}

void grab_bus(int serial)
{
  unsigned char chars[100];
  // Send busrq low
  mk_msg1(chars, 0x02, 0x00, shadow0_reset(0));
  send(chars, 4, serial, !dbg);

  unsigned char rpy;
  // wait for busak (probably it is faster than the serial :)
  while (1)
    {
      mk_msg0(chars, 0x01, 0x00, 0x01);
      do_read(chars, 3, &rpy, 1, serial, !dbg);
      if ((rpy&80) == 0) break;
    }
  
  mk_msg1(chars, 0x02, 0x00, shadow0_set(1));
  send_wait_ok(chars, 4, serial, !dbg);
}

void release_bus(int serial)
{
  unsigned char chars[100];

  mk_msg1(chars, 0x02, 0x00, shadow0_reset(1));
  send(chars, 4, serial, !dbg);

  mk_msg1(chars, 0x02, 0x00, shadow0_set(0));
  send(chars, 4, serial, !dbg);
}

void break_addr(int serial, unsigned addr)
{
  unsigned char chars[100];
  // Setting the break_addr 
  mk_msg1(chars, 0x02, 0x06, addr/256);
  send(chars, 4, serial, !dbg);
  mk_msg1(chars, 0x02, 0x07, addr%256);
  send(chars, 4, serial, !dbg);
}

void break_flag(int serial, unsigned flag)
{
  unsigned char chars[100];
  mk_msg1(chars, 0x02, 0x00, shadow0_set(2));
  send(chars, 4, serial, !dbg);  
}

void mk_msg(unsigned char* str,
	    unsigned char cmd,
	    unsigned char reg,
	    unsigned char len,
	    unsigned char* data)
{
  str[0] = cmd;
  str[1] = reg;
  str[2] = len;
  for (int i=0;i<len;i++)
    {
      str[i+3] = data[i];
    }
}

void mk_msg1(unsigned char* str,
	    unsigned char cmd,
	    unsigned char reg,
	    unsigned char data)
{
  mk_msg(str, cmd, reg, 0x01, &data);
}

void mk_msg0(unsigned char* str,
	     unsigned char cmd,
	     unsigned char reg,
	     unsigned char len)
{
  str[0] = cmd;
  str[1] = reg;
  str[2] = len;
}


void send(const unsigned char* str, int len, int serial, int silent)
{
  if (len==-1)
    {
      fprintf(stderr, "re-write this call...\n");
      exit(1);
    }

  if (!silent ||dbg_serial)
    {
      printf("Sent: <<");
      for (int i=0;i<len;i++)
	printf("%.2x", str[i]);
      printf(">>\n");
      fflush(stdout);
    }
      
  write(serial, str, len);

}

void read_wrap(int serial, unsigned char* str, int len)
{
  read(serial, str, len);

  for (int i=0;i<len;i++)
    {
      if (dbg_serial) printf("Got %.2x\n", str[i]);
    }
}

// No "real" calls to serial read/write after this point to
// keep traffic logging consitent

void wait_ok(int serial, int silent)
{
  unsigned char ch;

  send("\x02\x05\x01\x55", 4, serial, silent);
  send("\x01\x02\x01", 3, serial, silent);

  while (1)
    {
      read_wrap(serial, &ch, 1);
      if (ch=='\x56') break;
      if (dbg) printf("got... %.2x\n", ch);
    }

  if (!silent)
    {
      printf("Got %.2x back\n", ch);
      fflush(stdout);
    }
}

void send_wait_ok(const unsigned char* str, int len, int serial, int silent)
{
  send(str, len, serial, silent);

  wait_ok(serial, silent);
}

int save_mem(const char* fname, const unsigned char* buff, int nbytes)
{
  FILE* r = fopen(fname, "wb");
  if (r==NULL)
    {
      fprintf(stderr, "Failed to open file: ``%s''\n", fname);
      exit(1);
    }

  int nmemb=fwrite(buff, sizeof(char), nbytes, r);

  fclose(r);
  return nmemb;
}

int load_mem(const char* fname, unsigned char* buff, int nbytes)
{
  FILE* r = fopen(fname, "rb");
  if (r==NULL)
    {
      fprintf(stderr, "Failed to open file: ``%s''\n", fname);
      exit(1);
    }

  int nmemb=fread(buff, sizeof(char), nbytes, r);
  fclose(r);
  return nmemb;
}

int load_mem_filelen(const char* fname, unsigned char* buff, int maxbytes)
{
  FILE* r = fopen(fname, "rb");
  if (r==NULL)
    {
      fprintf(stderr, "Failed to open file: ``%s''\n", fname);
      exit(1);
    }

  int nmemb=fread(buff, sizeof(char), maxbytes, r);

  assert(feof(r));
  
  fclose(r);
  return nmemb;
}

int ishex(char ch)
{
  if (ch>='0' && ch<='9') return 1;
  if (ch>='A' && ch<='F') return 1;
  return 0;
}

// cbuff contains pre-fabricated msg
//
void do_read(unsigned char* cbuff, int len, unsigned char* rbuff, int n, int serial, int silent)
{
  send(cbuff, len, serial, silent);
  
  int j;
  for (j=0;j<n;j++)
    {
      unsigned char ch;
      read_wrap(serial, &ch, 1);
      if (!silent) printf("Read: %.2x\n", ch);
      rbuff[j]=ch;
    }
  wait_ok(serial, !dbg);
}

void readmemshort(unsigned char *rbuff, int offset, int nbytes, int serial, int silent)
{
  if (nbytes > 256)
    {
      fprintf(stderr, "readmemshort: takes max 256 bytes\n");
      exit(1);
    }

  unsigned char chars[100];
  send("\x02\x01\x01\x00", 4, serial, silent);
  mk_msg1(chars, 0x02, 0x02, offset/256);
  send(chars, 4, serial, silent);
  mk_msg1(chars, 0x02, 0x03, offset%256);
  send(chars, 4, serial, silent);

  // nbytes=0 means 256 :-)
  mk_msg0(chars, 0x01, 0x01, nbytes);
  do_read(chars, 3, rbuff , nbytes, serial, silent);
      
}

void readmem(unsigned char* rbuff, int nbytes, int serial)
{
  int i;
  for (i=0;i<nbytes;i+=256)
    {
      readmemshort(rbuff+i, i, 256,serial, !dbg);
    }
}


// Xref is of type:
//       NAME   xdec  xhex     xline
//
unsigned xref_lookup(const char* text, const char* haystack)
{
  int retval;
  const char* needle = strstr(haystack, text);
  assert (needle != NULL);
  
  // Move needle to first space
  while (1)
    {
      assert (*needle != '\0');
      if (*needle == ' ') break;
      needle++;
    }
  
  // Now we scan the decimal value
  assert(1==sscanf(needle, "%d", &retval));

  if (dbg)
    {
      printf("%s: %.4x\n", text, retval);
    }
  
  return retval;
}

void writememshort(const unsigned char *wbuff, int offset, int nbytes, int serial, int silent)
{
  if (nbytes > 256)
    {
      fprintf(stderr, "readmemshort: takes max 256 bytes\n");
      exit(1);
    }

  unsigned char chars[100];
  send("\x02\x01\x01\x00", 4, serial, silent);
  mk_msg1(chars, 0x02, 0x02, offset/256);
  send(chars, 4, serial, silent);
  mk_msg1(chars, 0x02, 0x03, offset%256);
  send(chars, 4, serial, silent);

  // nbytes=0 means 256 :-)
  mk_msg0(chars, 0x02, 0x04, nbytes);
  send(chars, 3, serial, silent);

  for (int i=0;i<nbytes;i++)
    {
      char ch=wbuff[i];
      send(&ch, 1, serial, silent);
    }
      
}


void writemem(const unsigned char* wbuff, int nbytes, int serial)
{
  int i;
  unsigned char cmdbuff[100];
  for (i=0;i<nbytes;i+=256)
    {
      writememshort(wbuff+i, i, 256, serial, !dbg);
    }
  wait_ok(serial, !dbg);
}



int load_asm(const unsigned char* asmbin, const char* xref, int serial, int silent)
{
  unsigned char asmline[4096];

  int asmlen = load_mem_filelen(asmbin, asmline, 4096);

  int asmoffset = strlen("Z80ASM..");

  // load_mem_filelen gives the raw file len, we deduct header and two org bytes
  asmlen -= (asmoffset + 2);
  
  int i;

  // Get the org address from the assembler binary...
  int org = asmline[8] + asmline[9]*256;

  if (dbg) printf("Found Z80 org at: %.4x\n", org);
  
  // Add the linear sram offset since rom is at low we dont expect to go above 64k
  org += 0x4000;

  unsigned char chars[100];
  send("\x02\x01\x01\x00", 4, serial, silent);
  mk_msg1(chars, 0x02, 0x02, org/256);
  send(chars, 4, serial, silent);
  mk_msg1(chars, 0x02, 0x03, org%256);
  send(chars, 4, serial, silent);

  char xreftext[4096];

  int xreflen = load_mem_filelen(xref, xreftext, 4096);

  const unsigned char* binpek = &asmline[asmoffset+2];
  int xref_WATERMARK = xref_lookup("WATERMARK", xreftext);
  int xref_PIVOT = xref_lookup("PIVOT", xreftext);
  
  // Check for watermark
  const char wmark[] = { 0x1e, 0xe7, 0xba, 0xbe };
  if (0!=strncmp(&binpek[(xref_WATERMARK - xref_PIVOT)],
		 wmark,
		 4))
    {
      fprintf(stderr, "*** WARNING, Watermark not found, this might not work       ***\n");
      fprintf(stderr, "*** Check the ../asm file, you have been warned, continuing ***\n");
      sleep(3);
    }

  mk_msg0(chars, 0x02, 0x04, asmlen);
  send(chars, 3, serial, silent);
  
  assert (asmlen<=256);
  
  for (i=0;i<asmlen;i++)
    {
      send(&binpek[i], 1, serial, silent);
    }

  // Just a quick checkin after sending a large chunk...
  wait_ok(serial, silent);

  return asmlen;
}
// nums
const int num2scan[] = {
  40, // 0
  30, // 1
  31, // 2
  32, // 3
  33, // 4
  34, // 5
  44, // 6
  43, // 7
  42, // 8
  41  // 9
};

// letters A-Z
const int lett2scan[] = {
  10, // A
  74, // B
  03, // C
  12, // D
  22, // E
  13, // F
  14, // G
  64, // H
  52, // I
  63, // J
  62, // K
  61, // L
  72, // M
  73, // N
  51, // O
  50, // P
  20, // Q
  23, // R
  11, // S
  24, // T
  53, // U
  04, // V
  21, // W
  02, // X
  54, // Y
  01  // Z
};

const int enter_scan=60;
const int space_scan=70;
const int dot_scan=71;
const int shift_scan=00;

const int reset_scan=77;

void send_scan(int press, int code, int serial)
{
  unsigned char sbuf[100];

  // TODO this conversion is kind of silly
  int col = code%10;
  int row = code/10;

  unsigned char strobe_lo = (press << 6) | (row << 3) | col;
  unsigned char strobe_hi = (1<<7) | strobe_lo;
  
  mk_msg1(sbuf, 0x02, 0x08, strobe_hi);
  send_wait_ok(sbuf, 4, serial, 1);

  mk_msg1(sbuf, 0x02, 0x08, strobe_lo);
  send_wait_ok(sbuf, 4, serial, 1);

  // Wait uncertain time for zeddy to react
  // TODO: this will need some increase in case writing long essays
  // to the ZX keyboard since long lines increase reaction time
  // an even better way would be someway to know that the zeddy has
  // reacted.
  usleep(200000);
}

void keytype(int mod, char ch, int serial)
{
  if (mod==-1)
    {
      // Reset all to high
      send_scan(1,77,serial);
      return;
    }

  // Shift?
  if (mod==1)
    {
      send_scan(0, shift_scan, serial);
    }
    
  switch(ch)
    {
    case '~':
      {
	send_scan(1, reset_scan, serial);
	break;
      }
    case '^':
      {
	send_scan(0, enter_scan, serial);
	send_scan(1, enter_scan, serial);
	break;
      }
    case ' ':
      {
	send_scan(0, space_scan, serial);
	send_scan(1, space_scan, serial);
	break;
      }
    case '.':
      {
	send_scan(0, dot_scan, serial);
	send_scan(1, dot_scan, serial);
	break;
      }
    default:
      {
	if (ch>='A' && ch<='Z')
	  {
	    send_scan(0, lett2scan[ch-'A'], serial);
	    send_scan(1, lett2scan[ch-'A'], serial);
	  }
	if (ch>='0' && ch<='9')
	  {
	    send_scan(0, num2scan[ch-'0'], serial);
	    send_scan(1, num2scan[ch-'0'], serial);
	  }
	break;
      }
    }

  // Shift - lift?
  if (mod==1)
    {
      send_scan(1, shift_scan, serial);
    }
    
}

