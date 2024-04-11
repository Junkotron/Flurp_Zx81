#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <errno.h>


#define MAX_SAMPLE 2048
#define MAX_CHANNEL 400
#define MAX_NAME 128
#define COUNT(A) (sizeof(A)/sizeof((A)[0]))
#define MAX(A,B) (A > B ? A : B)
#define VAL(A) # A
#define TXT(A) VAL(A)

int getSize(unsigned* const rows, unsigned* const cols);
int keyEvents();
int getc_noecho();

typedef struct
{
	unsigned width;
	unsigned round;
	unsigned colsize;
	unsigned timescalestep;
	unsigned zoom;
	unsigned beginsmpl;
	unsigned endsmpl;
	unsigned beginch;
	unsigned endch;
	unsigned tui;
	char* scope;
	char file[MAX_NAME];
	FILE* fin;
	FILE* fout;
} Parameters;

typedef struct
{
	unsigned      size;
	unsigned      scope;
	char     name[MAX_NAME];
	char     type[MAX_SAMPLE];//'U','Z','X','\0'=Data
	unsigned val [MAX_SAMPLE];
} Channel;

typedef struct
{
	long long unsigned timestamps[MAX_SAMPLE];
	Channel ch[MAX_CHANNEL];
	unsigned nb, nb_scopes;
	char scopes[32][32];//[0]=root
	char date[32], version[32], scale[32]; //file info
	//parsing related values
	unsigned cur_scopes;
} Parser;

void showHelp(char* arg0, Parameters* p)
{
	fprintf(stderr, "Usage: %s [OPTION] [FILE]...:\n"
			" -h:			: this help screen\n"
			" -w=%i			: width of each sample  (1,2,...)\n"
			" -r=%i			: rounded wave (0:none,1:pipe,2:slash)\n"
			" -t=%i			: time scale step (0:none,1,10,...)\n"
			" -b=%i			: Begin sample (0:begin,1,...)\n"
			" -e=%i			: End sample (0:end,1,...)\n"
			" -i=%i			: TUI (0:off,1:on)\n"
			" -s=a,b,c		: comma separated scope(s) to display\n"
			, arg0, p->width, p->round, p->timescalestep, p->beginsmpl, p->endsmpl, p->tui);
}

void parseArgs(int argc, char** argv, Parameters* params)
{
	int i;
	for (i = 1; i < argc; i++) //parse "-" arguments
	{
		if (argv[i][0] != '-')
		{
			for (unsigned f = 0; f < strlen(argv[i]); f++)
				params->file[f] = argv[i][f];
			continue;
		}
		switch (argv[i][1])
		{
		case 'o':
			params->fout = fopen(argv[i] + 3, "w+");
			break;
		case 'h':
			showHelp(argv[0], params);
			exit(0);
			break;
		case 'w':
			params->width = MAX(1, atoi(argv[i] + 3));
			break;
		case 'r':
			params->round = atoi(argv[i] + 3);
			break;
		case 't':
			params->timescalestep = atoi(argv[i] + 3);
			break;
		case 'b':
			params->beginsmpl = atoi(argv[i] + 3);
			break;
		case 'e':
			params->endsmpl = atoi(argv[i] + 3);
			break;
		case 's':
			params->scope = argv[i] + 3;
			break;
		case 'i':
			params->tui = atoi(argv[i] + 3);
			break;
		case 'z':
			params->zoom = atoi(argv[i] + 3);
			break;
		default:
			fprintf(stderr, "Unknow param '%c'", argv[i][1]);
		}
	}
}

int char2id(char* str_id)
{
	int i = strlen(str_id) - 1, id = 0;
	for (; i >= 0; i--)
	{
		id *= 94; //shift previous value
		id += str_id[i] - '!'; //! is 0, ~ is 93
	}
	return id;
}

void parseInst(Parameters* params, Parser* p)
{
	char token[32];
	fscanf(params->fin, "%31s", token);
	//printf("%s\n",token);
	if (!strcmp("var", token))
	{
		char id_str[4];
		Channel chan = {};
		fscanf(params->fin, " reg %d %3[^ ] %"TXT(MAX_NAME)"[^$]", &(chan.size), id_str, chan.name);
		fscanf(params->fin, " wire %d %3[^ ] %"TXT(MAX_NAME)"[^$]", &(chan.size), id_str, chan.name);
		int id = char2id(id_str);
		p->ch[id] = chan; //printf("size=%i <%c> name=<%s>\n",size,id,data);
		p->ch[id].scope = p->cur_scopes;
	}
	else if (!strcmp("scope", token))
		fscanf(params->fin, "%*127s %127[^ $]", p->scopes[p->cur_scopes = ++(p->nb_scopes)]);
	else if (!strcmp("date", token))
		fscanf(params->fin, "\n%31[^$\n]", p->date);
	else if (!strcmp("version", token))
		fscanf(params->fin, "\n%31[^$\n]", p->version);
	else if (!strcmp("timescale", token))
	  {
		fscanf(params->fin, "\n%127[^$\n]", p->scale);
		sprintf(p->scale, "1us");
		fprintf(stderr, "scale: %s\n", p->scale);
		sleep(1);
	  }
	else if (!strcmp("comment", token))
		fscanf(params->fin, "\n%*[^$]");
	else if (!strcmp("upscope", token))
	{
		fscanf(params->fin, "\n%*[^$]");    /*back to root */
		p->cur_scopes = 0;
	}
	else if (!strcmp("enddefinitions", token))
		fscanf(params->fin, "\n%*[^$]");
	else if (!strcmp("dumpvars", token))      {}
	else if (!strcmp("end", token))           {}
	else
		printf("Unknow token : %s\n", token);
}

void parseTime(Parameters* params, Parser* p)
{
	long long unsigned stamp = 0;
	unsigned i;
	int c;
	while ((c = fgetc(params->fin)) != EOF)
	{
		if (isdigit(c))
			stamp = stamp * 10 + (c - '0');
		else
		{
			ungetc(c, params->fin);
			if (p->nb >= COUNT(p->timestamps))
				return;
			if (p->nb > 0) //copy all previous channels_size val to the current one
			{
				for (i = 0; i < COUNT(p->ch); i++)
				{
					p->ch[i].val [p->nb] = p->ch[i].val [p->nb - 1];
					p->ch[i].type[p->nb] = p->ch[i].type[p->nb - 1];
				}
			}
			p->timestamps[p->nb] = stamp;
			p->nb++;
			return;
		}
	}
}
/*
there is 2 kinds of data definition line :
state    : 1^
bus data : b0100001001011001110 ^
*/
void parseData(Parameters* params, Parser* p)
{
	unsigned data = 0, id = 0;
	char id_str[4], type = '\0';
	int c = fgetc(params->fin);
	if (c == 'b') //parsing bus data b%[0-9UZX]+ %c
	{
		while ((c = fgetc(params->fin)) != EOF && c != ' ')
		{
			if (isdigit(c))
				data = data * 2 + (c - '0');
			else
			{
				//letter (Z,U,X,...) = undefined type, but we don't know the id yet
				if (c == 'x' || c == 'z')
					type = toupper(c);
				else
					type = c;
			}
		}
		fscanf(params->fin, "%3[^\n]", id_str);
		id = char2id(id_str);
		p->ch[id].type[p->nb - 1] = type;
		p->ch[id].val [p->nb - 1] = data;
	}
	else  //parsing state %[0-9UZX] %c
	{
		fscanf(params->fin, "%3[^\n]", id_str);
		id = char2id(id_str);
		if (isalpha(c))
			p->ch[id].type[p->nb - 1] = c;
		else
			p->ch[id].type[p->nb - 1] = '\0'; //letter (Z,U,X,...) = undefined type
		if (isdigit(c))
			p->ch[id].val [p->nb - 1] = c - '0';
	}
}

void parseFile(Parameters* params, Parser* p)
{
	int c;
	while ((c = fgetc(params->fin)) != EOF)
	{
		//		printf("?%c\n",c);
		if (isspace(c))
			continue;
		if (c == '$')
			parseInst(params, p);
		else if (isdigit(c) || c == 'b' || c == 'Z' || c == 'U' || c == 'x' || c == 'z')
		{
			if (c == 'x' || c == 'z')
				ungetc(toupper(c), params->fin);
			else
				ungetc(c, params->fin);
			parseData(params, p);
		}
		else if (c == '#')
			parseTime(params, p);
		else
			fprintf(stderr, "unknow char : %c\n", c);
	}
}

unsigned numDischarges(unsigned n)
{
	unsigned i = 0;
	do
	{
		n = n / 10;
		i += 1;
	}
	while (n > 0);
	return i;
}
void numDelete(char* instr, char* outstr)
{
	unsigned index = 0;
	for (unsigned i = 0; i < strlen(instr); i++)
		if (instr[i] < '0' || instr[i] > '9')
		{
			outstr[index] = instr[i];
			++index;
		}
	outstr[index] = '\0';
}


void showVertical(Parameters* params, Parser* p)
{
	if (p->nb      )
		fprintf(params->fout, "%i samples", p->nb);
	if (p->date [0])
		fprintf(params->fout, " / %s", p->date);
	if (p->scale[0])
		fprintf(params->fout, " / %s", p->scale);
	if (params->zoom)
		fprintf(params->fout, " / zoom: %d \n", params->zoom);
	fprintf(params->fout, "help: q quit / ←↓↑→ scroll / ctrl+←→ zoom  / r reload");
	fprintf(params->fout, "\n");

	char scalestr[32] = {'\0'};
	numDelete(p->scale, scalestr);

	for (unsigned chan = params->beginch; chan < (params->endch == 0 ? MAX_CHANNEL : params->endch); chan++)
	{

		if (!p->ch[chan].size)
			continue;//skip empty ch
		if (params->scope && (!p->ch[chan].scope || !strstr(params->scope, p->scopes[p->ch[chan].scope])))
			continue;//skip root node or unrelated node if scope-only wanted
		if ((!chan && p->ch[chan].scope) || (chan > 0 && (p->ch[chan].scope != p->ch[chan - 1].scope)))
		{
			unsigned timescalestep = params->timescalestep;
			if (timescalestep != 0)
			{
				fprintf(params->fout, "┌── %s%*.*stime: ", p->ch[chan].scope ? p->scopes[p->ch[chan].scope] : "", \
						params->colsize - strlen(p->ch[chan].scope ? p->scopes[p->ch[chan].scope] : "") - 2, 0);
				unsigned tmp = 0;
				for (unsigned smpl = (params->beginsmpl > 0 ? params->beginsmpl : 0); \
						smpl < (tmp = (params->endsmpl < p->nb && params->endsmpl != 0 ? params->endsmpl : p->nb) - (params->tui != 0 ? timescalestep * (params->zoom > 0 ? params->zoom : 1) : 0), tmp > 0 ? tmp : 0); \
						smpl += timescalestep * (params->zoom > 0 ? params->zoom : 1))
				{
					unsigned scalenum = smpl * atoi(p->scale);
					fprintf(params->fout, "▏%d%s%*.*s", scalenum, scalestr, timescalestep * params->width - 1 - numDischarges(scalenum) - strlen(scalestr), 0);
				}
				fprintf(params->fout, "\n│\n");
			}
			else
				fprintf(params->fout, "┌── %s\n", p->ch[chan].scope ? p->scopes[p->ch[chan].scope] : "");

		}
		fprintf(params->fout, "%s %*.*s[%2i]: ", p->ch[chan].scope ? "│" : " ", params->colsize, params->colsize, p->ch[chan].name, p->ch[chan].size);
		for (unsigned smpl = (params->beginsmpl > 0 ? params->beginsmpl : 0); \
				smpl < (params->endsmpl < p->nb && params->endsmpl != 0 ? params->endsmpl : p->nb); \
				smpl += 1 * (params->zoom > 0 ? params->zoom : 1))
		{
			char     type = p->ch[chan].type[smpl];
			unsigned data = p->ch[chan].val [smpl];
			if (p->ch[chan].size == 1) //binary
			{
				unsigned w = params->width;
				//have a previous data => can print a transition
				if (params->round && smpl > 0 && !p->ch[chan].type[smpl - 1])
				{
					if (p->ch[chan].val[smpl] != p->ch[chan].val[smpl - 1]) //the value changed
					{
						//from H to L or L to H ?
						fprintf(params->fout, params->round == 2 ? "%s" : "│", (p->ch[chan].val[smpl - 1] ? "╲" : "╱"));
						w -= 1;
					}
				}
				unsigned t = 0, ids = 0;
				for (unsigned i = smpl + 1; i < (smpl + params->zoom < p->nb ? smpl + params->zoom : smpl); i++)
					if (p->ch[chan].val[i] != p->ch[chan].val[i - 1]) //the value changed
					{
						t++;
						ids = i;
					}

				while (w-- > 0)
				{
					switch (t)
					{
					default:
						fprintf(params->fout, "║");
						break;
					case 1:
						if (w == 0)
						{
							if (params->round != 0)
							{
								fprintf(params->fout, params->round == 2 ? "%s" : "│", (p->ch[chan].val[ids - 1] ? "╲" : "╱"));
								break;
							}
						}
						else
						case 0:
						if (type)
							fprintf(params->fout, "%c", type);
						else
							fprintf(params->fout, "%s", data ? "▔" : "▁");
						break;
					}
				}
			}
			else  //bus
			{
				if (p->ch[chan].type[smpl])
					fprintf(params->fout, "%*c", params->width, p->ch[chan].type[smpl]);
				else
				{
					char buffer[12];
					sprintf(buffer, "%X", p->ch[chan].val[smpl]);
					if (strlen(buffer) <= params->width)
						fprintf(params->fout, "%*X", params->width, p->ch[chan].val[smpl]);
					else
						fprintf(params->fout, "%*c", params->width, '#');
				}
			}
		}

		fprintf(params->fout, "%s%s\n", "\n", p->ch[chan].scope ? "│" : " ");
	}
}

int main(int argc, char** argv)
{
	Parameters params =
	{
		.width = 2,
		.round = 2,
		.colsize = 0,
		.timescalestep = 10,
		.zoom = 1,
		.beginsmpl = 0,
		.endsmpl = 0,
		.tui = 1,
		.beginch = 0,
		.endch = 0,
		.fin = stdin,
		.fout = stdout,
	};
	Parser data;
	parseArgs(argc, argv, &params);

	unsigned keyCode = 0;
	unsigned rows, cols;
	unsigned starttui = 0;
	do
	{
		if (!starttui)
		{
			memset(&data, 0, sizeof(Parser));
			params.fin = fopen(params.file, "r");
			if (!params.fin)
				return fprintf(stderr, "no input file\n"), -1;
			parseFile(&params, &data);
			fclose(params.fin);
			params.fin = stdin;

			params.colsize = 0;
			for (unsigned chan = 0; chan < MAX_CHANNEL; chan++)
			{
				if (params.colsize < strlen(data.ch[chan].name))
					params.colsize =  strlen(data.ch[chan].name);
				if (params.colsize < strlen(data.ch[chan].scope ? data.scopes[data.ch[chan].scope] : ""))
					params.colsize =  strlen(data.ch[chan].scope ? data.scopes[data.ch[chan].scope] : "");
			}

			params.colsize += 2;
		}

		if (params.tui != 0)
		{
			if (getSize(&rows, &cols))
			{
				fprintf(stderr, "Terminal size is unknown\n");
				return 1;
			}
			keyCode = starttui ? keyEvents() : 0;

			if (keyCode == 'q')
				return 0;
			if (keyCode == 1054 || keyCode == 97)
			  {
			    params.zoom = (params.zoom) + 1;
			  }
			if (keyCode == 1053 || keyCode == 122)
			  {
			    params.zoom = (params.zoom > 1 ? params.zoom - 1 : 1);
			  }
			if (keyCode == 1001)
				params.beginch = (params.beginch > 1 ? params.beginch - 1 : 0);
			if (keyCode == 1002)
				params.beginch += 1;
			if (keyCode == 1003)
				params.beginsmpl += 2 * params.zoom;
			if (keyCode == 1004)
				params.beginsmpl = (params.beginsmpl > 2 * params.zoom ? params.beginsmpl - 2 * params.zoom : 0);
			unsigned sizewindow = (cols - params.colsize - 8 - 2) / params.width * params.zoom;
			params.endsmpl = params.beginsmpl + sizewindow;
			params.endch = params.beginch + rows / 2 - 4;

			starttui = 1;
			if (keyCode == 'r')
				starttui = 0;
			system("clear");
		}
		showVertical(&params, &data);
	}
	while (params.tui != 0);
	return 0;
}

/////////////////////////////////////////TUI
int getc_noecho()
{
	struct termios oldt, newt;
	int ch;
	tcgetattr( STDIN_FILENO, &oldt );
	newt = oldt;
	newt.c_lflag &= ~ICANON;
	//if(echo != 0)
	//newt.c_lflag &=  ECHO;
	//else
	newt.c_lflag &= ~ECHO;

	tcsetattr( STDIN_FILENO, TCSANOW, &newt );
	ch = getchar();
	tcsetattr( STDIN_FILENO, TCSANOW, &oldt );
	return ch;
}

int keyEvents()
{
	int ch;
	ch = getc_noecho();
	if (ch == '\x1B')
	{
		ch = getc_noecho();
		if (ch == '[')
		{
			ch = getc_noecho();
			switch (ch)
			{
			case '1':
				ch = 1000;
				break;//combination
			case 'A':
				ch = 1001;
				break;//printf("top\n\r");break;
			case 'B':
				ch = 1002;
				break;//printf("bot\n\r");break;
			case 'C':
				ch = 1003;
				break;//printf("rig\n\r");break;
			case 'D':
				ch = 1004;
				break;//printf("lef\n\r");break;
			case 'H':
				ch = 1005;
				break;//printf("home\n\r");break;
			case 'F':
				ch = 1006;
				break;//printf("end\n\r");break;
			}
			if (ch == 1000)
			{
				ch = getc_noecho();
				if (ch == ';')
				{
					unsigned combination = 0;
					ch = getc_noecho();
					switch (ch)
					{
					case '2':
						combination = 20;
						break;//shift
					case '3':
						combination = 30;
						break;//alt
					case '4':
						combination = 40;
						break;//alt+shift
					case '5':
						combination = 50;
						break;//ctrl
					}
					ch = getc_noecho();
					switch (ch)
					{
					case 'A':
						ch = 1001 + combination;
						break;
					case 'B':
						ch = 1002 + combination;
						break;
					case 'C':
						ch = 1003 + combination;
						break;
					case 'D':
						ch = 1004 + combination;
						break;
					case 'H':
						ch = 1005 + combination;
						break;
					case 'F':
						ch = 1006 + combination;
						break;
					}
				}
			}
		}
	}
	//printf("keyCode:%d  %c\n\r",ch,ch);
	return ch;
}

int getSize(unsigned* const rows, unsigned* const cols)
{
	struct winsize sz;
	int	result;
	do
	{
		result = ioctl(STDOUT_FILENO, TIOCGWINSZ, &sz);
	}
	while (result == -1 && errno == EINTR);
	if (result == -1)
		return errno;
	if (rows)
		*rows = sz.ws_row;
	if (cols)
		*cols = sz.ws_col;
	return 0;
}


