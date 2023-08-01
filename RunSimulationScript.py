print("********************************************")
print("*                                          *")
print("*             TOSSIM Script                *")
print("*                                          *")
print("********************************************")

import sys
import time

import socket

from TOSSIM import *

NUM_OF_NODES = 9

t = Tossim([])


topofile = "topology.txt"
modelfile = "meyer-heavy.txt"


print("Initializing mac....")
mac = t.mac()
print("Initializing radio channels....")
radio = t.radio()
print("    using topology file:", topofile)
print("    using noise file:", modelfile)
print("Initializing simulator....")
t.init()


debug_outfile = "debug_files/debug_outfile.txt"
print("Saving simulation output to:", debug_outfile)
debug_out = open(debug_outfile, "w")

simulation_outfile = "debug_files/simulation.txt"
print("Saving simulation output to:", simulation_outfile)
simulation_out = open(simulation_outfile, "w")

node_red_file = "debug_files/node_red_outfile.txt"
print("Saving node red output to: ", node_red_file)
node_red_out = open(node_red_file, "w")


#out = sys.stdout

#Add debug channel
print("Activate debug message for 'debug' that will output to ", debug_outfile," general debug data")
t.addChannel("debug", debug_out)

print("Activate debug message for 'simulation' that will output to ", simulation_outfile," the useful simulation info")
t.addChannel("simulation", simulation_out)

print("Activate debug message for 'simulation' that will output to ", node_red_file," the useful simulation info")
t.addChannel("node_red", node_red_out)


bootTime = 0


for i in range(1, NUM_OF_NODES + 1):
    print("Creating node ", i, " ...")
    node = t.getNode(i)
    node.bootAtTime(bootTime)
    print(">>>Will boot at time",  bootTime, "[sec]")



print("Creating radio channels...")
f = open(topofile, "r")
lines = f.readlines()
for line in lines:
    s = line.split()
    if (len(s) > 0):
        print(">>>Setting radio channel from node", s[0], "to node", s[1], "with gain", s[2], "dBm")
        radio.add(int(s[0]), int(s[1]), float(s[2]))


#creation of channel model
print("Initializing Closest Pattern Matching (CPM)...")
noise = open(modelfile, "r")
lines = noise.readlines()
compl = 0
mid_compl = 0


print("Reading noise model data file:", modelfile)
print("Loading:")
for line in lines:
    str = line.strip()
    if (str != "") and ( compl < 10000 ):
        val = int(str)
        mid_compl = mid_compl + 1
        if ( mid_compl > 5000 ):
            compl = compl + mid_compl
            mid_compl = 0
            sys.stdout.write ("#")
            sys.stdout.flush()
        for i in range(1, NUM_OF_NODES + 1):
            t.getNode(i).addNoiseTraceReading(val)
print("Done!")


for i in range(1, NUM_OF_NODES + 1):
    print(">>>Creating noise model for node:", i)
    t.getNode(i).createNoiseModel()


print("Start simulation with TOSSIM! \n\n\n")


nextLine = 0

prevElapsedTime = 0


for i in range(0,100000):
	t.runNextEvent()
	
	with open(node_red_file, 'r') as NRfile:
	
		lines = NRfile.readlines()
	
		if lines and len(lines) > nextLine:
			
			sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
			
			sock.sendto(lines[nextLine], ("127.0.0.1", 1883))
			
			sock.close()
			
			nextLine += 1
	
	elapsedTime = float(t.time()) / float(t.ticksPerSecond())
	
	print(elapsedTime)
	
	time.sleep(elapsedTime - prevElapsedTime)
	
	prevElapsedTime = elapsedTime
	
	
print("\n\n\nSimulation finished!")