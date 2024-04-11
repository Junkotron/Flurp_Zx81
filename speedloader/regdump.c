
#include <stdio.h>

// TODO could use xref file for this ...
void regdump(const unsigned char* r)
{
  // TODO: PC..
  
  printf("tstates PC   AF   BC   DE   HL   SP  \n");
  printf("        IX   IY   AF'  BC'  DE'  HL'\n");

  printf("        XXXX %.2x%.2x %.2x%.2x %.2x%.2x %.2x%.2x %.2x%.2x\n",
	 r[3],r[2], r[5],r[4], r[7],r[6], r[9],r[8], r[1],r[0]);
  printf("        %.2x%.2x %.2x%.2x %.2x%.2x %.2x%.2x %.2x%.2x %.2x%.2x\n",
	 r[19],r[18], r[21],r[20], r[11],r[10], r[13],r[12], r[15],r[14], r[17],r[16]);
}


int main()
{
  // 22 BYTES READ

  unsigned char regbuff[1024];
  fread(regbuff, 22, sizeof(char), stdin);

  regdump(regbuff);
  
}
