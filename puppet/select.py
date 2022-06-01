#with open("C:\\Users\\nvnjo\\Desktop\\mytext.txt.txt",mode='a') as f:
    #f.write('\n 3nd line')
import subprocess

with open("C:\\Users\\nvnjo\\Desktop\\mytext.txt.txt",mode='r') as f:
    for line in (f.readlines()):
        print(f'connect to {line}')
#subprocess.Popen(pwd)
list1 = [1,2,3,4,5,6,7,8,9,10]
for num in list1:
    if num % 2 != 0:
        print('Odd number {}'.format(num))
    else:
        print(f'Even number {num}')