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
  for (var i = 0; i < 5; i++) {
    await hello.digDown();
    await hello.dig();
    await hello.forward();
    await hello.digUp();
    await hello.digUp();
  }

  // ログアウト
  await player.logout();
}
