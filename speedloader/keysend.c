
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

  if (argc!=2)
    {
      fprintf(stderr, "Usage: %s <string>\n", argv[0]);
      fprintf(stderr, "Use '_' for zx81 shift and '^' for newline\n");
      fprintf(stderr, "Also note that comma is '_.'\n");
      fprintf(stderr, "Hangup reset/release all is '~'\n");
      fprintf(stderr, "Refer to zx81 keyboard layout\n");
      exit(1);
    }
  
  // TODO: Map this to command line args
  const char* dev="/dev/ttyUSB0";

  char* msg = argv[1];
  
  int serial = open(dev, O_RDWR | O_NOCTTY | O_SYNC);

  for (int i=0;i<strlen(msg);i++)
    {
      if (msg[i]=='_')
	{
	  keytype(1, msg[i+1], serial);
	  i++;
	}
      else
	{
	  keytype(0, msg[i], serial);
	}
    }

  close(serial);
}
