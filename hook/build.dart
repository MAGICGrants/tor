import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

import 'prebuilt.dart';

/// Build time recorded by the vendored OpenSSL (`OPENSSL_BUILT_ON`). Any fixed
/// value makes the build reproducible; this is the native-0.2.0 commit time.
const _sourceDateEpoch = '1792525146';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    if (await usePrebuilt(input, output)) return;

    output.dependencies.addAll(await sourceDependencies(input.packageRoot));

    await RustBuilder(
      assetName: 'tor_ffi_plugin_bindings_generated.dart',
      extraCargoBuildArgs: const ['--locked'],
      extraCargoEnvironmentVariables: reproducibleEnvironment(),
    ).run(input: input, output: output);
  });
}

/// Keeps the build machine out of the library's bytes.
///
/// Flutter runs hooks with an allowlisted environment, so a caller's
/// SOURCE_DATE_EPOCH, CARGO_HOME and RUSTFLAGS never reach cargo. OpenSSL then
/// records the wall-clock time, and cargo falls back to `$HOME/.cargo`, whose
/// absolute path ends up in the panic locations of every registry crate.
Map<String, String> reproducibleEnvironment() {
  final env = Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE'];
  final cargoHome =
      env['CARGO_HOME'] ??
      (home == null ? null : '$home${Platform.pathSeparator}.cargo');
  return {
    'SOURCE_DATE_EPOCH': _sourceDateEpoch,
    if (cargoHome != null)
      'CARGO_ENCODED_RUSTFLAGS': '--remap-path-prefix=$cargoHome=/cargo',
  };
}
