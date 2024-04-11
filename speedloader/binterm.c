



#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h> 
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <assert.h>
#include <sys/select.h>

static int dbg=0;


int main(int argc, char *argv[])
{
  if (argc!=2)
    {
      fprintf(stderr, "Usage: binterm <device>\n");
      exit(1);
    }

  const char* dev=argv[1];
  

  int serial = open(dev, O_RDWR | O_NOCTTY | O_SYNC);
  unsigned byte;
  fd_set poller, w, e;

  char kbuf[100];
  int kpek=0;
  
  struct timeval tv;
  
  while (1)
    {
      while (1)
	{
	  FD_ZERO(&poller);
	  FD_ZERO(&w);
	  FD_ZERO(&e);
	  FD_SET(0, &poller);
	  FD_SET(serial, &poller);
	  
	  tv.tv_sec=1;
	  tv.tv_usec=0;
	  
	  int n=select(serial+1, &poller, &w, &e, &tv);
	  if (n!=0) break;
	}

      if (dbg) printf("out of select loop\n");
      
      if (FD_ISSET(0, &poller))
	{
	  int n;
	  if (dbg) printf("Waiting for keyboard\n");
	  if (dbg) fflush(stdout);

	  char ch;
	  read(0, &ch, 1);
	  if (dbg) printf("got raw char: %c( %d)\n", ch, ch);
	  
	  if ( (ch>='0' && ch<='9') || (ch>='a' && ch<='f') || (ch>='A' && ch<='F') )
	    {
	      // got a hex
	      if (kpek == 0)
		{
		  kbuf[kpek++]=ch;
		}
	      else
		{
		  kbuf[kpek++]=ch;
		  kbuf[kpek]='\0';
		  kpek=0;
		  sscanf(kbuf, "%2x", &byte);
		  
		  if (dbg) printf("scanned a byte\n");
		  if (dbg) printf("Sending: %.2x (%c)\n", byte, byte);
		  write(serial, &byte, 1);
		}
	    }
	}
      
      if (FD_ISSET(serial, &poller))
	{
	  if (dbg) printf("Waiting for serial\n");
	  if (dbg) fflush(stdout);
	  read(serial, &byte, 1);
	  //printf("Got: %.2x (%c)\n", byte, byte);
	  printf("%.2x", byte);
	  fflush(stdout);
	}

    }

}  
