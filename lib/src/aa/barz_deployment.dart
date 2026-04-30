/// Deployment registry for Barz smart-account factory infrastructure.
///
/// AA-07 / AA-08 / AA-09: Supplies per-chain deployment addresses for
/// [PasskeyBarzAddress.compute] and [BarzInitCode.forPasskey].
///
/// All six canonical chains (ETH mainnet, Sepolia, Base, Arbitrum, Optimism,
/// Polygon) use identical addresses because the contracts were deployed via
/// CREATE2 with the same deployer salt across all chains.
///
/// **Address sources (verified 2026-04-29):**
/// - `deployments/<chain>/BarzFactory.json` in trustwallet/barz repo
/// - `deployments/<chain>/Secp256r1VerificationFacet.json` in same repo
/// - `factory.getCreationCode()` via `eth_call` to mainnet factory
library;

/// Immutable value object capturing the on-chain deployment addresses needed
/// to compute Barz smart-account addresses and build ERC-4337 initCode.
///
/// One instance per chain. Use [BarzDeployments.byChainId] for lookup or the
/// named constants (e.g. [BarzDeployments.mainnet]).
final class BarzDeployment {
  /// Creates an immutable deployment descriptor.
  const BarzDeployment({
    required this.chainId,
    required this.factory,
    required this.verificationFacet,
    required this.accountFacet,
    required this.facetRegistry,
    required this.defaultFallback,
    required this.entryPointV06,
    required this.entryPointV07,
    required this.barzCreationCodeHex,
  });

  /// EIP-155 chain ID.
  final int chainId;

  /// BarzFactory contract address (0x-prefixed, mixed-case checksum).
  final String factory;

  /// Secp256r1VerificationFacet address — the passkey verification facet.
  final String verificationFacet;

  /// AccountFacet address (first constructor arg of BarzFactory).
  final String accountFacet;

  /// FacetRegistry address (third constructor arg of BarzFactory).
  final String facetRegistry;

  /// DefaultFallbackHandler address (fourth constructor arg of BarzFactory).
  final String defaultFallback;

  /// ERC-4337 EntryPoint v0.6 address (second constructor arg of BarzFactory).
  final String entryPointV06;

  /// ERC-4337 EntryPoint v0.7 address (used by [Erc4337Builder.v07]).
  final String entryPointV07;

  /// Barz contract creation code (0x-prefixed hex string).
  ///
  /// Equals `type(Barz).creationCode` as returned by
  /// `BarzFactory.getCreationCode()` on-chain. Used in
  /// [PasskeyBarzAddress.compute] for the round-trip CREATE2 verification
  /// (path B — pure-Dart ABI encoding + keccak256 + EIP-1014 create2Address).
  final String barzCreationCodeHex;

  @override
  String toString() => 'BarzDeployment(chainId: $chainId, factory: $factory)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarzDeployment &&
          runtimeType == other.runtimeType &&
          chainId == other.chainId &&
          factory == other.factory;

  @override
  int get hashCode => Object.hash(chainId, factory);
}

/// Pre-built registry of canonical Barz deployment addresses.
///
/// All chains share identical contract addresses (CREATE2 determinism):
/// - BarzFactory:                 `0x729c310186a57833f622630a16d13f710b83272a`
/// - Secp256r1VerificationFacet:  `0xeE1AF8E967eC04C84711842796A5E714D2FD33e6`
/// - AccountFacet:                `0xFde53272dcd7938d16E031A6989753c321728332`
/// - FacetRegistry:               `0xAfCb70e6e9514E2A15B23A01d2a9b9f7A34f2c33`
/// - DefaultFallbackHandler:      `0x2e7f1dAe1F3799d20f5c31bEFdc7A620f664728D`
/// - EntryPoint v0.6:             `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789`
/// - EntryPoint v0.7:             `0x0000000071727De22E5E9d8BAf0edAc6f37da032`
abstract final class BarzDeployments {
  // ── Shared constants (identical across all canonical chains) ──────────────

  static const String _factory =
      '0x729c310186a57833f622630a16d13f710b83272a';
  static const String _verificationFacet =
      '0xeE1AF8E967eC04C84711842796A5E714D2FD33e6';
  static const String _accountFacet =
      '0xFde53272dcd7938d16E031A6989753c321728332';
  static const String _facetRegistry =
      '0xAfCb70e6e9514E2A15B23A01d2a9b9f7A34f2c33';
  static const String _defaultFallback =
      '0x2e7f1dAe1F3799d20f5c31bEFdc7A620f664728D';
  static const String _entryPointV06 =
      '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789';
  static const String _entryPointV07 =
      '0x0000000071727De22E5E9d8BAf0edAc6f37da032';

  /// `type(Barz).creationCode` from `BarzFactory.getCreationCode()` on mainnet.
  ///
  /// Retrieved 2026-04-29 via `eth_call` on mainnet factory
  /// `0x729c310186a57833f622630a16d13f710b83272a` selector `0x00c194db`.
  /// 1362 bytes. Identical across all chains (same factory bytecode / salt).
  static const String _barzCreationCodeHex =
      '0x608060405260405161055238038061055283398101604081905261002291610163565b60008585'
      '85858560405160240161003d959493929190610264565b60408051601f1981840301815291815260'
      '20820180516001600160e01b0316634a93641760e01b1790525190915060009081906001600160a0'
      '1b038a16906100869085906102c3565b600060405180830381855af49150503d80600081146100c1'
      '576040519150601f19603f3d011682016040523d82523d6000602084013e6100c6565b606091505b'
      '50915091508115806100e157506100dc816102df565b600114155b156100ff57604051636ff35f89'
      '60e01b815260040160405180910390fd5b505050505050505050610306565b80516001600160a01b'
      '038116811461012457600080fd5b919050565b634e487b7160e01b600052604160045260246000fd'
      '5b60005b8381101561015a578181015183820152602001610142565b50506000910152565b600080'
      '60008060008060c0878903121561017c57600080fd5b6101858761010d565b955061019360208801'
      '61010d565b94506101a16040880161010d565b93506101af6060880161010d565b92506101bd6080'
      '880161010d565b60a08801519092506001600160401b03808211156101da57600080fd5b81890191'
      '5089601f8301126101ee57600080fd5b81518181111561020057610200610129565b604051601f82'
      '01601f19908116603f0116810190838211818310171561022857610228610129565b816040528281'
      '528c602084870101111561024157600080fd5b61025283602083016020880161013f565b80955050'
      '505050509295509295509295565b600060018060a01b038088168352808716602084015280861660'
      '4084015280851660608401525060a0608083015282518060a08401526102ab8160c0850160208701'
      '61013f565b601f01601f19169190910160c0019695505050505050565b600082516102d581846020'
      '870161013f565b9190910192915050565b8051602080830151919081101561030057600019816020'
      '0360031b1b821691505b50919050565b61023d806103156000396000f3fe60806040523661000b57'
      '005b600080357fffffffff0000000000000000000000000000000000000000000000000000000016'
      '81527f183cde5d4f6bb7b445b8fc2f7f15d0fd1d162275aded24183babbffee7cd491f6020819052'
      '604090912054819060601c80610125576004838101546040517fcdffacc600000000000000000000'
      '00000000000000000000000000000000000081526000357fffffffff000000000000000000000000'
      '00000000000000000000000000000000169281019290925273ffffffffffffffffffffffffffffff'
      'ffffffffff169063cdffacc690602401602060405180830381865afa1580156100fe573d6000803e'
      '3d6000fd5b505050506040513d601f19601f8201168201806040525081019061012291906101ca56'
      '5b90505b73ffffffffffffffffffffffffffffffffffffffff81166101a6576040517f08c379a000'
      '000000000000000000000000000000000000000000000000000000815260206004820152601d6024'
      '8201527f4261727a3a2046756e6374696f6e20646f6573206e6f7420657869737400000060448201'
      '5260640160405180910390fd5b3660008037600080366000845af43d6000803e8080156101c5573d'
      '6000f35b3d6000fd5b6000602082840312156101dc57600080fd5b815173ffffffffffffffffffff'
      'ffffffffffffffffffff8116811461020057600080fd5b939250505056fea2646970667358221220'
      '0f3fa76ace3be8675d8b4c0d6c210a922fff2c2f1444023b817d1f6c908cd56a64736f6c63430008'
      '150033';

  // ── Per-chain deployment instances ────────────────────────────────────────

  /// Ethereum mainnet (chainId 1).
  static const BarzDeployment mainnet = BarzDeployment(
    chainId: 1,
    factory: _factory,
    verificationFacet: _verificationFacet,
    accountFacet: _accountFacet,
    facetRegistry: _facetRegistry,
    defaultFallback: _defaultFallback,
    entryPointV06: _entryPointV06,
    entryPointV07: _entryPointV07,
    barzCreationCodeHex: _barzCreationCodeHex,
  );

  /// Sepolia testnet (chainId 11155111).
  ///
  /// NOTE: Sepolia is not in the official `deployments/` directory of the Barz
  /// repository as of 2026-04-29. Addresses below assume CREATE2 determinism
  /// (same deployer, same salt across chains). Verify on-chain before
  /// production use on Sepolia.
  static const BarzDeployment sepolia = BarzDeployment(
    chainId: 11155111,
    factory: _factory,
    verificationFacet: _verificationFacet,
    accountFacet: _accountFacet,
    facetRegistry: _facetRegistry,
    defaultFallback: _defaultFallback,
    entryPointV06: _entryPointV06,
    entryPointV07: _entryPointV07,
    barzCreationCodeHex: _barzCreationCodeHex,
  );

  /// Base mainnet (chainId 8453).
  static const BarzDeployment base = BarzDeployment(
    chainId: 8453,
    factory: _factory,
    verificationFacet: _verificationFacet,
    accountFacet: _accountFacet,
    facetRegistry: _facetRegistry,
    defaultFallback: _defaultFallback,
    entryPointV06: _entryPointV06,
    entryPointV07: _entryPointV07,
    barzCreationCodeHex: _barzCreationCodeHex,
  );

  /// Arbitrum One (chainId 42161).
  static const BarzDeployment arbitrum = BarzDeployment(
    chainId: 42161,
    factory: _factory,
    verificationFacet: _verificationFacet,
    accountFacet: _accountFacet,
    facetRegistry: _facetRegistry,
    defaultFallback: _defaultFallback,
    entryPointV06: _entryPointV06,
    entryPointV07: _entryPointV07,
    barzCreationCodeHex: _barzCreationCodeHex,
  );

  /// OP Mainnet / Optimism (chainId 10).
  static const BarzDeployment optimism = BarzDeployment(
    chainId: 10,
    factory: _factory,
    verificationFacet: _verificationFacet,
    accountFacet: _accountFacet,
    facetRegistry: _facetRegistry,
    defaultFallback: _defaultFallback,
    entryPointV06: _entryPointV06,
    entryPointV07: _entryPointV07,
    barzCreationCodeHex: _barzCreationCodeHex,
  );

  /// Polygon PoS (chainId 137).
  static const BarzDeployment polygon = BarzDeployment(
    chainId: 137,
    factory: _factory,
    verificationFacet: _verificationFacet,
    accountFacet: _accountFacet,
    facetRegistry: _facetRegistry,
    defaultFallback: _defaultFallback,
    entryPointV06: _entryPointV06,
    entryPointV07: _entryPointV07,
    barzCreationCodeHex: _barzCreationCodeHex,
  );

  /// Immutable map from chainId to [BarzDeployment].
  ///
  /// Covers all six canonical chains: mainnet (1), Sepolia (11155111),
  /// Base (8453), Arbitrum (42161), Optimism (10), Polygon (137).
  static const Map<int, BarzDeployment> byChainId = {
    1: mainnet,
    11155111: sepolia,
    8453: base,
    42161: arbitrum,
    10: optimism,
    137: polygon,
  };
}
