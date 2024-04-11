
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

  // TODO: Map these to command line args
  const char* dev="/dev/ttyUSB0";

  const int ram_size = 16384;

  int serial = open (dev, O_RDWR | O_NOCTTY | O_SYNC);

  send_wait_ok("h", serial, 0);

  int i;

  char wbuff[ram_size];
  memset(wbuff, 0, ram_size);
  writemem(wbuff, ram_size, serial);

  send_wait_ok("g", serial, 0);
  
  send_wait_ok("a", serial, 0);

  close(serial);
}
