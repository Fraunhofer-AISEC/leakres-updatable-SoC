#include <stdio.h>
#include <stdlib.h>
#include <mbedtls/aes.h>
#include <mbedtls/sha256.h>
#include <string.h>
#include "lrprf.h"
#include "lraead.h"

static uint8_t lr_prg_p_a[16] = {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
static uint8_t lr_prg_p_b[16] = {0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff};

struct lr_prg_context{
	uint8_t key[16];
};

static void lr_prg_init(struct lr_prg_context *ctx, const uint8_t *seed){
	memcpy(ctx->key, seed, 16);
}

static int lr_prg_iterate(struct lr_prg_context *ctx, uint8_t *output){
	mbedtls_aes_context aes;
	uint8_t tmp[16];

	if (mbedtls_aes_setkey_enc(&aes, ctx->key, 128)) {
		printf("%s (%d): mbedtls_aes_setkey_enc failed", __FILE__, __LINE__);
		return -1;
	}

	/* calc next key */
	if (mbedtls_aes_crypt_ecb(&aes, MBEDTLS_AES_ENCRYPT, lr_prg_p_a, tmp)) {
		printf("%s (%d): mbedtls_aes_crypt_ecb failed", __FILE__, __LINE__);
		return -1;
	}

	/* calc output */
	if (mbedtls_aes_crypt_ecb(&aes, MBEDTLS_AES_ENCRYPT, lr_prg_p_b, output)) {
		printf("%s (%d): mbedtls_aes_crypt_ecb failed", __FILE__, __LINE__);
		return -1;
	}

	memcpy(ctx->key, tmp, 16);
	return 0;
}


/* encrypt / decrypt can be done in-place */
static int lr_prg_streamcipher(const uint8_t *input, uint8_t *output, const size_t len,
	const uint8_t *iv, const uint8_t *key, const size_t key_len, const lr_dc dc )
{
	struct lr_prg_context ctx;
	unsigned int num_blocks;
	unsigned int remainder;
	unsigned int idx = 0;
	uint8_t enc_pad[16];
	uint8_t seed [16];

	lr_result lrc;
	/* generate seed for PRG with PRF */
	lrc = lrprf(iv, 16, key, key_len, dc, seed);
	if (lrc != LR_RES_VERIFY_SUCCESS) {
		return -1;
	}

	/* encrypt / decrypt using LRPRG */
	lr_prg_init(&ctx, seed);
	num_blocks = len / 16;
	remainder = len % 16;

	for (unsigned int i = 0; i < num_blocks; i++) {
		if (lr_prg_iterate(&ctx, enc_pad)){
			return -1;
		}
		for (unsigned int j = 0; j < 16; j++) {
			output[idx] = input[idx] ^ enc_pad[j];
			idx++;
		}
	}

	if (remainder) {
		if (lr_prg_iterate(&ctx, enc_pad)){
			return -1;
		}
		for (unsigned int j = 0; j < remainder; j++) {
			output[idx] = input[idx] ^ enc_pad[j];
			idx++;
		}
	}

	return 0;
}

static int calc_tag(const struct aead_input *aead_input, const uint8_t *ciphertext,
	const struct aead_config *aead_config, uint8_t *tag) {
	mbedtls_sha256_context ctx;
	unsigned char sha_output[32];
	lr_result lr_res;

	/* hash IV | ADATA | CTXT */
	mbedtls_sha256_init(&ctx);
	if(mbedtls_sha256_starts_ret(&ctx, 0)) {
		printf("%s (%d): mbedtls_sha256_starts_ret failed\n", __FILE__, __LINE__);
		return -1;
	}
	if (mbedtls_sha256_update_ret(&ctx, aead_input->iv, sizeof(aead_input->iv))) {
		printf("%s (%d): mbedtls_sha256_update_ret failed\n", __FILE__, __LINE__);
		return -1;
	}
	if (mbedtls_sha256_update_ret(&ctx, aead_input->adata, aead_input->adata_len)) {
		printf("%s (%d): mbedtls_sha256_update_ret failed\n", __FILE__, __LINE__);
		return -1;
	}
	if (mbedtls_sha256_update_ret(&ctx, ciphertext, aead_input->msg_len)) {
		printf("%s (%d): mbedtls_sha256_update_ret failed\n", __FILE__, __LINE__);
		return -1;
	}
	if (mbedtls_sha256_finish_ret(&ctx, sha_output)) {
		printf("%s (%d): mbedtls_sha256_finish_ret failed\n", __FILE__, __LINE__);
		return -1;
	}

	/* truncate sha256 output to 16 bytes */
	lr_res = lrprf(sha_output, 16, aead_config->mackey, aead_config->mackey_len, aead_config->dc, tag);
	if (lr_res != LR_RES_VERIFY_SUCCESS) {
		printf("%s (%d): lrprf failed\n", __FILE__, __LINE__);
		return -1;
	}

	mbedtls_sha256_free(&ctx);
	return 0;
}

/* output can point to aead_input->msg for in place calculation */
lr_result lraead(struct aead_input *aead_input, const struct aead_config *aead_config,
	uint8_t *output)
{
	uint8_t tag[16];

	if (aead_config->mode == LR_AEAD_ENCRYPT) {
		// encrypt then mac
		if (lr_prg_streamcipher(aead_input->msg, output, aead_input->msg_len,
			aead_input->iv, aead_config->enckey, aead_config->enckey_len, aead_config->dc)) {
			return LR_RES_UNKNOWN_ERR;
		}
		if (calc_tag(aead_input, output, aead_config, aead_input->tag)) {
			return LR_RES_UNKNOWN_ERR;
		}
	} else {
		// mac then decrypt
		if (calc_tag(aead_input, aead_input->msg, aead_config, tag)) {
			return LR_RES_UNKNOWN_ERR;
		}

		if (memcmp(tag, aead_input->tag, sizeof(aead_input->tag))) {
			return LR_RES_VERIFY_FAIL;
		}
		if (lr_prg_streamcipher(aead_input->msg, output, aead_input->msg_len,
			aead_input->iv, aead_config->enckey, aead_config->enckey_len, aead_config->dc)) {
			return LR_RES_UNKNOWN_ERR;
		}
	}

	return LR_RES_VERIFY_SUCCESS;
}
