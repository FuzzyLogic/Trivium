import os

fd = os.open("/proc/axi_trivium", os.O_RDWR)
os.write(fd, b'\xd0\xa5\xb8\xb5\xbb\x4a\xc3\x75\x62\xea')
os.write(fd, b'\x9f\x71\x9b\x04\xbd\x20\xca\x4a\xe6\x00')
os.write(fd, b'\xf3\x3a\xea\xc3')
ct = os.read(fd, 4)
#print(" ".join(hex(ord(n)) for n in str(ct)))
print(ct)
os.close(fd)