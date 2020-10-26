/*
 * Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V. 
 * acting on behalf of its Fraunhofer Institute AISEC. 
 * All rights reserved.
*/

#include <aisec_genlib.h>

int reg_write32(u32 addr, u32 data){
	volatile u32 *ptr;

	ptr = (u32*) addr;

	*ptr = data;

	return 0;
}


u32 reg_read32(u32 addr){
	volatile u32 *ptr;

	ptr = (u32*) addr;

	return *ptr;
}
