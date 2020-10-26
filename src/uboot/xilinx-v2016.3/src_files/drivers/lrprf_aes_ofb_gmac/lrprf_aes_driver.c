/*
 * Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
 * acting on behalf of its Fraunhofer Institute AISEC. 
 * All rights reserved.
 * 
 */


#include "lrprf_aes_driver.h"

int lrprf_aes_reset(){

	reg_write32(LRPRF_AES_CTRL_REG, LRPRF_AES_CTRL_RST_MASK);

	return 0;

}

void lrprf_aes_dumpregisters(){

	printf("               ---  lrprf aes ofb gmac Register Dump  ---\n\r");
	printf("---------------------------------------------------------------\n\r");
	printf("  Name                              Address      Value\n\r");
	printf("---------------------------------------------------------------\n\r");
	printf("  Control Register                  %08x   %08x\n\r", LRPRF_AES_CTRL_REG, *((volatile u32*)LRPRF_AES_CTRL_REG));
	printf("  Status Register                   %08x   %08x\n\r", LRPRF_AES_STAT_REG, *((volatile u32*)LRPRF_AES_STAT_REG));
	printf("  Input Register 0                  %08x   %08x\n\r", LRPRF_AES_IN_REG0, *((volatile u32* )LRPRF_AES_IN_REG0));
	printf("  Input Register 1                  %08x   %08x\n\r", LRPRF_AES_IN_REG1, *((volatile u32* )LRPRF_AES_IN_REG1));
	printf("  Input Register 2                  %08x   %08x\n\r", LRPRF_AES_IN_REG2, *((volatile u32* )LRPRF_AES_IN_REG2));
	printf("  Input Register 3                  %08x   %08x\n\r", LRPRF_AES_IN_REG3, *((volatile u32* )LRPRF_AES_IN_REG3));
	printf("  IV Register 0                     %08x   %08x\n\r", LRPRF_AES_IV_REG0, *((volatile u32* )LRPRF_AES_IV_REG0));
	printf("  IV Register 1                     %08x   %08x\n\r", LRPRF_AES_IV_REG1, *((volatile u32* )LRPRF_AES_IV_REG1));
	printf("  IV Register 2                     %08x   %08x\n\r", LRPRF_AES_IV_REG2, *((volatile u32* )LRPRF_AES_IV_REG2));
	printf("  IV Register 3                     %08x   %08x\n\r", LRPRF_AES_IV_REG3, *((volatile u32* )LRPRF_AES_IV_REG3));
	printf("  Output Register 0                 %08x   %08x\n\r", LRPRF_AES_OUT_REG0, *((volatile u32*)LRPRF_AES_OUT_REG0));
	printf("  Output Register 1                 %08x   %08x\n\r", LRPRF_AES_OUT_REG1, *((volatile u32*)LRPRF_AES_OUT_REG1));
	printf("  Output Register 2                 %08x   %08x\n\r", LRPRF_AES_OUT_REG2, *((volatile u32*)LRPRF_AES_OUT_REG2));
	printf("  Output Register 3                 %08x   %08x\n\r", LRPRF_AES_OUT_REG3, *((volatile u32*)LRPRF_AES_OUT_REG3));

}

int poll_timeout(u32 regAddr, u32 bitMask, u32 value, u32 timeout){

#ifndef LRPRF_AES_TURN_OFF_POLL_TIMEOUT
	u32 state;
	volatile u32 *reg = (u32*) regAddr;

	while (timeout){
		state = *reg;

		if ((state & bitMask) == value){
			return 0;
		}else {
			timeout--;
		}
	}

	printf("Error: Timeout when polling 0x%08x\n\r", regAddr);
	return 1;

#else //LRPRF_AES_TURN_OFF_POLL_TIMEOUT
	return 0;

#endif //LRPRF_AES_TURN_OFF_POLL_TIMEOUT
}
int lrprf_aes_parse_key(){
	int ret;

	// load key. control reg (6) = 1
	reg_write32(LRPRF_AES_CTRL_REG, LRPRF_AES_CTRL_LD_KEY_MASK);
	ret = poll_timeout(LRPRF_AES_STAT_REG, LRPRF_AES_STAT_BUSY_MASK, 0, LRPRF_AES_POLLTIMEOUT);

	// Check if AES is not busy and no error occured
	if (ret == 0){
		return 0;
	} else if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
		printf("Error: AES error during key load\n\r");
		return 1;
	} else {
		printf("Error: AES timeout during key load\n\r");
		return 1;
	}
}


int lrprf_aes_load_enc_partial_bitstream(lrprf_aes_encfile *encFile){

	int i,j;
	u32 aad_bytes, payload_bytes, aad_len_bits, iv_tmp;
	volatile u8 *payload_pos, *ad_pos;
	u32 aad_pad_len, aad_len;
	int ret;

	// Set devcfg.INT_STS[PCFG_DONE_INT] to clear DONE bit
	reg_write32(DEVCFG_INT_STS_ADDRESS, DEVCFG_INT_STS_PCFG_DONE_INT_MASK);



	payload_pos = encFile->payload_0;

	//iv-gmac
	reg_write32(LRPRF_AES_IV_REG0, to_little_endian(encFile->iv_h[0]));
	reg_write32(LRPRF_AES_IV_REG1, to_little_endian(encFile->iv_h[1]));
	reg_write32(LRPRF_AES_IV_REG2, to_little_endian(encFile->iv_h[2]));
	reg_write32(LRPRF_AES_IV_REG3, to_little_endian(encFile->iv_h[3]));

	// load iv gmac. Control Reg (7) = 1
	reg_write32(LRPRF_AES_CTRL_REG, LRPRF_AES_CTRL_LD_IV_MASK);

	ret = poll_timeout(LRPRF_AES_STAT_REG , LRPRF_AES_STAT_BUSY_MASK, 0, LRPRF_AES_POLLTIMEOUT);

	// Check if an error occured
	if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
		lrprf_aes_debug_print("Error: AES error [load iv gmac]\n\r");
		return 1;
	}
	// Check if a timout occured
	if (ret){
		lrprf_aes_debug_print("Error: AES timeout [load iv gmac]\n\r");
		return 1;
	}

	// input aad data
	// _length_high is ignored -> lengths limited to ~ 536 MB
	aad_len_bits = encFile->aad_length_low;		
	ad_pos = encFile->aad;

	if(aad_len_bits > 0){
		if(aad_len_bits%16 != 0)
			aad_pad_len = 16-aad_len_bits%16;
		else
			aad_pad_len = 0;
		aad_len = aad_len_bits+aad_pad_len;
		lrprf_aes_debug_print("AAD Len w/ pad(bits):%x\n\r",aad_len);
	}

	// input cipher text
	u32 blk_cnt, blk_len;
	blk_cnt = encFile->block_count_low;
	int k=0;

	if (encFile-> block_count_high > 0)
		{
			lrprf_aes_debug_print("Block count high not zero\r\n");
		}
	for(i=0; i< blk_cnt; i++)
	{
		if(i == (blk_cnt - 1))
			blk_len = encFile->block_length_last_low;
		else
			blk_len = encFile->block_length_low;

		reg_write32(LRPRF_AES_IV_REG0, to_little_endian(encFile->iv[0]));
		reg_write32(LRPRF_AES_IV_REG1, to_little_endian(encFile->iv[1]));
		reg_write32(LRPRF_AES_IV_REG2, to_little_endian(encFile->iv[2]));
		iv_tmp = to_little_endian(encFile->iv[3]);
		reg_write32(LRPRF_AES_IV_REG3, i);

		// load iv. Control Reg (7) = 1
		reg_write32(LRPRF_AES_CTRL_REG, LRPRF_AES_CTRL_LD_IV_MASK);

		ret = poll_timeout(LRPRF_AES_STAT_REG , LRPRF_AES_STAT_BUSY_MASK, 0, LRPRF_AES_POLLTIMEOUT);
	        // Check if an error occured
	        if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
        	        lrprf_aes_debug_print("Error: AES error [load IV]\n\r");
	                return 1;
	        }
	        // Check if a timout occured
        	if (ret){
	                lrprf_aes_debug_print("Error: AES timeout [load IV]\n\r");
        	        return 1;
	        }


		// input aad data for block 0
		if(aad_len > 0){
			for(k=0; k < aad_len/128; k++)
			{
				for(j=0;j < 4; j++)
				{
					reg_write32(LRPRF_AES_BASEADDRESS+IN_OFFSET+4*j,to_little_endian(*((u32*)ad_pos)));
					ad_pos += 4;
				}
				reg_write32(LRPRF_AES_BASEADDRESS+CONTROL_OFFSET, 0x0B);
				//busy flag
				ret = poll_timeout(LRPRF_AES_STAT_REG , LRPRF_AES_STAT_BUSY_MASK, 0, LRPRF_AES_POLLTIMEOUT);
			        // Check if an error occured
			        if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
			                lrprf_aes_debug_print("Error: AES error [load AAD] \n\r");
			                return 1;
			        }
			        // Check if a timout occured
			        if (ret){
			                lrprf_aes_debug_print("Error: AES timeout [load AAD]\n\r");
			                return 1;
			        }
			}
		}
		else {
			//lrprf_aes_debug_print("AAD None\n\r");
		}

		// input cipher text
		for(j=0; j<blk_len/16; j++)
		{
			for(k=0; k<4; k++)
			{
				reg_write32(LRPRF_AES_BASEADDRESS+IN_OFFSET+4*k,to_little_endian(*((u32*)payload_pos)));
				payload_pos += 4;
			}
			reg_write32(LRPRF_AES_BASEADDRESS+CONTROL_OFFSET, 0x03);
			//busy flag
			ret = poll_timeout(LRPRF_AES_STAT_REG , LRPRF_AES_STAT_BUSY_MASK, 0, LRPRF_AES_POLLTIMEOUT);
			// Check if an error occured
			if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
					lrprf_aes_debug_print("Error: AES error [decryption]\n\r");
					return 1;
			}
			// Check if a timout occured
			if (ret){
					lrprf_aes_debug_print("Error: AES timeout [decryption]\n\r");
					return 1;
			}

		}


		//tag length
		reg_write32(LRPRF_AES_IN_REG0, 0x00000000); 
		reg_write32(LRPRF_AES_IN_REG1, aad_len_bits);	// Len is expected in bits  
		reg_write32(LRPRF_AES_IN_REG2, 0x00000000);  
		reg_write32(LRPRF_AES_IN_REG3, (blk_len*8));

		//start calculation in decryption mode and tag. Control Reg (0) = 1,Control Reg (1) = 1, Control Reg (4) = 1
		reg_write32(LRPRF_AES_BASEADDRESS+CONTROL_OFFSET, 0x13);
		// wait until done bit is set
		ret = poll_timeout(LRPRF_AES_STAT_REG, LRPRF_AES_STAT_DONE_MASK, LRPRF_AES_STAT_DONE_MASK, LRPRF_AES_POLLTIMEOUT);
	        // Check if an error occured
	        if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
	                lrprf_aes_debug_print("Error: AES error [TAG calculation]\n\r");
	                return 1;
	        }
	        // Check if a timout occured
	        if (ret){
	                lrprf_aes_debug_print("Error: AES timeout [TAG calculation]\n\r");
	                return 1;
	        }

		// input tag data
		for(k=0; k<4; k++)
		{
			reg_write32(LRPRF_AES_BASEADDRESS+IN_OFFSET+4*k,to_little_endian(*((u32*)payload_pos)));
			payload_pos += 4;
		}
		//start calculation in decryption mode and tag. Control Reg (0) = 1,Control Reg (1) = 1, Control Reg (4) = 1
		reg_write32(LRPRF_AES_BASEADDRESS+CONTROL_OFFSET, 0x13);

		// wait until done bit is set
		ret = poll_timeout(LRPRF_AES_STAT_REG, LRPRF_AES_STAT_DONE_MASK, LRPRF_AES_STAT_DONE_MASK, LRPRF_AES_POLLTIMEOUT);
		// Check if an error occured
		if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
				lrprf_aes_debug_print("Error: AES error [TAG load]\n\r");
				return 1;
		}
		// Check if a timout occured
		if (ret){
				lrprf_aes_debug_print("Error: AES timeout[TAG load]\n\r");
				return 1;
		}

		// check if tag is valid
		if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_TAG_VALID_MASK){
			//lrprf_aes_debug_print("DecFile: LR-AES tag valid!\n\r");
		} else {
			printf("Error: AES GMAC tag of segment %d is not valid!\n\r", i);
			return 1;
		}
		//reset aad_len to 0 after first block
		aad_len=0;	
		aad_len_bits=0;
	}

	// Check if last block was processed
	if (i == blk_cnt){
		// Wait until FIFO is empty
		ret = poll_timeout(LRPRF_AES_STAT_REG , LRPRF_AES_STAT_FIFO_EMPTY_MASK, LRPRF_AES_STAT_FIFO_EMPTY_MASK, LRPRF_AES_POLLTIMEOUT);
		// Check for timeout
		if (ret == 0){
			// Check devcfg.INT_STS[PCFG_DONE_INT] if DONE is set
			if (reg_read32(DEVCFG_INT_STS_ADDRESS) & DEVCFG_INT_STS_PCFG_DONE_INT_MASK){
				// Configuration was successful
				return 0;
			}else{
				// DONE bit is not set. Indicates a problem during configuration.
				return 1;
			}
		}else{
			// Timeout while waiting for FIFO empty
			return 1;
		}
	}else{
		// Last block in file was not processed
		return 1;
	}
}

/* The format of the encrypted file is:
 *      Field                               Length
 *     --------------------------------------------
 *      1.  Payload block count            8 Bytes
 *      2.  Payload block length in byte   8 Bytes
 *      3.  Last block length in byte      8 Bytes
 *      4.  IV_gmac                       16 Bytes
 *      5.  IV                            16 Bytes
 *      6.  Length of AAd in bits          8 Bytes
 *      7.  AAD (padded to 128 bit)      var
 *      9.  Payload block 0               bl Bytes
 *      10.  Tag Payload block 0          16 Bytes
 *        ...
 *      11. Payload block bc-1            bl Bytes
 *      12. Tag Payload block bc-1        16 Bytes
 *
 */

int lrprf_aes_load_encfile(volatile u32 *filePtr, lrprf_aes_encfile *encFile ){

	uint32_t aad_words;
	uint32_t *file_word_ptr = filePtr;
	uint32_t aad_pad_len,aad_len;

	encFile->block_count_high = to_little_endian(*file_word_ptr++);
#if LRPRF_AES_DEBUG
	if (encFile->block_count_high > 0){
		printf("WARNING: Ignore byte 7-4 of block count.");
	}
#endif
	encFile->block_count_low = to_little_endian(*file_word_ptr++);

	encFile->block_length_high = to_little_endian(*file_word_ptr++);
#if LRPRF_AES_DEBUG
	if (encFile->block_length_high > 0){
		printf("WARNING: Ignore byte 7-4 of block length.");
	}
#endif
	encFile->block_length_low = to_little_endian(*file_word_ptr++);
	if (encFile->block_length_low % 16){
		printf("ERROR: Value of block length is no multiple of 16!");
		return 1;
	}

	encFile->block_length_last_high = to_little_endian(*file_word_ptr++);
#if LRPRF_AES_DEBUG
	if (encFile->block_length_last_high > 0){
		printf("WARNING: Ignore byte 7-4 of last block length.");
	}
#endif
	encFile->block_length_last_low = to_little_endian(*file_word_ptr++);
	if (encFile->block_length_last_low % 16){
		printf("ERROR: Value of last block length is no multiple of 16!");
		return 1;
	}

	encFile->iv_h = file_word_ptr;
	file_word_ptr += 4;
	encFile->iv = file_word_ptr;
	file_word_ptr += 4;

	encFile->aad_length_high = to_little_endian(*file_word_ptr++);
#if LRPRF_AES_DEBUG
	if (encFile->aad_length_high > 0){
		printf("WARNING: Ignore byte 7-4 of additional authentication data length.");
	}
#endif
	encFile->aad_length_low = to_little_endian(*file_word_ptr++);
	encFile->aad = (u8*)(file_word_ptr);

	// aad_length_high is ignored -> ad_length limited to ~ 536 MB
	// add padding length
	if(encFile->aad_length_low != 0){
		if(encFile->aad_length_low%16 != 0)
			aad_pad_len = 16-encFile->aad_length_low%16;
		else
			aad_pad_len = 0;
		aad_len = encFile->aad_length_low+aad_pad_len;
		lrprf_aes_debug_print("AAD Len w/ pad(bits):%x \n\r",aad_len);
		aad_words = (aad_len/128)*4;
	}
	else{
		lrprf_aes_debug_print("no AAD\n\r");
		aad_words= 0;
	}

	encFile->payload_0 = file_word_ptr + aad_words;

	return 0;

}

int lrprf_aes_print_encfile(lrprf_aes_encfile *encFile){

	u32 aad_words, aad_words_print;
	int i, block, block_length_in_16bytes;
	uint8_t* data_rd_ptr;
	uint32_t aad_pad_len,aad_len;

	printf("Content of encrypted file at address 0x%08x:\n\r", encFile);
	printf("   Block count (high):       %10d\n\r", encFile->block_count_high);
	printf("   Block count (low):        %10d\n\r", encFile->block_count_low);
	printf("   Block length (high):      %10d\n\r", encFile->block_length_high);
	printf("   Block length (low):       %10d\n\r", encFile->block_length_low);
	printf("   Last block length (high): %10d\n\r", encFile->block_length_last_high);
	printf("   Last block length (low):  %10d\n\r", encFile->block_length_last_low);
	printf("   IV_h:                     0x");
	for (i = 0; i < 16; i++){
		printf("%02x", ((uint8_t*)(encFile->iv_h))[i]);
		if (!((i+1)%4)){
			printf(" ");
		}
	}
	printf("\n\r");
	printf("   IV:                       0x");
	for (i = 0; i < 16; i++){
		printf("%02x", ((uint8_t*)(encFile->iv))[i]);
		if (!((i+1)%4)){
			printf(" ");
		}
	}
	printf("\n\r");
	printf("   AAD length (high):        %10d\n\r", encFile->aad_length_high);
	printf("   AAD length (low):         %10d\n\r", encFile->aad_length_low);

	if(encFile->aad_length_low != 0){
		if(encFile->aad_length_low%16 != 0)
			aad_pad_len = 16-encFile->aad_length_low%16;
		else
			aad_pad_len = 0;
		aad_len = encFile->aad_length_low+aad_pad_len;
		printf("AAD Len w/ pad(bits):%x\n\r",aad_len);

		aad_words = (aad_len/128)*4;
		aad_words_print = aad_len/32;
	}
	else{
		printf("no AAD\n\r");	
		aad_words= 0;
	}

	if (encFile->aad_length_low){
		printf("   AAD:                      0x");
		for (i = 0; i < aad_words*4; i++){
			printf("%02x", (encFile->aad)[i]);
			if (!((i+1)%4)){
				if (!((i+1)%16)){
					if (aad_words_print > 16 && i == 15){
						// Jump to the end of AAD (print only last 8 words)
						printf("\n\r                             ...\n\r                             0x");
						i = (aad_words_print-8)*4-1;  // Minus one, since i will be incremented after that turn
					}else{
						if (i == aad_words*4-1){
							// Last new line
							printf("\n\r");
						}else{
							// New line every 16 bytes
							printf("\n\r                             0x");
						}
					}
				}else{
					// Space every four bytes
					printf(" ");
				}
			}
		}
	}else{
		printf("   AAD:                      none\n\r");
	}


	data_rd_ptr = encFile->payload_0;

	for (block = 0; block < encFile->block_count_low; block++){
		if (block != encFile->block_count_low-1){
			block_length_in_16bytes = encFile->block_length_low/16;
		}else{
			block_length_in_16bytes = encFile->block_length_last_low/16;
		}

		printf("   Payload %-10d:       0x", block);
			for (i = 0; i < block_length_in_16bytes*16; i++){
				printf("%02x", *data_rd_ptr);
				if (!((i+1)%4)){
					if (!((i+1)%16)){
						//if (block_length_in_16bytes > 4 && i == 15){
						if (0){
							// Jump to the end of payload (print only last 8 words)
							printf("\n\r                             ...\n\r                             0x");
							data_rd_ptr += (block_length_in_16bytes-2)*16-1-i;
							i = (block_length_in_16bytes-2)*16-1;  // Minus one, since i will be incremented after that turn
						}else{
							if (i == block_length_in_16bytes*16-1){
								// Last new line
								printf("\n\r");
							}else{
							// New line every 16 bytes
							printf("\n\r                             0x");
						}
					}
				}else{
					// Space every four bytes
					printf(" ");
				}
			}
			data_rd_ptr++;
		}

		printf("   Tag %-10d:           0x", block);
		for (i = 0; i < 16; i++){
			printf("%02x", *data_rd_ptr);
			if (!((i+1)%4)){
				printf(" ");
			}
			data_rd_ptr++;
		}
		printf("\n\r");


		// Only print first and last block
		if (encFile->block_count_low > 2){
			if (block == 0){
				data_rd_ptr = encFile->payload_0 + (encFile->block_count_low-1) * encFile->block_length_low;
				block = encFile->block_count_low-1;
			}
		}

	}

	return 0;
}

u32 to_little_endian(u32 in){

	u32 out;
	u8 *out_ptr = (u8*) &out;
	u8 *in_ptr = (u8*) &in;

	out_ptr[0] = in_ptr[3];
	out_ptr[1] = in_ptr[2];
	out_ptr[2] = in_ptr[1];
	out_ptr[3] = in_ptr[0];

	return out;
}

static void printh(const uint8_t* h, size_t size) {
	size_t i = 0;
	for (i = 0; i < size; i++)
		printf("%02X", h[i]);
}



int lraead_calc_hash(lraead_encfile *aead_file, uint8_t *hash)
{
	sha256_context ctx ;
	unsigned char sha_output[32];
	unsigned char hash_o[16];
	uint8_t nonce[16];
	int i,j=0;
//	mbedtls_sha256_init(&ctx);
//	/* hash IV | ADATA | CTXT */
#ifdef DEBUGAEAD
	printf("hash input: nonce\n\r");
	printh(aead_file->nonce, 16);
	printf("hash input: aad\n\r");
	printh(aead_file->aad, aead_file->aad_length);
	printf("hash input: payload\n\r");
	printh(aead_file->payload, aead_file->payload_length);
	printf("\n\r");

#endif
	sha256_starts(&ctx);

	sha256_update(&ctx, aead_file->nonce, 16);

	sha256_update(&ctx, aead_file->aad, aead_file->aad_length);

	sha256_update(&ctx, aead_file->payload, aead_file->payload_length);

	sha256_finish(&ctx, sha_output);

#ifdef DEBUGAEAD
	printf("hash:\n\r");
	printh(sha_output, sizeof(sha_output));
	printf("\n\r");
#endif
	for(i=0; i<16; i++)
	{
		hash[i] = sha_output[i];
	}

#ifdef DEBUGAEAD
	printf("truncated hash:\n\r");
	printh(hash, 16);
	printf("\n\r");
#endif
//	free(&ctx);
	return 0;
}

/* The format of the encrypted file is:
 *      Field                               Length
 *     --------------------------------------------
 *      1.  nonce						 16 Bytes
 *      2.  tag							 16 Bytes
 *      3.  Length of AAd in bytes       4 Bytes
 *      3.  Length of payload in bytes   4 Bytes
 *      5.  AAD (padded to 128 bit)      var
 *      6.  Payload in bytes             var 
 *
 */

int lraead_load_encfile(volatile u32 *filePtr, lraead_encfile *aead_file ){

	uint32_t aad_bytes;
	uint32_t *file_word_ptr = filePtr;
	uint32_t aad_pad_len,aad_len;


	aead_file->nonce = file_word_ptr;
	file_word_ptr += 4;
	aead_file->tag = file_word_ptr;
	file_word_ptr += 4;

	aead_file->aad_length = (*file_word_ptr++);
	aead_file->payload_length = (*file_word_ptr++);
	aead_file->aad = (u8*)(file_word_ptr);
	if(aead_file->aad_length != 0){
		lrprf_aes_debug_print("AAD present\n\r");
		aad_bytes = aead_file->aad_length;
	}
	else{
		lrprf_aes_debug_print("no AAD\n\r");
		aad_bytes= 0;
	}


	aead_file->payload = (u8*)(file_word_ptr) + aad_bytes;

	return 0;

}

/*
 * Parse computed hash to the lraes in standalone mode
 */
int lrprf_standalone_load_hash(lraead_encfile *aead_file, uint8_t *hash)
{

	int k=0;
	int ret;
	//calcuate hash of the file
	lraead_calc_hash(aead_file, hash);

	// Load hash
		for(k=0; k<4; k++)
		{
			reg_write32(LRPRF_AES_BASEADDRESS+IV_OFFSET+4*k,to_little_endian(*((u32*)hash)));
			hash += 4;
		}

	// set standalone mode. control reg (4) = 1 and control reg (7) = 1 
	reg_write32(LRPRF_AES_BASEADDRESS+CONTROL_OFFSET, 0x90);
	//reg_write32(LRPRF_AES_CTRL_REG, LRPRF_AES_CTRL_STANDALONE_MASK);

	ret = poll_timeout(LRPRF_AES_STAT_REG, LRPRF_AES_STAT_BUSY_MASK, 0, LRPRF_AES_POLLTIMEOUT);

	// Check if AES is not busy and no error occured
	if (ret == 0){
		printf("LRAEAD Streamcipher: hash loaded!\n\r");
	} else if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
		printf("Error: AES error during hash load\n\r");
		return 1;
	} else {
		printf("Error: AES timeout during hash load\n\r");
		return 1;
	}
	// Load Tag for comparison
	reg_write32(LRPRF_AES_IN_REG0, to_little_endian(aead_file->tag[0]));
	reg_write32(LRPRF_AES_IN_REG1, to_little_endian(aead_file->tag[1]));
	reg_write32(LRPRF_AES_IN_REG2, to_little_endian(aead_file->tag[2]));
	reg_write32(LRPRF_AES_IN_REG3, to_little_endian(aead_file->tag[3]));

	//start calculation in decryption mode and tag. Control Reg (1) = 1, Control Reg (4) = 1
	reg_write32(LRPRF_AES_BASEADDRESS+CONTROL_OFFSET, 0x18);

	// check if tag is valid
	if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_TAG_VALID_MASK){
		printf("LRAEAD Streamcipher: LR-AES tag valid!\n\r");
	} else {
		printf("Error: LRAEAD tag of image is not valid!\n\r");
		return 1;
	}
#ifdef DEBUGAEAD
	printf("Out Reg0: %08x   %08x\n\r", LRPRF_AES_OUT_REG0, *((volatile u32*)LRPRF_AES_OUT_REG0));
	printf("Out Reg1: %08x   %08x\n\r", LRPRF_AES_OUT_REG1, *((volatile u32*)LRPRF_AES_OUT_REG1));
	printf("Out Reg2: %08x   %08x\n\r", LRPRF_AES_OUT_REG2, *((volatile u32*)LRPRF_AES_OUT_REG2));
	printf("Out Reg3: %08x   %08x\n\r", LRPRF_AES_OUT_REG3, *((volatile u32*)LRPRF_AES_OUT_REG3));
#endif
	// reset standalone mode. control reg (4) = 1 and control reg (7) = 1 
	reg_write32(LRPRF_AES_BASEADDRESS+CONTROL_OFFSET, 0x00);
	return 0;
}

/*
 * Decrypt partial bitstream with lrprf in stream cipher mode
 */
int lrprf_stream_dec_pr_bit(lraead_encfile *aead_file)
{
	int i,j,k;
	uint32_t payload_blocks;
	volatile uint8_t *payload_pos;
	int ret;

	payload_pos = aead_file->payload;

	// Set devcfg.INT_STS[PCFG_DONE_INT] to clear DONE bit
	reg_write32(DEVCFG_INT_STS_ADDRESS, DEVCFG_INT_STS_PCFG_DONE_INT_MASK);



	//iv-gmac
	reg_write32(LRPRF_AES_IV_REG0, to_little_endian(aead_file->nonce[0]));
	reg_write32(LRPRF_AES_IV_REG1, to_little_endian(aead_file->nonce[1]));
	reg_write32(LRPRF_AES_IV_REG2, to_little_endian(aead_file->nonce[2]));
	reg_write32(LRPRF_AES_IV_REG3, to_little_endian(aead_file->nonce[3]));

	// load iv gmac. Control Reg (7) = 1
	reg_write32(LRPRF_AES_CTRL_REG, LRPRF_AES_CTRL_LD_IV_MASK);

	//ret = poll_timeout(LRPRF_AES_STAT_REG , 0x4, 0x4, LRPRF_AES_POLLTIMEOUT);

	// Check if an error occured
	if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
		lrprf_aes_debug_print("Error: AES error [load nonce]\n\r");
		return 1;
	}
	// Check if a timout occured
	if (ret){
		lrprf_aes_debug_print("Error: AES timeout [load nonce]\n\r");
		return 1;
	}

	printf("dec_pr_bit: Nonce  loaded successfully\n\r");

	// input cipher text
	payload_blocks = aead_file->payload_length/16;
	printf("Payload blocks: %x\n\r",payload_blocks);
	for(j=0; j<payload_blocks; j++)
	{
		for(k=0; k<4; k++)
		{
			reg_write32(LRPRF_AES_BASEADDRESS+IN_OFFSET+4*k,to_little_endian(*((u32*)payload_pos)));
			payload_pos += 4;
		}
		reg_write32(LRPRF_AES_BASEADDRESS+CONTROL_OFFSET, 0x03);
		//busy flag
		ret = poll_timeout(LRPRF_AES_STAT_REG , 0x4, 0x4, LRPRF_AES_POLLTIMEOUT);
		// Check if an error occured
		if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
			lrprf_aes_debug_print("Error: AES error [decryption]\n\r");
			return 1;
		}
		// Check if a timout occured
		if (ret){
			lrprf_aes_debug_print("Error: AES timeout [decryption]\n\r");
			return 1;
		}

	}
		printf("Decryption complete \n\r");
	if (reg_read32(DEVCFG_INT_STS_ADDRESS) & DEVCFG_INT_STS_PCFG_DONE_INT_MASK){
		// Configuration was successful
		lrprf_aes_debug_print("Done bit set \n\r");
		return 0;
	}else{
		// DONE bit is not set. Indicates a problem during configuration.
		lrprf_aes_debug_print("Error: DONE bit not set \n\r");
		return 1;
	}
	//return 0;
}

int lrprf_aes_load_key(uint32_t mask){
	int ret;

	// load key. control reg (6) = 1
	reg_write32(LRPRF_AES_CTRL_REG, mask);
	ret = poll_timeout(LRPRF_AES_STAT_REG, LRPRF_AES_STAT_BUSY_MASK, 0, LRPRF_AES_POLLTIMEOUT);

	// Check if AES is not busy and no error occured
	if (ret == 0){
		return 0;
	} else if (reg_read32(LRPRF_AES_STAT_REG) & LRPRF_AES_STAT_ERROR_MASK){
		printf("Error: AES error during key load\n\r");
		return 1;
	} else {
		printf("Error: AES timeout during key load\n\r");
		return 1;
	}
}



int lraead_print_encfile(lraead_encfile *aead_file){

	u32 aad_words, aad_words_print;
	int i, block, block_length_in_16bytes;
	uint8_t* data_rd_ptr;
	uint32_t aad_pad_len,aad_len;

	printf("Content of encrypted file at address 0x%08x:\n\r", aead_file);
	printf("   Nonce:                     0x");
	for (i = 0; i < 16; i++){
		printf("%02x", ((uint8_t*)(aead_file->nonce))[i]);
		if (!((i+1)%4)){
			printf(" ");
		}
	}
	printf("\n\r");
	printf(" Tag:                       0x");
	for (i = 0; i < 16; i++){
		printf("%02x", ((uint8_t*)(aead_file->tag))[i]);
		if (!((i+1)%4)){
			printf(" ");
		}
	}
	printf("\n\r");
	printf("   AAD length :        %08x\n\r", aead_file->aad_length);

	if(aead_file->aad_length != 0){
		printf("   AAD:   0x");
		for (i = 0; i < aead_file->aad_length; i++){
			printf("%02x", (aead_file->aad)[i]);
		}
		printf("\n\r");
		// printf("AAD present:%08x\n\r", aead_file->aad);
		// aad_words = aead_file->aad_length;
	}
	else{
		printf("no AAD\n\r");	
		aad_words= 0;
	}
	printf("   Payload length:        %08x\n\r", aead_file->payload_length);
		printf(" PAyload 16bytes: 0x");
		for (i = 0; i < 16; i++){
			printf("%02x", (aead_file->payload)[i]);
		}
		printf("\n\r");


	return 0;
}
