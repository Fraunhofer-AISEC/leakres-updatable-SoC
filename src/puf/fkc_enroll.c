#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include "platform.h"
#include "xil_printf.h"
#include "fuzzy_key_commitment.h"

#define NUM_TEST_KEYS 1
#define NUM_KEY_READBACK 20
#define NUM_PUF_EVAL 50
#define LEN_PUF_RESPONSE_BITS 498

void RandomArray(u32 *x, int len);
void PrintHexArray(u32 *x, int len);
bool EqualArray(u32 *x, u32 *y, int len);
int HammingDistanceArray(u32 *x, u32 *y, int len);
int HammingWeight(u32 x);

int main()
{
  float error_counter = NUM_TEST_KEYS * NUM_KEY_READBACK;
  float hamming_distance = 0;
  bool compare;
  u32 key[FKC_NUM_KEY_WORDS] = {0x641DFFB4,0xCC225043,0x1853B3D7,0xEF536F8A, 0x0F92E787,0xFC829C8F,0x7EBE69E6,0xEC8721BB };
  u32 reconstruct[FKC_NUM_KEY_WORDS] = { 0 };
  u32 puf_reference[FKC_NUM_HELPER_WORDS] = { 0 };
  u32 puf_response[FKC_NUM_HELPER_WORDS] = { 0 };
  RETURN_CODE ret;

  u32 helper[FKC_NUM_HELPER_WORDS] = {0};
  init_platform();

  printf("\n\r");
  printf("********************************\n\r");
  printf(" FUZZY KEY COMMITMENT TESTING\n\r");
  printf("********************************\n\r");
  printf("\n\r");

  //Key enrollment
  // ***************************************************************************
  printf("Key commit & generate test:\n\r");
    printf("\t    key:");
    PrintHexArray(&key[0], FKC_NUM_KEY_WORDS);
    printf("\n\r");

    // generate helper data
    ret = FKC_KeyCommit(&key[0], &helper[0]);
    if ( ret != SUCCESS ) {
        return ret;
    }
    printf("\t helper:");
    PrintHexArray(&helper[0], FKC_NUM_HELPER_WORDS);
    printf("\n\r");
    printf("\n\r");

    // reconstruct key
    for ( int j=0; j<NUM_KEY_READBACK; j++ ) {
      ret = FKC_KeyReconstruct(&reconstruct[0], &helper[0]);
      if ( ret != SUCCESS ) {
        return ret;
      }
      compare = EqualArray(&key[0], &reconstruct[0], FKC_NUM_KEY_WORDS);
      if ( !compare ) {
        error_counter -= 1;
      }

      if ( !(j % ((int) NUM_KEY_READBACK / 10)) || (j == NUM_KEY_READBACK-1) ) {
        printf("\treconstruct %4d of %4d:", j+1, NUM_KEY_READBACK);
        PrintHexArray(&reconstruct[0], FKC_NUM_KEY_WORDS);
        if ( compare ) {
          printf(": OK");
        } else {
          printf(": FAIL");
        }
        printf("\n\r");
      }
    }
    printf("\n\r");

  // ***************************************************************************
  printf("PUF test:\n\r");
  // read back reference
  ret = FKC_PUFRead(&puf_reference[0]);
  if ( ret != SUCCESS ) {
    return ret;
  }
  hamming_distance = 0;

  // read back response
  for (int i=0; i<NUM_PUF_EVAL; i++) {
    ret = FKC_PUFRead(&puf_response[0]);
    if ( ret != SUCCESS ) {
      return ret;
    }
    hamming_distance += HammingDistanceArray(&puf_reference[0], &puf_response[0], FKC_NUM_HELPER_WORDS);

    if ( !(i % ((int) NUM_PUF_EVAL / 10)) || (i == NUM_PUF_EVAL-1) ) {
      printf("\tresponse %4d of %4d:", i+1, NUM_PUF_EVAL);
      PrintHexArray(&puf_response[0], FKC_NUM_HELPER_WORDS);
      printf("\n\r");
    }
  }
  hamming_distance /= NUM_PUF_EVAL;

  printf("\n\r");

  // ***************************************************************************
  printf("Test Summary:\n\r");
  printf("\tKey Reconstruction Success: %d of %d (%0.2f%%)\n\r",
    (int) error_counter,
    NUM_TEST_KEYS*NUM_KEY_READBACK,
    error_counter / (NUM_TEST_KEYS*NUM_KEY_READBACK) * 100);
  printf("\tPUF Response Hamming Distance: %0.2f of %d (%0.2f%%)\n\r",
    hamming_distance,
    LEN_PUF_RESPONSE_BITS,
    hamming_distance / LEN_PUF_RESPONSE_BITS * 100);
  printf("\n\r");

  // ***************************************************************************
  printf("(note the leading 14-bits of the PUF/Helper Data values are fixed to zero\n\r");
  printf(" this is due to the mismatch in the required helper data size of 498-bits\n\r");
  printf(" and the register size of 512-bits. this is taken into account for the\n\r");
  printf(" Hamming weight calculation)\n\r");

  printf("********************************\n\r");
  printf(" END OF TEST\n\r");
  printf("********************************\n\r");
  printf("\n\r");

  cleanup_platform();
  return 0;
}

// misc utility functions for testing
void RandomArray(u32 *x, int len) {
  for (int i=0; i<len; i++) {
    x[i] = (u32) rand();
  }
  return;
}

void PrintHexArray(u32 *x, int len) {
  for (int i=0; i<len; i++) {
    printf("%08x", (unsigned int) x[i]);
  }
  return;
}

bool EqualArray(u32 *x, u32 *y, int len) {
  for (int i=0; i<len; i++) {
    if ( x[i] != y[i] ) {
      return false;
    }
  }
  return true;
}

int HammingDistanceArray(u32 *x, u32 *y, int len) {
	int i;
	int dist = 0;

	for (i = 0; i < len; i++) {
		dist += HammingWeight( x[i] ^ y[i] );
	}
	return dist;
}

int HammingWeight(u32 x) {
  int weight = 0;
  while ( x != 0 ) {
    weight++;
    x &= x - 1;
  }
  return weight;
}
