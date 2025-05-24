import 'dart:async';
import 'package:hackcraft/src/hackcraft_client.dart';

Future<void> main() async {
  // プレイヤーを生成
  final player = Player('your name');

  // サーバーにログイン
  await player.login('localhost', 25570);

  // エンティティを取得
  final hello = await player.getEntity('your pet');

  // メッセージを送信
  await hello.say('hello world');

  // ログアウト
  await player.logout();
}
