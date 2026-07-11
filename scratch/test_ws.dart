import 'dart:io';
import 'dart:convert';

void main() async {
  final url = 'wss://commutas.onrender.com/ws/student/route/ROUTE-MURREE-REV';
  print('Connecting to $url...');
  try {
    final socket = await WebSocket.connect(url).timeout(Duration(seconds: 10));
    print('Connected successfully!');
    socket.listen((msg) {
      print('Received: $msg');
    }, onError: (err) {
      print('Stream error: $err');
    }, onDone: () {
      print('Stream closed');
    });
    
    // Wait for 5 seconds and exit
    await Future.delayed(Duration(seconds: 5));
    print('Closing socket...');
    await socket.close();
    print('Done!');
  } catch (e, s) {
    print('Error: $e');
    print(s);
  }
}
