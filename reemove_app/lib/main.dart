import 'bootstrap.dart';
import 'core/config/app_environment.dart';

Future<void> main() async {
  await bootstrap(AppEnvironment.fromCompileTime());
}
