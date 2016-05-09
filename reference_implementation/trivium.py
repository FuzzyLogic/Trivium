import sys
from collections import deque
from random import randint

def hexToBitList(hexStr):
    binStr = list()
    for char in hexStr:
        binStr += list(hexNibbleToBitList(char))
    return binStr[::-1]
		
def hexNibbleToBitList(hexNibble):
    if hexNibble == '0':
        return [0, 0, 0, 0]
    elif hexNibble == '1':
        return [0, 0, 0, 1] 
    elif hexNibble == '2':
        return [0, 0, 1, 0] 
    elif hexNibble == '3':
        return [0, 0, 1, 1] 
    elif hexNibble == '4':
        return [0, 1, 0, 0] 
    elif hexNibble == '5':
        return [0, 1, 0, 1] 
    elif hexNibble == '6':
        return [0, 1, 1, 0] 
    elif hexNibble == '7':
        return [0, 1, 1, 1] 
    elif hexNibble == '8':
        return [1, 0, 0, 0] 
    elif hexNibble == '9':
        return [1, 0, 0, 1] 
    elif hexNibble == 'a':
        return [1, 0, 1, 0] 
    elif hexNibble == 'b':
        return [1, 0, 1, 1] 
    elif hexNibble == 'c':
        return [1, 1, 0, 0] 
    elif hexNibble == 'd':
        return [1, 1, 0, 1] 
    elif hexNibble == 'e':
        return [1, 1, 1, 0] 
    elif hexNibble == 'f':
        return [1, 1, 1, 1] 
    else:
        return [0, 0, 0, 0]
        
def bitListToHex(bitList):
    hexStr = ""
    for i in range(0, len(bitList), 4):
        hexStr = bitListToHexNibble([bitList[i + 3], bitList[i + 2], bitList[i + 1], bitList[i]]) + hexStr
    
    return hexStr
    
def bitListToHexNibble(bitList):
    if bitList == [0, 0, 0, 0]:
        return '0'
    elif bitList == [0, 0, 0, 1]:
        return '1'
    elif bitList == [0, 0, 1, 0]:
        return '2' 
    elif bitList == [0, 0, 1, 1]:
        return '3'
    elif bitList == [0, 1, 0, 0]:
        return '4'
    elif bitList == [0, 1, 0, 1]:
        return '5' 
    elif bitList == [0, 1, 1, 0]:
        return '6' 
    elif bitList == [0, 1, 1, 1]:
        return '7' 
    elif bitList == [1, 0, 0, 0]:
        return '8' 
    elif bitList == [1, 0, 0, 1]:
        return '9' 
    elif bitList == [1, 0, 1, 0]:
        return 'a' 
    elif bitList == [1, 0, 1, 1]:
        return 'b' 
    elif bitList == [1, 1, 0, 0]:
        return 'c' 
    elif bitList == [1, 1, 0, 1]:
        return 'd' 
    elif bitList == [1, 1, 1, 0]:
        return 'e' 
    elif bitList == [1, 1, 1, 1]:
        return 'f' 
    else:
        return '0'
    
class Trivium:
    def __init__(self, key, iv):
        self.state = None

        # Initialize register A
        initRegs = key
        initRegs += list([0]*13)
		
		# Initialize register B
        initRegs += iv
        initRegs += list([0]*4)

		# Initialize register C and create deque
        initRegs += list([0]*108)
        initRegs += list([1, 1, 1])
        
        # Create the state using a deque (as it has a rotation method)
        self.state = deque(initRegs)

        # Warm-up phase, which includes 4 full cycles of the state
        for i in range(1152):
            self.genKeystream()

    # Encrypt a given message based on the current state of the cipher
    def encrypt(self, pt):
        ct = []
        for ptBit in pt:
            keyStreamBit = self.genKeystream()
            ct.append(ptBit ^ keyStreamBit)
            
        return ct

    # Generate the Trivium key stream
    def genKeystream(self):
        t1 = self.state[65] ^ self.state[92]
        t2 = self.state[161] ^ self.state[176]
        t3 = self.state[242] ^ self.state[287]
		
        a1 = self.state[90] & self.state[91]
        a2 = self.state[174] & self.state[175]
        a3 = self.state[285] & self.state[286]

        zi = t1 ^ t2 ^ t3

        s1 = t1 ^ a1 ^ self.state[170]
        s2 = t2 ^ a2 ^ self.state[263]
        s3 = t3 ^ a3 ^ self.state[68]

        self.state.rotate(1)

        self.state[0] = s3
        self.state[93] = s1
        self.state[177] = s2

        # Return key stream bit
        return zi


def main():
    inFile = open("trivium_ref_in.txt", "w")
    outFile = open("trivium_ref_out.txt", "w")
    numTests = 10
    
    # Generate reference I/O for specified number of tests
    for testNum in range(numTests):
        # Generate and output random key and IV
        keyStr = ''
        ivStr = ''
        for i in range(10):
            # Generate individual random bytes for key and IV
            keyStr += hex(randint(0, 255))[2:]
            ivStr += hex(randint(0, 255))[2:]
        
        keyStr = keyStr.zfill(20)
        ivStr = ivStr.zfill(20)
        inFile.write(keyStr + "\n")
        inFile.write(ivStr + "\n")
        
        # Initialize the cipher
        key = hexToBitList(keyStr)
        iv = hexToBitList(ivStr)
        trivium = Trivium(key, iv)

        # Determine random number of 32-bit words to encrypt
        numWords = randint(10, 100)

        for i in range(numWords):
            # Generate random 32-bit data word and write to output
            curWord = ''
            for j in range(4):
                # Generate random byte
                curWord += hex(randint(0, 255))[2:]
        
            curWord = curWord.zfill(8);
            inFile.write(curWord + "\n")
        
            # Encrypt the data and write the resulting 32-bit ciphertext to output
            outFile.write(bitListToHex(trivium.encrypt(hexToBitList(curWord))).zfill(8) + "\n")

        # Indicate end of current test via "-"
        inFile.write("-\n")
        outFile.write("-\n")
        
    # Indicate end of all test data via "."
    inFile.write(".\n")
    outFile.write(".\n")
    inFile.close()
    outFile.close()

if __name__ == "__main__":
    main()
