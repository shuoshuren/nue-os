.code16

.equ SYSSIZE ,0x3000 # System size in clicks
.global _start # 程序开始的地方

.equ SETUPLEN, 0x04 # setup 程序占用的扇区数
.equ BOOTSEG, 0x07c0 # 当此删除被BIOS识别到启动扇区，装载到内存时，装载到0x07c0段处
.equ INITSEG, 0x9000 #bootsect代码会移动到这里
.equ SETUPSEG, 0x9020 # setup.s代码会移动到这里
.equ SYSSEG, 0x1000 # system 程序转载的地址
.equ ROOT_DEV,0x301 #指定/dev/fda为系统镜像所在设备
.equ ENDSEG,SYSSEG+SYSSIZE


.text 

ljmp $BOOTSEG,$_start

_start:
    mov $BOOTSEG,%ax # 将启动扇区从0x07c0移动到0x9000处
    mov %ax,%ds
                    # rep mov用法：
                    # 原地址ds:si = 0x07c0:0000
                    # 目的地址es:di = 0x9000:0000
                    # 移动次数 %cx = 256
                    # 因为时movsw 所以每次移动一个word(2Byte) 256次即为启动扇区的大小

    mov $INITSEG,%ax
    mov %ax,%es
    mov $256,%cx
    xor %si,%si
    xor %di,%di
    rep movsw   # 进行移动

    ljmp $INITSEG,$go   #长跳转同时切换cs:ip

go:
    mov %cs,%ax     #对DS,ES,SS寄存器进行初始化
    mov %ax,%ds
    mov %ax,%es
    mov %ax,%ss
    mov $0xFF00,%sp #设置栈

load_setup:
    #将软盘的内容加载到内存，并且跳转到相应的地址执行代码
    mov $0x0000,%dx # 选择磁盘号0，磁头号0进行读取
    mov $0x0002,%cx #从二号扇区，0轨道开始读(扇区从1开始编号）
    mov $INITSEG,%ax # ES:Bx指向目的地址
    mov %ax,%es
    mov $0x0200,%bx 
    mov $02,%ah #servic 2: read disk sectors
    mov $4,%al #读取的扇区数
    int $0x13   #调用BIOS终端读取
    jnc setup_load_ok #没有异常，加载成功
    mov $0x0000,%dx
    mov $0x0000,%ax # server 0 :reset the disk
    int $0x13
    jmp load_setup # 一直重试，直到加载成功

setup_load_ok:
    # Jump to the demo program
    # mov $SETUPSEG,%ax
    # mov %ax,%ds
    
    # mov %ax,%cs
    # ljmp $0x1020,$0

    mov $0x00,%dl
    mov $0x0800,%ax
    int $0x13
    mov $0x00,%ch
    mov %cx,%cs:sectors+0
    mov $INITSEG,%ax
    mov %ax,%es

# 输出一行信息
print_msg:
    # Get cursor position
    mov $0x03, %ah
    xor %bh,%bh
    int $0x10 
	
    mov $20,%cx # set output length
    mov $0x0007,%bx # page 0,color=0x07
	mov $_string,%bp
	mov $0x1301, %ax # write string,move cursor
    int $0x10   # 使用中断0x10,输出内容是从es:bp中获取

# 接下来将整个系统镜像转载到0x1000:0000开始的内存中
    mov $SYSSEG,%ax
    mov %ax,%es
    call read_it
    call kill_motor

    mov %cs:root_dev,%ax
    cmp $0,%ax
    jne root_defined # root_dev !=0,defined root
    mov %cs:sectors+0,%bx #else check for the root dev
    mov $0x0208,%ax
    cmp $15,%bx
    je root_defined # sector = 15,1.2Mb floopy driver
    mov $0x021c,%ax
    cmp $18,%bx # sector = 18 1.44mb floopy driver
    je root_defined

undef_root:
    jmp undef_root

root_defined:
    mov %ax,%cs:root_dev+0
# 所有的内容都加载到内存中，现在跳转到setup-routine(0x9020:0000)
    ljmp $SETUPSEG,$0

# read_it 和kill_motor 两个子函数，用来读取软盘中的内容和关闭软驱使用
# 定义变量，用于读取软盘信息

sread: .word 1+SETUPLEN # 当前轨道读取的扇区数
head: .word 0 #当前读头
track: .word 0 #当前轨道

read_it:
    mov %es,%ax
    test $0x0FFF,%ax

die:
    jne die # if es not at 64KB(0x1000) Boundary,then stop here
    xor %bx,%bx
rp_read:
    mov %es,%ax
    cmp $ENDSEG,%ax
    jb ok1_read # if $ENDSEG > %ES ,then continue reading,else just return
    ret

ok1_read:
    mov %cs:sectors+0,%ax
    sub sread,%ax
    mov %ax,%cx # calculate how much sectors left read
    shl $9,%cx # cx = cx * 512B
    add %bx,%cx # current bytes read in now
    jnc ok2_read    # if not bigger than 64K ,continue to ok_2
    je ok2_read
    xor %ax,%ax
    sub %bx,%ax
    shr $9,%ax

ok2_read:
    call read_track
    mov %ax,%cx # cx = num of sectord read so far
    add sread,%ax
    
    cmp %cs:sectors+0,%ax
    jne ok3_read
    mov $1,%ax
    sub head,%ax
    jne ok4_read
    incw track

ok4_read:
    mov %ax,head
    xor %ax,%ax
ok3_read:
    mov %ax,sread
    shl $9,%cx
    add %cx,%bx # Erro
    jnc rp_read # if shorter than 64K,then read the data again,else ,adjust ES to next 64K,then read again
    mov %es,%ax
    add $0x1000,%ax
    mov %ax,%es # change the segment to next 64KB
    xor %bx,%bx
    jmp rp_read


read_track:
    # this routine do the actual read
    push %ax
    push %bx
    push %cx
    push %dx
    mov track,%dx # set the track number $track,disk number 0
    mov sread,%cx
    inc %cx
    mov %dl,%ch
    mov head,%dx
    mov %dl,%dh
    mov $0,%dl
    and $0x0100,%dx
    mov $2,%ah
    int $0x13
    jc bad_rt
    pop %dx
    pop %cx
    pop %bx
    pop %ax
    ret

bad_rt:
    mov $0,%ax
    mov $0,%dx
    int $0x13
    pop %dx
    pop %cx
    pop %bx
    pop %ax
    jmp read_track

kill_motor:
    push %dx
    mov $0x3f2,%dx
    mov $0,%al
    outsb
    pop %dx
    ret

sectors:
    .word 0



_string:
	.ascii "Hello Bootloader!"
	.byte 13,10,13,10
.= 508

root_dev:
    .word ROOT_DEV



signature:
	.word 0xaa55
