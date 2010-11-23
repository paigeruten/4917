#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define I_HALT 0
#define I_ADD  1
#define I_SUB  2
#define I_INC0 3
#define I_INC1 4
#define I_DEC0 5
#define I_DEC1 6
#define I_BELL 7
#define I_PRNT 8
#define I_LD0  9
#define I_LD1  10
#define I_ST0  11
#define I_ST1  12
#define I_JMP  13
#define I_JZ   14
#define I_JNZ  15

// if defined, print "DING" instead of actually ringing a bell
//#define FAKE_BELL

int main(int argc, char *argv[]) {
  int ip;
  int is;
  int r0;
  int r1;
  int data;
  char memory[16];
  int mp;

  FILE *in = stdin;
  char instruct[12];
  int instruct_i;
  int ch;
  int i;

  if (argc == 2) {
    if ((in = fopen(argv[1], "r")) == NULL) {
      fprintf(stderr, "couldn't open file '%s'\n", argv[1]);
      exit(1);
    }
  } else if (argc > 2) {
    fprintf(stderr, "usage: %s [filename]\n", argv[0]);
    exit(1);
  }

  memset(memory, 0, sizeof(memory));

  instruct_i = 0;
  mp = 0;
  while (ch = fgetc(in)) {
    if (isdigit(ch)) {
      instruct[instruct_i++] = ch;
    } else if (instruct_i > 0) {
      if (mp == 16) {
        fprintf(stderr, "Error: program too big\n");
        fclose(in);
        exit(1);
      }

      instruct[instruct_i] = '\0';
      memory[mp++] = atoi(instruct);

      if (memory[mp - 1] < 0) {
        fprintf(stderr, "Error: program contains negative instructions\n");
        fclose(in);
        exit(1);
      } else if (memory[mp - 1] > 15) {
        fprintf(stderr, "Error: program contains instructions that are too large\n");
        fclose(in);
        exit(1);
      }

      instruct_i = 0;
    }

    if (ch == EOF) {
      break;
    }
  }

  fclose(in);

  ip = 0;
  is = 0;
  r0 = 0;
  r1 = 0;

  do {
    if (ip > 15) {
      is = 0;
    } else {
      is = memory[ip++];
    }

    if (is > 7) {
      data = memory[ip++];
    }

    switch (is) {
      case I_HALT:
        break;

      case I_ADD:
        r0 = (r0 + r1) % 16;
        break;

      case I_SUB:
        r0 = (r0 - r1) % 16;
        break;

      case I_INC0:
        r0 = (r0 + 1) % 16;
        break;

      case I_INC1:
        r1 = (r1 + 1) % 16;
        break;

      case I_DEC0:
        r0 = (r0 - 1) % 16;
        break;

      case I_DEC1:
        r1 = (r1 - 1) % 16;
        break;

      case I_BELL:
        #ifdef FAKE_BELL
        printf("DING ");
        #else
        putchar('\a');
        #endif
        break;

      case I_PRNT:
        printf("%d ", memory[ip - 1]);
        break;

      case I_LD0:
        r0 = memory[data];
        break;

      case I_LD1:
        r1 = memory[data];
        break;

      case I_ST0:
        memory[data] = r0;
        break;

      case I_ST1:
        memory[data] = r1;
        break;

      case I_JMP:
        ip = data;
        break;

      case I_JZ:
        if (r0 == 0) {
          ip = data;
        }
        break;

      case I_JNZ:
        if (r0 != 0) {
          ip = data;
        }
        break;
    }
  } while (is != 0);

  putchar('\n');

  return 0;
}

