## Register File Depth = 256
## a - h (each have 32). Special a0 = Zero Register
## a: loop limits/constants
## b: counter variables
## c - h: general purpose registers
## LPU Count - 10

#Set up some variables
addi a0 a1 49 #a1 = 49 (50 time steps)
addi a0 a2 1 #a2 = increment variable
addi a0 a3 9 #LPU limit
addi a0 a4 15 #16 inputs
addi a0 a5 39 #40 self-inputs
addi a0 a6 10 #LPU/Neuron Offsetter
add a0 a0 b2 #Time step counter
addi a0 a7 41 #Weight mem indexer offset (for recurrent neurons)
add a0 a0 b3 #Input memory counter
add a0 a0 b4 #AN memory indexer
add a0 a0 b0 #b0 = LPU counter
add a0 a0 b1 #b1 = weight mem indexer
add a0 a0 a8 #a8 = LPU offsetter for recurrent weights
add a0 a0 b5 #b5 = Output AN Mem indexer
add a0 a0 b7 #b7 = LPU Iteration counter
addi a0 a9 3 #a9 = LPU Iteration Limit (4)
addi a0 a10 16 #a10 = Input Memory Offsetter
addi a0 a11 40 #a11 = Output neuron index
add a0 a0 h0 #h0 = Input Memory StartPoint


LPUIteration:
	source 0 #Input to LPUs from input memory
	sfunc 0 #Set LPUs to tanh activation function
	add a0 a0 b6 #Output LPU indexer
	add a0 a0 b0 #Reset the LPU counter
	add a0 h0 b3 #Set the input memory start point
LoadWeightsHiddenLayer:
	lw b1 b0 #Load from weightMem.b0 into LPU.b0
	add a2 b1 b1 #Increment the weight mem indexer
	beq b0 a3 LoadInputs #If weights have been loaded to all LPUs, start pushing inputs
	add a2 b0 b0 #Increment the LPU indexer
	jump LoadWeightsHiddenLayer
LoadInputs:
	la b3 #Load inputs from InputMem.b3 to all LPUs
	beq b3 a4 RecurrentInputCheck #Check if all inputs applied
	add a2 b3 b3 #Increment input counter
	jump LoadInputs
RecurrentInputCheck:
	beq a0 b2 WriteToANMem #If on time step zero, there are no recurrent inputs
	#Otherwise, change the input source to AN Mem
	source 1 #LPU Input Source = AN Mem
	add a0 a0 b4 #Reset the recurrent memory indexer to zero
	add a8 a7 b1 #Set the weight mem indexer to the weight mem offset WITH LPU offset
	add a0 a0 b0 #Reset the LPU counter
LoadRecurrentWeights:
	lw b1 b0 #Load weights from b1 (offset)
	add a2 b1 b1 #Increment weight mem indexer
	beq b0 a3 LoadRecurrentInputs #If weights have been loaded to all LPUs, start pushing inputs
	add a2 b0 b0 #Increment the LPU indexer
	jump LoadRecurrentWeights
LoadRecurrentInputs:
	la b4 #Load recurrent inputs from ANMem.b4 to all LPUs
	beq b4 a5 WriteToANMem #Check if all inputs applied
	add a2 b4 b4 #Increment input counter
	jump LoadRecurrentInputs
WriteToANMem:
	wm b6 b5 #Write LPUBank.b6 to ANMem.b5
	add a2 b5 b5 #Increment AN Mem dest. address
	beq b6 a3 LPUHandle #If all LPU outputs written to mem, go to LPU handling
	add a2 b6 b6 #Increment the LPU Counter
	jump WriteToANMem
LPUHandle:
	#Here, we check if we completed the LPU iterations
	beq b7 a9 TimeStepCheck
	add a2 b7 b7 #Increment the LPU Counter
	#Before jumping back to LPUIteration, need to offset the weight mem indexer
	#and increase the LPU Offsetter variable for when offsetting the weight mem values
	add a6 b1 b1 #b1 is now offset by 10
	beq a0 b2 SkipRecurrentOffsetter
	add a6 a8 a8 #a8 is now offset by 10
SkipRecurrentOffsetter:
	jump LPUIteration
TimeStepCheck:
	beq b2 a1 OutputLayer #If we processed 50 time steps, we are done with recurrent layer
	#If not, we increment the time step counter and jump back to TimeStepIteration
	add a2 b2 b2 #Increment time step counter
	add a10 h0 h0 #Input memory start point now at previous value + 16
	jump LPUIteration
OutputLayer:
	#For the output layer, we set the source to AN Memory
	source 1
	#Set the activation function of the LPUs to sigmoid
	sfunc 1
	#Load the weights from output neuron index to the zero-th LPU
	lw a11 a0
	#Reset the AN memory input counter
	add a0 a0 b4 #AN memory indexer
OutputLayerInputs:
	ls b4 a0 #Load from AnMem.b4 to LPU zero
	beq b4 a5 WriteOutput
	add a2 b4 b4 #Increment ANMem indexer
	jump OutputLayerInputs
WriteOutput:
	wm a0 a11 #Write the output from LPU Zero to AN memory address a11 (40)