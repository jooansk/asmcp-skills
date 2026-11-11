
TYPE
	TcpDevStateEnum :
		( (*Steps of TcpDeviceClient*)
		tdIDLE := 0, (*Enable is FALSE, no socket*)
		tdOPEN := 10, (*TcpOpen creates the socket*)
		tdCONNECT := 20, (*TcpClient connects to the device*)
		tdCONNECTED := 30, (*Receives lines; sends a request when one waits*)
		tdSEND := 40, (*TcpSend sends the request*)
		tdCLOSE := 50, (*TcpClose frees the socket*)
		tdWAIT_RETRY := 60 (*Pause before the next connection attempt*)
		);
END_TYPE
