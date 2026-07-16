import 'package:win32/win32.dart';

void main() {
  PCWSTR? x;
  CreateNamedPipe(x!, 0, 0, 0, 0, 0, 0, null);
}
