'''
Author: Kartik Singhal
This assembler is capable of converting RISC-Pipelined ISA assembly instructions to binaries
Which can be fed to the memory of our processor using a bootloader

If filename.asm is to be assembled then
Command Format: python assembler.py <filename>
'''

import sys
binaries = ''

if __name__ == '__main__':
    params = sys.argv
    if(len(params) > 1):
        filename = params[1]
        with open(filename + '.asm', 'r') as t:
            code = t.readlines()
            # comment handler
            code = [i for i in code if i[0] != ';' or len(i) != 0]
            
            for i, j in enumerate(code):
                if ';' in j:
                    j = j.split(';')[0]
                    code[i] = j
            code = [i for i in code if i != '']
            for line in code:
                inst, args = line.split()[:2]
                args = args.split(',')

                # for instructions 1 through 8
                if(inst=="ada" or inst=="adc" or inst=="adz" or inst=="awc" 
                   or inst=="aca" or inst=="acc" or inst=="acz" or inst=="acw"):
                    binaries+="0001"
                    regs = ''
                    for i in args:
                        if i[0] == "r":
                            regs = bin(int(i[1]))[2:].zfill(3) + regs
                    
                    binaries += regs[3:6] + regs[:3] + regs[6:] # due to encoding being ra rb rc, asm being rc ra rb

                    # Placing the complement bit.
                    if (inst=="ada" or inst=="adc" or inst=="adz" or inst=="awc"):
                        binaries += "0"
                    else:
                        binaries += "1"

                    if (inst=="ada" or inst=="aca"):
                        binaries += "00"
                    elif (inst=="adc" or inst=="acc"):
                        binaries += "10"
                    elif (inst == "adz" or inst=="acz"):
                        binaries += "01"
                    else:
                        binaries += "11"

                # for instruction 9
                if(inst == "adi"):
                    binaries += "0000"
                    regs = ''
                    for i in args:
                        if i[0] == "r":
                            # as even in adi the order of ra and rb is reversed between assembly and machine code
                            regs = bin(int(i[1]))[2:].zfill(3) + regs
                        else:
                            binaries += regs
                            binaries += bin(int(i))[2:].zfill(6)

                # for instructions 10 through 15         
                if(inst == "ndu" or inst == "ndc" or inst == "ndz"
                   or inst == "ncu" or inst == "ncc" or inst == "ncz"):
                    binaries += "0010"
                    regs = ''
                    for i in args:
                        if i[0] == "r":
                            # this automatically reverses the order of the registers
                            regs = bin(int(i[1]))[2:].zfill(3) + regs
                    binaries += regs[3:6] + regs[:3] + regs[6:] # due to encoding being ra rb rc, asm being rc ra rb

                    if(inst == "ndu" or inst == "ndc" or inst == "ndz"):
                        binaries += "0"
                    else:
                        binaries += "1"

                    if(inst == "ndu" or inst=="ncu"):
                        binaries += "00"
                    elif (inst == "ndc" or inst=="ncc"):
                        binaries += "10"
                    elif (inst == "ndz" or inst=="ncz"):
                        binaries += "01"


                # instruction 16
                if(inst == "lli"):
                    binaries += "0011"
                    for i in args:
                        if i[0]=="r":
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        else:
                            binaries += bin(int(i))[2:].zfill(9)

                # instruction 17
                if(inst == "lw"):
                    binaries += "0100"
                    for i in args:
                        if i[0]=="r":
                            # directly appending to binaries as order is same for asm and encoding
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        else:
                            binaries += bin(int(i))[2:].zfill(6)

                # instruction 18
                if(inst == "sw"):
                    binaries += "0101"
                    for i in args:
                        if i[0] == "r":
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        else:
                            binaries += bin(int(i))[2:].zfill(6)

                # instruction 19
                if(inst == "lm"):
                    binaries += "0110"
                    for i in args:
                        if i[0] == "r":
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        else:
                            binaries += bin(int(i))[2:].zfill(9)
                
                # instruction 20
                if(inst == "sm"):
                    binaries += "0111"
                    for i in args:
                        if i[0] == "r":
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        else:
                            binaries += bin(int(i))[2:].zfill(9)

                # instruction 21
                if(inst == "beq"):
                    binaries += "1000"
                    for i in args:
                        if i[0] == "r":
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        else:
                            binaries += bin(int(i))[2:].zfill(6)
                
                # instruction 22
                if(inst == "blt"):
                    binaries += "1001"
                    for i in args:
                        if i[0] == "r":
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        else:
                            binaries += bin(int(i))[2:].zfill(6)
                
                # instruction 23
                if(inst == "ble"):
                    binaries += "1010"
                    for i in args:
                        if i[0] == "r":
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        else:
                            binaries += bin(int(i))[2:].zfill(6)

                # instruction 24
                if(inst == "jal"):
                    binaries += "1100"
                    for i in args:
                        if i[0] == "r":
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        else:
                            binaries += bin(int(i))[2:].zfill(9)

                # instruction 25
                if(inst == "jlr"):
                    binaries += "1101"
                    for i in args:
                        if i[0] == "r":
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        # always putting 6 zeros at the end
                        binaries += "000000"     

                # instruction 26               
                if(inst == "jri"):
                    binaries += "1111"
                    for i in args:
                        if i[0] == "r":
                            binaries += bin(int(i[1]))[2:].zfill(3)
                        else:
                            binaries += bin(int(i))[2:].zfill(9)                  
        
        with open('source.bin', 'w') as file:
            file.write(binaries)
        
        print("Assembled code successfully to /source.bin")
    else:
        print("No filename was passed")