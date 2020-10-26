#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "../lraead.h"

static uint8_t keys[2][16] = {
	{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xab}, // k_enc
	{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xef}  // k_mac
};

static void printh(uint8_t* h, size_t size) {
	size_t i = 0;
	for (i = 0; i < size; i++)
		printf("%02X", h[i]);
}

int main(int argc, char **argv) {
	int rc,i;
	FILE* f;
	size_t adata_len;
	size_t msg_len;
	uint8_t* adata = NULL;
	uint8_t* msg = NULL;
	uint8_t* ctxtbuf = NULL;
	lr_dc dc = DC_2;
	struct aead_input aead_input;
	struct aead_config aead_config;
	lr_result lrc;
	uint32_t len32;
	char xil_dummy[4]={NULL,NULL,NULL,32};

	if (argc < 6 || argc > 7) {
		printf("Usage: %s adata_filename message_filename key_filename nonce_filename output_filename [data_complexity]\n", argv[0]);
		return -1;
	}

	if (argc == 7) {
		int tmp;

		if (sscanf(argv[6], "%i", &tmp) < 0) {
			printf("Invalid data complexity value\n");
			return -1;
		}

		switch (tmp) {
		case 2:
			dc = DC_2;
			break;
		case 4:
			dc = DC_4;
			break;
		case 16:
			dc = DC_16;
			break;
		case 256:
			dc = DC_256;
			break;
		default:
			printf("Invalid data complexity value\n");
			return -1;
		}
	}

	/* parse key */
	printf("parsing key\n");
	f = fopen(argv[3], "r");
	if (!f) {
		printf("Could not open key file: %s\n", argv[3]);
		return -1;
	}

	// get key size
	fseek(f, 0, SEEK_END);
	if (ftell(f) != sizeof(keys)) {

		printf("Invalid key length, expected %lu\n", sizeof(keys));
		return -1;
	}
	rewind(f);

	rc = fread(keys, 1, sizeof(keys), f);
	if (rc != sizeof(keys)) {
		printf("Could not read full key, expected %lu bytes, received %d\n", sizeof(keys), rc);
		return -1;
	}
	fclose(f);

	/* parse nonce */
	printf("parsing nonce\n");
	f = fopen(argv[4], "r");
	if (!f) {
		printf("Could not open nonce file: %s\n", argv[4]);
		return -1;
	}

	// get nonce size
	fseek(f, 0, SEEK_END);
	if (ftell(f) != sizeof(aead_input.iv)) {
		printf("Invalid nonce length, expected %lu\n", sizeof(aead_input.iv));
		return -1;
	}
	rewind(f);

	rc = fread(aead_input.iv, 1, sizeof(aead_input.iv), f);
	if (rc != sizeof(aead_input.iv)) {
		printf("Could not read full key, expected %lu bytes, received %d\n", sizeof(aead_input.iv), rc);
		return -1;
	}
	fclose(f);

	printf("parsing message\n");
	f = fopen(argv[2], "r");
	if (!f) {
		printf("Could not open message file: %s\n", argv[2]);
		return -1;
	}
	// get input size
	int pad_len;
	fseek(f, 0, SEEK_END);
	msg_len = ftell(f);
	if(msg_len%16 == 0){
		pad_len=0;
	}
	else{
		pad_len= 16-msg_len%16;
		f = fopen(argv[2], "ab");
		for (i=0; i<(16-msg_len%16);i++)
		{
			fputs(" ",f);
		}
		fclose(f);
	}
	msg_len = msg_len+pad_len;
	rewind(f);
	f = fopen(argv[2], "r");
	msg = malloc(msg_len);
	if (!msg) {
		printf("malloc failed.\n");
		return -1;
	}
	ctxtbuf = malloc(msg_len);
	if (!ctxtbuf) {
		printf("malloc failed.\n");
		return -1;
	}

	if (fread(msg, 1, msg_len, f) != msg_len) {
		printf("Could not read full message, expected %zi bytes\n", msg_len);
		return -1;
	}
	fclose(f);
	pad_len=0;


	printf("parsing adata\n");
	f = fopen(argv[1], "rb");
	if (!f) {
		printf("Could not open adata file: %s\n", argv[1]);
		return -1;
	}
	// get input size
	fseek(f, 0, SEEK_END);
	adata_len = ftell(f);
	printf("aad len: %d\n",adata_len);
	if (adata_len > 0) {
		if (adata_len%16 == 0){
			pad_len=0;
			fclose(f);
		}
		else if(adata_len < 16){
			f = fopen(argv[1], "ab");
			for (i=0; i<16-adata_len;i++)
			{
				fputs(" ",f);
				pad_len +=1;
			}
			fclose(f);
		}
		else{
			f = fopen(argv[1], "ab");
			for (i=0; i<(16-adata_len%16);i++)
			{
				fputs(" ",f);
				pad_len += 1;
			}
			fclose(f);
		}
		f = fopen(argv[1], "rb");
		rewind(f);
		adata_len= adata_len+pad_len;
		adata = malloc(adata_len);
		if (!adata) {
			return -1;
		}
	
			if (fread(adata, 1, adata_len, f) != adata_len) {
				printf("Could not read full adata, expected %zi bytes\n", adata_len);
				return -1;
			}
			fclose(f);
		}
	printf("k_enc:\n");
	printh(keys[0], sizeof(keys[0]));
	printf("\nk_mac:\n");
	printh(keys[1], sizeof(keys[1]));
	printf("\nnonce:\n");
	printh(aead_input.iv, sizeof(aead_input.iv));
//	printf("\nmsg:\n");
//	printh(msg, msg_len);
//	printf("\n");
	printf("\nadata:\n");
	printh(adata, adata_len);
	printf("\n");

	/* prepare aead input */
	aead_input.msg = msg;
	aead_input.msg_len = msg_len;
	aead_input.adata = adata ;
	aead_input.adata_len = adata_len;

	aead_config.enckey = keys[0];
	aead_config.enckey_len = sizeof(keys[0]);
	aead_config.mackey = keys[1];
	aead_config.mackey_len = sizeof(keys[1]);
	aead_config.dc = dc;
	aead_config.mode = LR_AEAD_ENCRYPT;

	lrc = lraead(&aead_input, &aead_config, ctxtbuf);
	if (lrc != LR_RES_VERIFY_SUCCESS) {
		printf("lraead failed\n");
		return -1;
	}

	printf("\ntag:\n");
	printh(aead_input.tag, sizeof(aead_input.iv));
	printf("\n");

	//  The format of the encrypted file is:
	//      Field                               Length
	//      ------------------------------------------
	//      1. Nonce                          16 Bytes
	//      2. Tag                            16 Bytes
	//      3. Length of AAD in byte           8 Bytes
	//      4. Length of payload in byte       8 Bytes
	//      5. AAD                                 var
	//      6. Payload                             var	}
	printf("writing result\n");
	f = fopen(argv[5], "w+");
	if (!f) {
		printf("Could not open output file: %s\n", argv[5]);
		return -1;
	}
	if (fwrite(aead_input.iv, 1, sizeof(aead_input.iv), f) != sizeof(aead_input.iv)) {
		printf("write1 failed\n");
		return -1;
	}
	if (fwrite(aead_input.tag, 1, sizeof(aead_input.tag), f) != sizeof(aead_input.tag)) {
		printf("write2 failed\n");
		return -1;
	}
	len32 = (uint32_t) adata_len;
	if (fwrite(&len32, 1, sizeof(len32), f) != sizeof(len32)) {
		printf("write3 failed\n");
		return -1;
	}
	len32 = (uint32_t) msg_len;
	printf("=======================\n\r");
	printf("msg_len: %x\n\r",len32);
	printf("=======================\n\r");
	if (fwrite(&len32, 1, sizeof(len32), f) != sizeof(len32)) {
		printf("write4 failed\n");
		return -1;
	}
	if (fwrite(adata, 1, adata_len, f) != adata_len) {
		printf("write5 failed\n");
		return -1;
	}
	if (fwrite(ctxtbuf, 1, msg_len, f) != msg_len) {
		printf("write6 failed\n");
		return -1;
	}
	fclose(f);

	/* check result */
	aead_input.msg = ctxtbuf;
	aead_config.mode = LR_AEAD_DECRYPT;

	lrc = lraead(&aead_input, &aead_config, ctxtbuf);
	if (lrc != LR_RES_VERIFY_SUCCESS) {
		printf("lraead failed\n");
		return -1;
	}

	if (memcmp(ctxtbuf, msg, msg_len)) {
		printf("compare failed\n");
		return -1;
	}

	free(msg);
	free(ctxtbuf);
	if (adata) free(adata);
	return 0;
}
