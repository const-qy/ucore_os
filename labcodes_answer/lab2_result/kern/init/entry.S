#include <mmu.h>
#include <memlayout.h>

#define REALLOC(x) (x - KERNBASE)

.text
.globl kern_entry


kern_entry:
    # load pa of boot pgdir //������ʱ����ҳĿ¼��ҳ�������Ǵ洢�����أ�
    movl $REALLOC(__boot_pgdir), %eax
    movl %eax, %cr3

    # enable paging  //ʹ�ܷ�ҳ����
    movl %cr0, %eax
    orl $(CR0_PE | CR0_PG | CR0_AM | CR0_WP | CR0_NE | CR0_TS | CR0_EM | CR0_MP), %eax
    andl $~(CR0_TS | CR0_EM), %eax
    movl %eax, %cr0

    # update eip
    # now, eip = 0x1.....
    leal next, %eax
    # set eip = KERNBASE + 0x1.....
    jmp *%eax
next:

    # unmap va 0 ~ 4M, it's temporary mapping
    xorl %eax, %eax
    movl %eax, __boot_pgdir

    # set ebp, esp
    movl $0x0, %ebp
    # the kernel stack region is from bootstack -- bootstacktop,
    # the kernel stack size is KSTACKSIZE (8KB)defined in memlayout.h
    movl $bootstacktop, %esp
    # now kernel stack is ready , call the first C function
    call kern_init

# should never get here
spin:
    jmp spin

.data
.align PGSIZE
    .globl bootstack
bootstack:
    .space KSTACKSIZE #0x38000000 
    .globl bootstacktop
bootstacktop:

# kernel builtin pgdir
# an initial page directory (Page Directory Table, PDT)
# These page directory table and page table can be reused!
.section .data.pgdir
.align PGSIZE
__boot_pgdir:
.globl __boot_pgdir
   # ����������ҳĿ¼��
    # map va 0 ~ 4M to pa 0 ~ 4M (temporary)
	# 0~4M =>  0x00000000~0x00400000,ͨ�������֪��ʮλΪ0����ҳĿ¼�ĵ�һ��ҳĿ¼�
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
	#��ҳĿ¼�������䣬
    .space (KERNBASE >> PGSHIFT >> 10 << 2) - (. - __boot_pgdir) # pad to PDE of KERNBASE
	# 0xC0000000~0xC040000,�����ʮλΪ0x300
    # map va KERNBASE + (0 ~ 4M) to pa 0 ~ 4M
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    .space PGSIZE - (. - __boot_pgdir) # pad to PGSIZE

.set i, 0
__boot_pt1:# һҳ��������ӳ��4M,ͨ��ѭ����������ռ䵽�����ռ�ĶԵ�ӳ�䣬ucore�洢��������ַ1M��ʼ�ĵط���
.rept 1024
    .long i * PGSIZE + (PTE_P | PTE_W)
    .set i, i + 1
.endr
#0xC0000000 =>3GB 