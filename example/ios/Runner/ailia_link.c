//
//  ailia_link.c
//  Runner
//
//  Created by Kazuki Kyakuno on 2023/07/31.
//

#include "ailia_link.h"

extern void ailiaLLMDestroy(void* net);

// Dummy link to keep libailia.a from being deleted

void test(void){
    ailiaLLMDestroy(NULL);
}
