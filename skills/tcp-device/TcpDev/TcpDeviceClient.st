(************************************************************************
 * Copyright: free to use and change (sample of github.com/jooansk/asmcp-skills)
 * Author: ASMCP skill tcp-device
 * Created: 2026-11-11
 * Description: TcpDeviceClient keeps a TCP connection to a device that
 *   speaks text lines (scanner, printer, vision sensor, robot, test PC):
 *   requests with answers, and lines the device sends by itself.
 *   Block comments only, so the library builds without IecExtendedComments.
 ************************************************************************)
FUNCTION_BLOCK TcpDeviceClient
	(* Inputs left at 0 take the library's defaults *)
	IF EndChar = 0 THEN
		LineEndChar := TCPDEV_LF;
	ELSE
		LineEndChar := EndChar;
	END_IF;
	IF AnswerTimeout = T#0s THEN
		UsedAnswerTimeout := TCPDEV_ANSWER_TIMEOUT;
	ELSE
		UsedAnswerTimeout := AnswerTimeout;
	END_IF;
	IF RetryDelay = T#0s THEN
		UsedRetryDelay := TCPDEV_RETRY_DELAY;
	ELSE
		UsedRetryDelay := RetryDelay;
	END_IF;

	NewLine := FALSE;
	(* A request's result stays while Send is TRUE, so a station's step can wait on it *)
	IF NOT Send AND NOT Busy THEN
		Done := FALSE;
		Error := FALSE;
	END_IF;

	DetectSend(CLK := Send);
	IF DetectSend.Q AND NOT Busy THEN
		Done := FALSE;
		Error := FALSE;
		IF State = tdCONNECTED THEN
			(* A copy: the caller may change Request while TcpSend still works on the text *)
			SendText := Request;
			SendPending := TRUE;
			Busy := TRUE;
		ELSE
			StatusID := TCPDEV_ERR_NOT_CONNECTED;
			Error := TRUE;
		END_IF;
	END_IF;

	CASE State OF
		tdIDLE:
			IF Enable THEN
				OpenSocket.enable := TRUE;
				State := tdOPEN;
			END_IF;

		tdOPEN:
			IF OpenSocket.status = ERR_OK THEN
				SocketIdent := OpenSocket.ident;
				OpenSocket.enable := FALSE;
				IF Enable THEN
					ConnectToDevice.enable := TRUE;
					State := tdCONNECT;
				ELSE
					CloseSocket.enable := TRUE;
					State := tdCLOSE;
				END_IF;
			ELSIF (OpenSocket.status <> ERR_FUB_BUSY) AND (OpenSocket.status <> ERR_FUB_ENABLE_FALSE) THEN
				(* No socket was created: nothing to close *)
				StatusID := OpenSocket.status;
				OpenSocket.enable := FALSE;
				State := tdWAIT_RETRY;
			END_IF;

		tdCONNECT:
			IF ConnectToDevice.status = ERR_OK THEN
				ConnectToDevice.enable := FALSE;
				IF Enable THEN
					RxLength := 0;
					PrevByte := 0;
					ReceiveData.enable := TRUE;
					State := tdCONNECTED;
				ELSE
					CloseSocket.enable := TRUE;
					State := tdCLOSE;
				END_IF;
			ELSIF (ConnectToDevice.status <> ERR_FUB_BUSY) AND (ConnectToDevice.status <> ERR_FUB_ENABLE_FALSE) THEN
				(* A failed connect leaves the socket unusable: close it and start again with a new one *)
				StatusID := ConnectToDevice.status;
				ConnectToDevice.enable := FALSE;
				CloseSocket.enable := TRUE;
				State := tdCLOSE;
			END_IF;

		tdCONNECTED:
			IF (ReceiveData.status = ERR_OK) AND (ReceiveData.recvlen > 0) THEN
				(* TCP is a byte stream: one block can hold part of a line or several lines *)
				ScanIdx := RxLength;
				RxLength := RxLength + ReceiveData.recvlen;
				LineStart := 0;
				WHILE ScanIdx < RxLength DO
					IF RxBuffer[ScanIdx] = LineEndChar THEN
						LineLength := ScanIdx - LineStart;
						IF (LineLength > 0) AND (PrevByte = TCPDEV_CR) THEN
							LineLength := LineLength - 1;
						END_IF;
						(* Answer keeps the last line; a longer line is cut to Answer's size *)
						brsmemset(ADR(Answer), 0, SIZEOF(Answer));
						brsmemcpy(ADR(Answer), ADR(RxBuffer) + LineStart, MIN(LineLength, SIZEOF(Answer) - 1));
						NewLine := TRUE;
						LineCount := LineCount + 1;
						IF WaitAnswer THEN
							WaitAnswer := FALSE;
							Busy := FALSE;
							Done := TRUE;
						END_IF;
						LineStart := ScanIdx + 1;
					END_IF;
					PrevByte := RxBuffer[ScanIdx];
					ScanIdx := ScanIdx + 1;
				END_WHILE;
				(* The start of the next line moves to the front of the buffer *)
				IF LineStart > 0 THEN
					brsmemmove(ADR(RxBuffer), ADR(RxBuffer) + LineStart, RxLength - LineStart);
					RxLength := RxLength - LineStart;
				END_IF;
				IF RxLength >= SIZEOF(RxBuffer) THEN
					StatusID := TCPDEV_ERR_OVERFLOW;
					RxLength := 0;
					IF WaitAnswer THEN
						WaitAnswer := FALSE;
						Busy := FALSE;
						Error := TRUE;
					END_IF;
				END_IF;
			ELSIF ReceiveData.status = ERR_OK THEN
				(* ERR_OK with nothing received: the device closed the connection *)
				StatusID := TCPDEV_ERR_CLOSED;
				ReceiveData.enable := FALSE;
				CloseSocket.enable := TRUE;
				State := tdCLOSE;
			ELSIF (ReceiveData.status <> tcpERR_NO_DATA) AND (ReceiveData.status <> tcpERR_WOULDBLOCK) AND (ReceiveData.status <> ERR_FUB_BUSY) AND (ReceiveData.status <> ERR_FUB_ENABLE_FALSE) THEN
				StatusID := ReceiveData.status;
				ReceiveData.enable := FALSE;
				CloseSocket.enable := TRUE;
				State := tdCLOSE;
			END_IF;

			IF State = tdCONNECTED THEN
				IF NOT Enable THEN
					ReceiveData.enable := FALSE;
					CloseSocket.enable := TRUE;
					State := tdCLOSE;
				ELSIF SendPending THEN
					SendPending := FALSE;
					ReceiveData.enable := FALSE;
					SendRequest.enable := TRUE;
					State := tdSEND;
				ELSIF WaitAnswer AND AnswerTimer.Q THEN
					(* The connection stays: a device that missed one request may answer the next *)
					StatusID := TCPDEV_ERR_TIMEOUT;
					WaitAnswer := FALSE;
					Busy := FALSE;
					Error := TRUE;
				END_IF;
			END_IF;

		tdSEND:
			IF SendRequest.status = ERR_OK THEN
				SendRequest.enable := FALSE;
				WaitAnswer := TRUE;
				ReceiveData.enable := TRUE;
				State := tdCONNECTED;
			ELSIF (SendRequest.status <> ERR_FUB_BUSY) AND (SendRequest.status <> ERR_FUB_ENABLE_FALSE) AND (SendRequest.status <> tcpERR_WOULDBLOCK) THEN
				(* tcpERR_SENTLEN, tcpERR_NOT_CONNECTED ...: the connection is unusable. tcpERR_WOULDBLOCK: enable stays TRUE, so the next call sends again *)
				StatusID := SendRequest.status;
				SendRequest.enable := FALSE;
				CloseSocket.enable := TRUE;
				State := tdCLOSE;
			END_IF;

		tdCLOSE:
			(* A request still open fails with the cause of the close *)
			IF Busy THEN
				Busy := FALSE;
				Error := TRUE;
			END_IF;
			SendPending := FALSE;
			WaitAnswer := FALSE;
			IF (CloseSocket.status <> ERR_FUB_BUSY) AND (CloseSocket.status <> ERR_FUB_ENABLE_FALSE) THEN
				(* Closed, or the socket was already gone: free either way *)
				SocketIdent := 0;
				CloseSocket.enable := FALSE;
				IF Enable THEN
					State := tdWAIT_RETRY;
				ELSE
					State := tdIDLE;
				END_IF;
			END_IF;

		tdWAIT_RETRY:
			IF NOT Enable THEN
				State := tdIDLE;
			ELSIF RetryTimer.Q THEN
				OpenSocket.enable := TRUE;
				State := tdOPEN;
			END_IF;
	END_CASE;

	(* Function block calls: each once per call, after the state machine *)
	OpenSocket(pIfAddr := 0, port := 0, options := 0);
	ConnectToDevice(ident := SocketIdent, pServer := ADR(ServerAddress), portserv := ServerPort);
	SendRequest(ident := SocketIdent, pData := ADR(SendText), datalen := brsstrlen(ADR(SendText)), flags := 0);
	ReceiveData(ident := SocketIdent, pData := ADR(RxBuffer) + RxLength, datamax := SIZEOF(RxBuffer) - RxLength, flags := 0);
	CloseSocket(ident := SocketIdent, how := 0);
	AnswerTimer(IN := WaitAnswer, PT := UsedAnswerTimeout);
	RetryTimer(IN := (State = tdWAIT_RETRY), PT := UsedRetryDelay);
	Connected := (State = tdCONNECTED) OR (State = tdSEND);
END_FUNCTION_BLOCK
