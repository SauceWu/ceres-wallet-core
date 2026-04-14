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

  s.dependency 'Flutter'

  # Pre-built XCFramework (device + simulator, all deps merged: TrustWalletCore + protobuf + TrezorCrypto + Rust)
  # Built by: bash tool/build_native.sh ios
  # Packaged as dist/ios-xcframework.tar.gz by the CI workflow.
  s.vendored_frameworks = 'Frameworks/ceres_wallet_core.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
  }

  s.libraries = 'c++'
  s.frameworks = 'Security', 'Foundation'
end
