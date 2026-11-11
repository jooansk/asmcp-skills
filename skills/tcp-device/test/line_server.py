"""Line server for testing TcpDeviceClient on ARsim (sample skill tcp-device).

Answers every line it receives with "ACK <line>" (CR LF), greets each new connection with "HELLO",
and with --tick N sends an unsolicited "TICK <n>" every N seconds. Python 3, standard library only.

    python line_server.py                      # 127.0.0.2:12000
    python line_server.py --port 2001 --tick 5
    python line_server.py --silent             # never answers: tests the answer timeout

127.0.0.2 is a loopback address of its own: an ARsim on 127.0.0.1 reaches it, and both may use the same port.
Stop with Ctrl+C.
"""
import argparse
import socket
import threading
import time


def serve_client(conn, addr, args):
    print(f"connected: {addr[0]}:{addr[1]}")
    stop = threading.Event()

    def tick():
        n = 0
        while not stop.wait(args.tick):
            n += 1
            conn.sendall(f"TICK {n}\r\n".encode())

    if args.tick > 0:
        threading.Thread(target=tick, daemon=True).start()
    try:
        conn.sendall(b"HELLO\r\n")
        pending = b""
        while True:
            data = conn.recv(1024)
            if not data:
                break
            pending += data
            while b"\n" in pending:
                line, pending = pending.split(b"\n", 1)
                text = line.rstrip(b"\r").decode(errors="replace")
                print(f"<- {text}")
                if not args.silent:
                    time.sleep(args.delay)
                    conn.sendall(f"ACK {text}\r\n".encode())
    except OSError as e:
        print(f"connection error: {e}")
    finally:
        stop.set()
        conn.close()
        print("disconnected")


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--host", default="127.0.0.2")
    p.add_argument("--port", type=int, default=12000)
    p.add_argument("--tick", type=float, default=0, help="seconds between unsolicited TICK lines (0 = none)")
    p.add_argument("--delay", type=float, default=0.05, help="seconds before each answer")
    p.add_argument("--silent", action="store_true", help="never answer")
    args = p.parse_args()
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as srv:
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind((args.host, args.port))
        srv.listen()
        print(f"listening on {args.host}:{args.port}")
        while True:
            conn, addr = srv.accept()
            threading.Thread(target=serve_client, args=(conn, addr, args), daemon=True).start()


if __name__ == "__main__":
    main()
