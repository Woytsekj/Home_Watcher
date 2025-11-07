import 'package:http/http.dart' as http;
import 'dart:convert';

class HttpComms
{
  // This Works!
  static var uri = Uri(
    scheme: 'http',
    host: '3.149.184.208',
    path: '/send_command',
    port: 80
  );

  // Send command do not wait for response
  static Future<http.Response> sendCommand(String commandName) {
    print('Send Command: $commandName');
    return http.post(
      uri, 
      headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      }, 
      body: jsonEncode(<String, String>{'command': commandName}),);
  }

  // Send command, is protected from time outs
  static Future<http.Response> sendCommandProtected(String commandName) async {

    http.Response response;
    try
    {
      response = await sendCommand(commandName);

    }
    on Exception catch (e)
    {
      print("Exception in communication $e");
      response = http.Response(e.toString(), 666); 
    }

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    return response;

  }
}