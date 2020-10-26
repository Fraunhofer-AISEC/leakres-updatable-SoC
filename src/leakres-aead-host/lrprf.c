#include <stdio.h>
#include <stdlib.h>
#include <mbedtls/aes.h>
#include <string.h>
#include "lrprf.h"

static void gen_plaintext(const lr_dc dc, uint8_t iv_bitval, uint8_t *ptxt) {
	unsigned int bit_size = dc;
	uint8_t b = 0;

	for (unsigned int i = 0; i < 8/bit_size; i++) {
		b |= iv_bitval << (i*bit_size);
	}
	for (unsigned int i = 0; i < 16; i++){
		ptxt[i] = b;
	}
	return;
}

lr_result lrprf(const uint8_t *data, size_t data_len, const uint8_t *key,
		size_t key_len, const lr_dc dc, uint8_t *output)
{
	uint8_t running_key[16];
	uint8_t plaintext[16];
	mbedtls_aes_context aes;
	unsigned int bit_size = dc;
	unsigned int mask = (2 << (bit_size - 1)) - 1;

	/* evaluate ggm tree, start from MSB */
	if (mbedtls_aes_setkey_enc(&aes, key, key_len*8)) {
		printf("%s (%d): mbedtls_aes_setkey_enc failed", __FILE__, __LINE__);
		return -1;
	}

	for (size_t b = 0; b < data_len; b++) {
		for (unsigned int i = 0; i < 8; i += bit_size) {
			unsigned int shift = 8 - i - bit_size;
			uint8_t tmp = (data[b] & (mask << shift));
			uint8_t p = tmp >> shift;
			gen_plaintext(dc, p, plaintext);
			if (mbedtls_aes_crypt_ecb(&aes, MBEDTLS_AES_ENCRYPT, plaintext, running_key)) {
				printf("%s (%d): mbedtls_aes_crypt_ecb failed", __FILE__, __LINE__);
				return -1;
			}

			/* update key */
			if (mbedtls_aes_setkey_enc(&aes, running_key, key_len*8)) {
				printf("%s (%d): mbedtls_aes_setkey_enc failed", __FILE__, __LINE__);
				return -1;
			}
		}
	}

	/* whitening step, always encrypt zeros */
	memset(plaintext, 0, sizeof(plaintext));
	if (mbedtls_aes_crypt_ecb(&aes, MBEDTLS_AES_ENCRYPT, plaintext, running_key)) {
		printf("%s (%d): mbedtls_aes_crypt_ecb failed", __FILE__, __LINE__);
		return -1;
	}

	memcpy(output, running_key, 16);
	return 0;
}
