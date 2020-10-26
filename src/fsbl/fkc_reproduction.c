/*
 * fkc_reproduction.c
 *
 *  Created on: Aug 27, 2020
 *      Author: jacob
 */


#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
//#include "platform.h"
#include "xil_printf.h"
#include "fuzzy_key_commitment.h"

#define NUM_TEST_KEYS 1
#define NUM_KEY_READBACK 20
#define NUM_PUF_EVAL 50
#define LEN_PUF_RESPONSE_BITS 498

void PrintHexArray(u32 *x, int len);


int fkc_reproduction(){


	  u32 reconstruct[FKC_NUM_KEY_WORDS] = { 0 };

	  RETURN_CODE ret;
	  //	  FIXME: Insert generated helper data following key enrollement
	  //u32 helper[FKC_NUM_HELPER_WORDS] = {<Insert generated helper data here>};
	  //u32 helper[FKC_NUM_HELPER_WORDS] = {0x12345678,0x12345678,0x12345678,0x12345678,\
											0x12345678,0x12345678,0x12345678,0x12345678,\
										  	0x12345678,0x12345678,0x12345678,0x12345678,\
										  	0x12345678,0x12345678,0x12345678,0x12345678};
	  printf("\n\r");
	  printf("********************************\n\r");
	  printf(" FUZZY KEY COMMITMENT TESTING\n\r");
	  printf("********************************\n\r");
	  printf("\n\r");

	  printf("\t helper:");
	  PrintHexArray(&helper[0], FKC_NUM_HELPER_WORDS);
	  printf("\n\r");
	  printf("\n\r");

	  ret = FKC_KeyReconstruct(&reconstruct[0], &helper[0]);
	       if ( ret != SUCCESS ) {
	         return ret;
	       }
	       printf("Reconstructed key \n\r");
	       PrintHexArray(&reconstruct[0], FKC_NUM_KEY_WORDS);
	       printf("\n\r");

	      return 0;
}

void PrintHexArray(u32 *x, int len) {
  for (int i=0; i<len; i++) {
    printf("%08x", (unsigned int) x[i]);
  }
  return;
}

