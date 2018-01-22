def writeBit(data, location, value):
	value &= 1
	if value:
	 #we are setting a bit
	 return data | 1<<location
	else:
		return data & ~(1<<location)
		
def readBit(data, location):
	return (data >> location) & 1
	 
def encode(data, bias):
	data &= 0xFF
	
	numberOfOnes = 0
	for i in range(8):
		numberOfOnes += ((data >> i) & 1)
		
	if(numberOfOnes > 4) | ((numberOfOnes == 4) & ((data & 1) == 0)):
		useXNOR = 1
	else:
		useXNOR = 0
		
	outputData = data & 1 #output[0] = data[0]
	
	for i in range(1,8):
		outputData = writeBit(outputData, i, ((readBit(outputData, i-1) ^ readBit(data,i)) ^ useXNOR))
		
	outputData |= (~useXNOR << 8) & (1<<8)
	
	
	#print("{:010b}".format(outputData & 0x3FF))
	if oneCounter (outputData & 0xFF) == 4:
		#only 1 possible encoding for Data as no (positive/ negative bias version)
		outputData = writeBit(outputData, 9, ~readBit(outputData, 8))
		if readBit(outputData, 8) == 0:
			outputData ^= 0xFF
	else:
		if bias == 1:
			if oneCounter(outputData & 0xFF) > 4:
				outputData |= (1<<9)
				outputData ^= 0xFF
			else:
				pass
		else:
			if oneCounter(outputData & 0xFF) < 4:
				outputData |= (1<<9)
				outputData ^= 0xFF
			else:
				pass
	#print("{:010b}".format(outputData & 0x3FF))
	#print()
	return (data, outputData)
	
	
def oneCounter(data):
	data &= 0xFF
	sum = 0
	for i in range(8):
		sum += ((data >> i) & 1)
	return sum
	
	
		
if __name__ == "__main__":
	#generate()
	#encoder_test()
	valueList = []

	for i in range(256):
		for bias in (-1, 1):
			if encode(i, bias) not in valueList:
				valueList.append(encode(i,bias))
				
	assert len(valueList) == 460
	
	file = open("tmds_decoder.v", "w")
	file.write("case(in)\n")
	for i in valueList:
		file.write("\t10'b{:010b}: begin out = 8'b{:08b}; error = 0; end\n".format(i[1], i[0]))
	file.write("\tdefault: out = 8'b00000000; error = 1\n") 
	file.write("endcase")
	file.close()
	

	
	

	
	

	