# PasskeyEvmSigner 实现计划

## 背景

`ceres_wallet_core` 已有 `TWWebAuthn`（3 个静态方法），覆盖了 P-256 passkey 的全部密码学原语：
- `getPublicKey(attestationObject)` — 注册阶段提取公钥
- `reconstructOriginalMessage(authData, clientDataJSON)` — 重建被签名 message
- `getRSValues(derSignature)` — DER → 64 字节 r‖s（链上验签格式）

`PasskeyEvmSigner` 的任务是在此基础上实现 `EvmSigner` 接口，让 `ceres_wallet_dapp` 能把 passkey 账户当成普通 signer 使用。

---

## 架构定位

```
ceres_wallet_dapp
  └── EvmSigner（接口）
        ↑ 实现
ceres_wallet_core
  ├── CoreEvmSigner（现有，secp256k1 HD）
  ├── PasskeyEvmSigner（新增，P-256）← 本计划
  └── TWWebAuthn（已有，密码学原语）
        ↑ 依赖
passkeys 包（Flutter，调用平台原生 WebAuthn API）
```

---

## 依赖

```yaml
# pubspec.yaml 新增
dependencies:
  passkeys: ^2.0.0          # iOS/Android/macOS 平台 WebAuthn 调用
  # passkeys 包内部走：
  #   iOS/macOS → ASAuthorizationController
  #   Android  → Credential Manager API
```

---

## 实现拆分（4 步）

---

### Step 1：注册（Registration）

用户首次创建 passkey 账户时执行一次。

```dart
class PasskeyRegistration {
  /// 调用平台 WebAuthn API 创建 passkey
  /// 返回注册后的公钥（压缩 P-256 格式，33 bytes）
  static Future<PasskeyCredential> register({
    required String rpId,          // Relying Party ID，如 "ceres.wallet"
    required String userId,        // 用户唯一 ID（不显示给用户）
    required String userDisplayName,
  }) async {
    // 1. 调用 passkeys 包发起注册
    final attestation = await PasskeyAuthenticator().register(
      RegisterRequest(
        relyingPartyId: rpId,
        relyingPartyName: 'Ceres Wallet',
        userId: userId,
        name: userDisplayName,
      ),
    );

    // 2. 用 TWWebAuthn 从 attestationObject 提取 P-256 公钥
    final pubKeyBytes = TWWebAuthn.getPublicKey(
      Uint8List.fromList(base64Url.decode(attestation.attestationObject)),
    );

    // 3. 用 TWAnyAddress 派生以太坊地址（P-256 公钥 → keccak256 → 地址）
    //    注意：这个地址只能配合 SmartAccount 合约使用，EOA 不认 P-256
    final address = _deriveAddress(pubKeyBytes);

    return PasskeyCredential(
      credentialId: attestation.id,
      publicKey: pubKeyBytes,
      address: address,
      rpId: rpId,
    );
  }
}
```

---

### Step 2：PasskeyCredential 数据模型

```dart
@freezed
class PasskeyCredential with _$PasskeyCredential {
  const factory PasskeyCredential({
    required String credentialId,   // Base64url，平台存储的 key handle
    required Uint8List publicKey,   // 压缩 P-256 公钥，33 bytes
    required String address,        // 对应的 SmartAccount 地址（非 EOA）
    required String rpId,
  }) = _PasskeyCredential;

  factory PasskeyCredential.fromJson(Map<String, dynamic> json) =>
      _$PasskeyCredentialFromJson(json);
}
```

---

### Step 3：PasskeyEvmSigner 实现

```dart
/// P-256 passkey 签名器，对接 ceres_wallet_dapp 的 EvmSigner 接口。
/// 签名结果为 64 字节 r‖s，供 EIP-7212 / ERC-4337 链上合约验证。
class PasskeyEvmSigner implements EvmSigner {
  final PasskeyCredential _credential;
  final PasskeyAuthenticator _authenticator;

  PasskeyEvmSigner({
    required PasskeyCredential credential,
    PasskeyAuthenticator? authenticator,
  })  : _credential = credential,
        _authenticator = authenticator ?? PasskeyAuthenticator();

  @override
  String get address => _credential.address;

  // ── personal_sign ────────────────────────────────────────────────────────
  // 注意：passkey 签名结果是 P-256，链上必须通过 SmartAccount 验证，
  // 不能直接用于普通 EOA personal_sign 场景。
  @override
  Future<String> personalSign(Uint8List message) async {
    return _sign(message);
  }

  // ── signTypedDataV4 ──────────────────────────────────────────────────────
  @override
  Future<String> signTypedDataV4(String typedDataJson) async {
    // typed data hash 由调用方（或 ceres_wallet_onchain）提供
    // 这里接收已经 hash 好的 32 bytes digest
    final digest = _hashTypedData(typedDataJson);
    return _sign(digest);
  }

  // ── signTransaction ──────────────────────────────────────────────────────
  // passkey 不能直接签 EOA 交易，此方法只在 AA 路径下有意义
  // AA 路径下签的是 UserOperationHash（32 bytes）
  @override
  Future<String> signTransaction(EthTransaction tx) async {
    throw UnsupportedError(
      'PasskeyEvmSigner 只支持 AA（SmartAccount）路径，'
      '不能签 EOA 交易。请通过 UserOperationBuilder 构建 UserOp。',
    );
  }

  @override
  Future<bool> hasCapability(SignerCapability cap) async {
    return switch (cap) {
      SignerCapability.personalSign   => true,
      SignerCapability.signTypedData  => true,
      SignerCapability.signTransaction => false,  // AA 路径才支持
      SignerCapability.sendTransaction => false,
    };
  }

  // ── 核心签名逻辑 ─────────────────────────────────────────────────────────
  Future<String> _sign(Uint8List payload) async {
    // 1. 调用平台 WebAuthn API（触发 Face ID / 指纹 / PIN）
    final assertion = await _authenticator.authenticate(
      AuthenticateRequest(
        relyingPartyId: _credential.rpId,
        allowedCredentials: [_credential.credentialId],
        // challenge = payload 的 base64url（WebAuthn 规范要求）
        challenge: base64Url.encode(payload),
      ),
    );

    // 2. 用 TWWebAuthn 重建真正被签名的 message
    final signedMessage = TWWebAuthn.reconstructOriginalMessage(
      base64Url.decode(assertion.authenticatorData),
      base64Url.decode(assertion.clientDataJSON),
    );

    // 3. 提取 r‖s（64 bytes）
    final rs = TWWebAuthn.getRSValues(
      base64Url.decode(assertion.signature),
    );

    // 4. 返回十六进制字符串，格式：0x + r(32bytes) + s(32bytes)
    return '0x${hex.encode(rs)}';
  }
}
```

---

### Step 4：集成到 SmartAccount（AA）流程

`PasskeyEvmSigner` 不能独立完成链上交易，必须配合 SmartAccount 合约。

```
用户确认（Face ID）
    ↓
PasskeyEvmSigner.sign(userOpHash)
    ↓ 返回 r‖s（64 bytes）
UserOperationBuilder（ceres_wallet_aa，未来库）
    ↓ 组装 UserOperation.signature = r‖s
Bundler（eth_sendUserOperation）
    ↓
EntryPoint → SmartAccount.validateUserOp()
    ↓ 调 EIP-7212 P-256 预编译合约验签
    ✅ 通过，执行操作
```

**推荐 SmartAccount 实现：**
- **Barz**（TrustWallet 官方，与 TWWebAuthn 同源，首选）
- **Coinbase Smart Wallet**（原生支持 P-256）
- **Kernel + WebAuthn validator**（ZeroDev）

---

## 测试计划

| 测试 | 方式 |
|------|------|
| `TWWebAuthn` 三个方法的单元测试 | 用官方 WebAuthn test vector（CBOR 样本） |
| `PasskeyCredential` JSON 序列化 | 普通单元测试 |
| `PasskeyEvmSigner` 签名格式 | mock `PasskeyAuthenticator`，验证 r‖s 输出格式 |
| 链上验签 | 本地 Anvil fork + Barz 合约，发真实 UserOp |

---

## 注意事项

1. **`credentialId` 必须持久化**：用户下次开 app 需要用同一个 `credentialId` 发起 assertion，丢了就无法再签名。建议存 `flutter_secure_storage`。

2. **Passkey 同步**：iOS 通过 iCloud Keychain 自动同步到其他苹果设备；Android 通过 Google Password Manager。macOS 和 iOS 共用 iCloud Keychain，天然互通。

3. **`rpId` 必须一致**：注册和认证的 `rpId` 必须完全相同，且要与 app 的 Bundle ID / domain 绑定，否则平台会拒绝。

4. **降级方案**：建议 passkey 注册时同时允许用户设置备用的助记词账户，防止设备全部丢失时无法恢复。

---

## 工作量估算

| 步骤 | 估时 |
|------|------|
| passkeys 包接入 + 平台配置（iOS entitlements / Android assetlinks） | 1 天 |
| PasskeyCredential 模型 + 注册流程 | 0.5 天 |
| PasskeyEvmSigner 实现 | 1 天 |
| 单元测试 | 1 天 |
| 真机联调（Face ID） | 1 天 |
| **合计** | **~4-5 天** |

---

*计划编写：2026-04-29*
