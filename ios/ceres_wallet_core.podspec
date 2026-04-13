Pod::Spec.new do |s|
  s.name             = 'ceres_wallet_core'
  s.version          = '0.0.1'
  s.summary          = 'Dart FFI bindings for Trust Wallet Core (ETH/SOL/SUI/TRX)'
  s.homepage         = 'https://github.com/ceresecosystem/ceres_wallet_core'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Ceres' => 'dev@ceresecosystem.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.static_framework = true

  s.dependency 'Flutter'

  # Pre-built static library (all deps merged: TrustWalletCore + protobuf + TrezorCrypto + Rust)
  # Built by: bash tool/build_native.sh ios
  s.vendored_libraries = 'Libraries/libCeresWalletCore.a'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
    # Force-load all symbols so Dart FFI can find TW* via DynamicLibrary.process()
    'OTHER_LDFLAGS' => '-force_load "${PODS_TARGET_SRCROOT}/Libraries/libCeresWalletCore.a"',
  }

  s.libraries = 'c++'
  s.frameworks = 'Security'
end
