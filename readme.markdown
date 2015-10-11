# NetDebug

This is a network debugging application, which supports the following operations:

- Ping, which is used for determining if a target network location exists.
- Trace, which is used for tracing all the intermediate routing stations between the localhost and the target network location.

Both of the these operations accept as a target network location an IP address or a fully qualified domain name (FQDN).

Examples of IP addresses and their FQDN are listed bellow:

- 216.58.208.36 (www.google.com)
- 199.59.149.198 (www.twitter.com)
- 31.13.90.17 (www.facebook.com)

Instructions for using the application:

- Perform a ping operation
	1. Set a network target, i.e. www.google.com or 127.0.0.1.
	2. Set preferred packet size (must be between 8 and 64760 and a power of 2).
	3. Set preferred number of packets to be used.
	4. Press the start button (in case there is no response there is a timeout of at least 15s, which grows depending on the number of packets).
	5. If the operation succeeds, then press the save button to save it.
	6. Go to the archive tab and tap on the operation to see it.
    
- Perform a trace operation

	1. Set a network target, i.e. www.google.com or 127.0.0.1.
	2. Set preferred packet size (must be between 8 and 64760 and a power of 2).
	3. Set preferred number of packets to be used.
	4. Press the start button and wait (it takes considerable time to finish).
	5. If the operation succeeds, then press the save button to save it.
	6. Go to the archive tab and tap on the operation to see it.
    
- Archive

	- The operations are grouped according to their type and inside the group are sorted according to their creation date. 
	- The archived operations can be deleted by sliding on them from right to left.

The application follows the MVC pattern. The structures of the application are categorised bellow according to the MVC pattern:

- Model (the most complicated part of the application, which holds everything together - check the pseudocode of the ping operation  [DataModel performPingOperationWith:numberOfPackets:packetSizeInBytes:delegate:] and trace operation [DataModel performTraceOperationWith:numberOfPackets:packetSizeInBytes:delegate:])
	- DataModel
	- DataModelDelegateProtocol
	- DataModelOperationType

	- Ping algorithm (it is fully explained in PingAlgorithm overview - the heart of this application)
		- PingAlgorithm
		- PingAlgorithmDelegateProtocol
		- PingAlgorithmICMPType

	- CoreData objects (no functionality - nothing to see)
		- PingResponse
		- PingOperation
		- TraceOperation

- ViewControllers (all methods and parameters are hidden - nothing to see)
	- PingViewController
	- PingInfoViewController
	- TraceViewController
	- TraceInfoViewController
	- ArchiveViewController


