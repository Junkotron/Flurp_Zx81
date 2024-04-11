#ifndef __UTIL_H
#define __UTIL_H


unsigned char shadow0_set(int bit);
unsigned char shadow0_reset(int bit);

void mk_msg(unsigned char* str,
	    unsigned char cmd,
	    unsigned char reg,
	    unsigned char len,
	    unsigned char* data);

void mk_msg1(unsigned char* str,
	     unsigned char cmd,
	     unsigned char reg,
	     unsigned char data);

void mk_msg0(unsigned char* str,
	     unsigned char cmd,
	     unsigned char reg,
	     unsigned char len);

void grab_bus(int serial);
void release_bus(int serial);
void break_addr(int serial, unsigned addr);
void break_flag(int serial, unsigned flag);


void send(const unsigned char* str, int len, int serial, int silent);
void read_wrap(int serial, unsigned char* str, int len);
void wait_ok(int serial, int silent);
void send_wait_ok(const unsigned char* str, int len, int serial, int silent);
int save_mem(const char* fname, const unsigned char* buff, int nbytes);
int load_mem(const char* fname, unsigned char* buff, int nbytes);
int load_mem_filelen(const char* fname, unsigned char* buff, int maxbytes);
int ishex(char ch);
void do_read(unsigned char* cbuff, int len, unsigned char* rbuff, int n, int serial, int silent);
void readmem(unsigned char* rbuff, int nbytes, int serial);
void readmemshort(unsigned char* rbuff, int offset, int nbytes, int serial, int silent);
unsigned xref_lookup(const char* text, const char* haystack);
void writememshort(const unsigned char *wbuff, int offset, int nbytes, int serial, int silent);
void writemem(const unsigned char* wbuff, int nbytes, int serial);

void keytype(int mod, char ch, int serial);

int load_asm(const unsigned char* binfile, const char* xref, int serial, int silent);

#endif
