#!/usr/bin/env python3
"""
CI Patches for wallet-core source trimming.

Automates all manual source patches required after codegen
to build only the kept chains. Based on Phase 2 build experience.

Usage:
    python3 ci_patches.py <wallet-core-dir>

Idempotent: safe to run multiple times on the same checkout.
"""

import json
import os
import re
import shutil
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <wallet-core-dir>")
        sys.exit(1)

    wc = Path(sys.argv[1]).resolve()
    if not (wc / "CMakeLists.txt").exists():
        print(f"ERROR: {wc} does not look like a wallet-core checkout")
        sys.exit(1)

    os.chdir(wc)
    print("=== CI Patches: Source Trimming ===\n")

    kept_ids = read_kept_chains(wc)
    step1_move_chain_dirs(wc, kept_ids)
    step2_move_interface_files(wc, kept_ids)
    step3_patch_coin_cpp(wc)
    step4_patch_hdwallet(wc)
    step5_create_stubs(wc)
    step6_patch_protobuf_cmake(wc)
    step7_fix_twhrp(wc)
    step8_disable_tests(wc)
    step9_patch_cmake_flutter(wc)
    step10_trim_rust(wc)

    print("\n=== CI Patches Complete ===")


def read_kept_chains(wc: Path) -> set:
    with open(wc / "registry.json") as f:
        registry = json.load(f)
    return {e["id"].lower() for e in registry}


def step1_move_chain_dirs(wc: Path, kept_ids: set):
    """Move unused chain directories out of src/.

    Only moves directories that ARE chains (have Entry.h or Entry.cpp)
    and are NOT in the kept list. Everything else stays — shared infra,
    utilities, proto, interface, etc. are never touched.
    """
    print(">>> Step 1: Moving unused chain source directories...")
    trimmed = wc / "_trimmed_src"
    trimmed.mkdir(exist_ok=True)

    moved = 0
    src = wc / "src"
    for d in sorted(src.iterdir()):
        if not d.is_dir():
            continue

        # Only consider directories that are chain implementations
        # (they have Entry.h or Entry.cpp)
        is_chain = (d / "Entry.h").exists() or (d / "Entry.cpp").exists()
        if not is_chain:
            continue

        # Check if this chain is in the kept list
        dl = d.name.lower()
        if dl in kept_ids or any(
            k.startswith(dl) or dl.startswith(k) for k in kept_ids
        ):
            continue

        # Move unused chain directory
        dest = trimmed / d.name
        if not dest.exists():
            shutil.move(str(d), str(dest))
            moved += 1
    print(f"   Moved {moved} chain directories")


def step2_move_interface_files(wc: Path, kept_ids: set):
    """Move interface/*.cpp files that belong to trimmed chains.

    Only moves files whose chain was removed in step1.
    Determines ownership by checking if the chain dir was moved to _trimmed_src.
    All other interface files (common/framework) are kept.
    """
    print(">>> Step 2: Moving trimmed chain interface files...")
    iface_dir = wc / "src" / "interface"
    trimmed = wc / "_trimmed_src" / "interface"
    trimmed.mkdir(parents=True, exist_ok=True)

    # Build set of removed chain names from _trimmed_src
    trimmed_src = wc / "_trimmed_src"
    removed_chains = set()
    if trimmed_src.exists():
        for d in trimmed_src.iterdir():
            if d.is_dir() and d.name != "interface":
                removed_chains.add(d.name.lower())

    moved = 0
    if iface_dir.exists():
        for f in sorted(iface_dir.glob("TW*.cpp")):
            name_after_tw = f.name[2:]  # strip "TW"
            # Match by name prefix (e.g. TWBitcoinScript -> bitcoin)
            belongs_to_removed = any(
                name_after_tw.lower().startswith(chain)
                for chain in removed_chains
            )
            # Also check if it #includes headers from a removed chain dir
            if not belongs_to_removed:
                try:
                    content = f.read_text()
                    # Look for includes like "../Bitcoin/..." where Bitcoin was removed
                    for line in content.splitlines():
                        if '#include' not in line or '../' not in line:
                            continue
                        # Extract dir name from #include "../DirName/..."
                        inc = line.split('../')[-1].split('/')[0].strip('"')
                        if inc.lower() in removed_chains:
                            belongs_to_removed = True
                            break
                except Exception:
                    pass
            if belongs_to_removed:
                dest = trimmed / f.name
                if not dest.exists():
                    shutil.move(str(f), str(dest))
                    moved += 1
    print(f"   Moved {moved} interface files")


def step3_patch_coin_cpp(wc: Path):
    """Remove dispatcher entries for trimmed chains from Coin.cpp."""
    print(">>> Step 3: Patching Coin.cpp...")
    coin_cpp = wc / "src" / "Coin.cpp"
    if not coin_cpp.exists():
        print("   WARNING: Coin.cpp not found")
        return

    # Kept source dirs = dirs still in src/ (excluding _trimmed and non-dirs)
    kept_dirs = set()
    for d in (wc / "src").iterdir():
        if d.is_dir() and d.name != "_trimmed":
            kept_dirs.add(d.name)

    with open(coin_cpp) as f:
        lines = f.readlines()

    new_lines = []
    for line in lines:
        # Remove #include for trimmed chains
        m = re.match(r'#include\s+"(\w+)/Entry\.h"', line)
        if m and m.group(1) not in kept_dirs:
            continue

        # Remove static entry declarations
        m = re.match(r'(\w+)::Entry\s+\w+DP;', line.strip())
        if m and m.group(1) not in kept_dirs:
            continue

        # Remove case dispatchers
        m = re.match(r'\s*case TWBlockchain(\w+):\s*entry', line)
        if m:
            chain = m.group(1)
            if not any(
                chain.lower().startswith(d.lower())
                or d.lower().startswith(chain.lower())
                for d in kept_dirs
            ):
                continue

        new_lines.append(line)

    with open(coin_cpp, "w") as f:
        f.writelines(new_lines)
    print(f"   {len(lines)} -> {len(new_lines)} lines")


def step4_patch_hdwallet(wc: Path):
    """Remove Bitcoin address includes from HDWallet.cpp."""
    print(">>> Step 4: Patching HDWallet.cpp...")
    hdw = wc / "src" / "HDWallet.cpp"
    if not hdw.exists():
        print("   WARNING: HDWallet.cpp not found")
        return

    content = hdw.read_text()
    content = content.replace(
        '#include "Bitcoin/CashAddress.h"\n', "// TRIMMED\n"
    )
    content = content.replace(
        '#include "Bitcoin/SegwitAddress.h"\n', "// TRIMMED\n"
    )
    hdw.write_text(content)
    print("   Removed Bitcoin address includes")


def step5_create_stubs(wc: Path):
    """Create TrimmedStubs.cpp with stub functions for trimmed chains."""
    print(">>> Step 5: Creating TrimmedStubs.cpp...")
    stubs = wc / "src" / "TrimmedStubs.cpp"
    stubs.write_text(
        """\
// Auto-generated stubs for trimmed chain C interface functions.
// These satisfy linker requirements without pulling in chain implementations.
#include <cstddef>
#include <cstdint>
extern "C" {
// Bitcoin
void* TWBitcoinAddressCreateWithData(void*, uint8_t) { return nullptr; }
void* TWBitcoinAddressCreateWithPublicKey(void*, uint8_t) { return nullptr; }
void* TWBitcoinAddressCreateWithString(void*) { return nullptr; }
void TWBitcoinAddressDelete(void*) {}
void* TWBitcoinAddressDescription(void*) { return nullptr; }
bool TWBitcoinAddressEqual(void*, void*) { return false; }
bool TWBitcoinAddressIsValid(void*) { return false; }
bool TWBitcoinAddressIsValidString(void*) { return false; }
void* TWBitcoinAddressKeyhash(void*) { return nullptr; }
uint8_t TWBitcoinAddressPrefix(void*) { return 0; }
void* TWBitcoinMessageSignerSignMessage(void*, void*, void*) { return nullptr; }
bool TWBitcoinMessageSignerVerifyMessage(void*, void*, void*) { return false; }
void* TWBitcoinScriptCreate() { return nullptr; }
void* TWBitcoinScriptCreateCopy(void*) { return nullptr; }
void* TWBitcoinScriptCreateWithData(void*) { return nullptr; }
void TWBitcoinScriptDelete(void*) {}
bool TWBitcoinScriptEqual(void*, void*) { return false; }
// Groestlcoin
void* TWGroestlcoinAddressCreateWithPublicKey(void*, uint8_t) { return nullptr; }
void* TWGroestlcoinAddressCreateWithString(void*) { return nullptr; }
void TWGroestlcoinAddressDelete(void*) {}
bool TWGroestlcoinAddressEqual(void*, void*) { return false; }
bool TWGroestlcoinAddressIsValidString(void*) { return false; }
void* TWGroestlcoinAddressDescription(void*) { return nullptr; }
// Segwit
void* TWSegwitAddressCreateWithPublicKey(int32_t, void*) { return nullptr; }
void* TWSegwitAddressCreateWithString(void*) { return nullptr; }
void TWSegwitAddressDelete(void*) {}
bool TWSegwitAddressEqual(void*, void*) { return false; }
bool TWSegwitAddressIsValidString(void*) { return false; }
void* TWSegwitAddressDescription(void*) { return nullptr; }
int32_t TWSegwitAddressHrp(void*) { return 0; }
int32_t TWSegwitAddressHRP(void*) { return 0; }
int32_t TWSegwitAddressWitnessVersion(void*) { return 0; }
void* TWSegwitAddressWitnessProgram(void*) { return nullptr; }
// Cardano
void* TWCardanoMinAdaAmount(void*) { return nullptr; }
void* TWCardanoGetStakingAddress(void*) { return nullptr; }
void* TWCardanoOutputMinAdaAmount(void*, void*) { return nullptr; }
void* TWCardanoGetByronAddress(void*) { return nullptr; }
// FIO
void* TWFIOAccountCreateWithString(void*) { return nullptr; }
void TWFIOAccountDelete(void*) {}
void* TWFIOAccountDescription(void*) { return nullptr; }
// Nervos
void* TWNervosAddressCreateWithString(void*) { return nullptr; }
void TWNervosAddressDelete(void*) {}
void* TWNervosAddressDescription(void*) { return nullptr; }
void* TWNervosAddressCodeHash(void*) { return nullptr; }
void* TWNervosAddressArgs(void*) { return nullptr; }
void* TWNervosAddressHashType(void*) { return nullptr; }
bool TWNervosAddressIsValidString(void*) { return false; }
bool TWNervosAddressEqual(void*, void*) { return false; }
// NEAR
void* TWNEARAccountCreateWithString(void*) { return nullptr; }
void TWNEARAccountDelete(void*) {}
void* TWNEARAccountDescription(void*) { return nullptr; }
// Tezos
void* TWTezosMessageSignerFormatMessage(void*, void*) { return nullptr; }
void* TWTezosMessageSignerInputToPayload(void*) { return nullptr; }
void* TWTezosMessageSignerSignMessage(void*, void*, void*) { return nullptr; }
bool TWTezosMessageSignerVerifyMessage(void*, void*, void*, void*) { return false; }
// Filecoin
void* TWFilecoinAddressConverterConvertToEthereum(void*) { return nullptr; }
void* TWFilecoinAddressConverterConvertFromEthereum(void*) { return nullptr; }
// THORChain
void* TWTHORChainSwapBuildSwap(void*) { return nullptr; }
}
"""
    )
    print("   Created TrimmedStubs.cpp")


def step6_patch_protobuf_cmake(wc: Path):
    """Add -faligned-allocation to Protobuf.cmake."""
    print(">>> Step 6: Patching Protobuf.cmake...")
    pb = wc / "cmake" / "Protobuf.cmake"
    if not pb.exists():
        print("   WARNING: Protobuf.cmake not found")
        return

    content = pb.read_text()
    if "-faligned-allocation" not in content:
        content = content.replace(
            "target_compile_options(protobuf PRIVATE -DHAVE_PTHREAD=1",
            "target_compile_options(protobuf PRIVATE -DHAVE_PTHREAD=1 -faligned-allocation",
        )
        pb.write_text(content)
        print("   Added -faligned-allocation")
    else:
        print("   Already patched")


def step7_fix_twhrp(wc: Path):
    """Fix broken TWHRP codegen output."""
    print(">>> Step 7: Fixing TWHRP...")

    # Fix header
    header = wc / "include" / "TrustWalletCore" / "TWHRP.h"
    if not header.exists() or header.stat().st_size < 10:
        header.write_text(
            """\
// Minimal TWHRP.h for trimmed build
#pragma once
#include "TWBase.h"
TW_EXTERN_C_BEGIN
enum TWHRP { TWHRPUnknown = 0 };
const char* _Nullable stringForHRP(enum TWHRP hrp);
enum TWHRP hrpForString(const char* _Nonnull string);
TW_EXTERN_C_END
"""
        )
        print("   Created TWHRP.h")

    # Fix source
    src = wc / "src" / "Generated" / "TWHRP.cpp"
    src.parent.mkdir(parents=True, exist_ok=True)
    src.write_text(
        """\
#include <TrustWalletCore/TWHRP.h>
#include <cstring>
const char* stringForHRP(enum TWHRP hrp) { switch (hrp) { default: return nullptr; } }
enum TWHRP hrpForString(const char *_Nonnull string) { return TWHRPUnknown; }
"""
    )
    print("   Fixed TWHRP.cpp")


def step8_disable_tests(wc: Path):
    """Disable test builds (references removed chain dirs)."""
    print(">>> Step 8: Disabling tests...")
    tests_cmake = wc / "tests" / "CMakeLists.txt"
    if tests_cmake.exists():
        tests_cmake.write_text("# Tests disabled for trimmed build\n")
        print("   Disabled tests/CMakeLists.txt")


def step9_patch_cmake_flutter(wc: Path):
    """Patch CMakeLists.txt to check FLUTTER before ANDROID."""
    print(">>> Step 9: Patching CMakeLists.txt (FLUTTER priority)...")
    cmake = wc / "CMakeLists.txt"
    content = cmake.read_text()

    if "Configuring for Flutter (Dart FFI)" in content:
        print("   Already patched")
        return

    # Insert FLUTTER block before the ANDROID block
    old = "# Source files\nif (${ANDROID})"
    new = """\
# Source files
# PATCHED: FLUTTER before ANDROID for Dart FFI (pure C, no JNI)
if (${FLUTTER})
    message("Configuring for Flutter (Dart FFI)")
    file(GLOB_RECURSE sources src/*.c src/*.cc src/*.cpp src/*.h)
    if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
        add_library(TrustWalletCore STATIC ${sources} ${PROTO_SRCS} ${PROTO_HDRS})
        target_link_libraries(TrustWalletCore PUBLIC ${WALLET_CORE_BINDGEN} ${PROJECT_NAME}_INTERFACE PRIVATE TrezorCrypto protobuf Boost::boost)
    else()
        add_library(TrustWalletCore SHARED ${sources} ${PROTO_SRCS} ${PROTO_HDRS})
        if (${CMAKE_ANDROID_ARCH_ABI} STREQUAL "arm64-v8a")
            set(WALLET_CORE_BINDGEN ${WALLET_CORE_RS_TARGET_DIR}/aarch64-linux-android/release/${WALLET_CORE_RS_LIB})
        elseif (${CMAKE_ANDROID_ARCH_ABI} STREQUAL "armeabi-v7a")
            set(WALLET_CORE_BINDGEN ${WALLET_CORE_RS_TARGET_DIR}/armv7-linux-androideabi/release/${WALLET_CORE_RS_LIB})
        elseif (${CMAKE_ANDROID_ARCH_ABI} STREQUAL "x86_64")
            set(WALLET_CORE_BINDGEN ${WALLET_CORE_RS_TARGET_DIR}/x86_64-linux-android/release/${WALLET_CORE_RS_LIB})
        endif()
        find_library(log-lib log)
        target_link_libraries(TrustWalletCore PUBLIC ${WALLET_CORE_BINDGEN} ${PROJECT_NAME}_INTERFACE PRIVATE TrezorCrypto protobuf ${log-lib} Boost::boost)
    endif()
elseif (${ANDROID})"""

    content = content.replace(old, new)
    cmake.write_text(content)
    print("   FLUTTER block inserted before ANDROID")


def step10_trim_rust(wc: Path):
    """Trim Rust chain crates from workspace."""
    print(">>> Step 10: Trimming Rust chains...")

    keep_chains = {"tw_ethereum", "tw_solana", "tw_sui", "tw_ronin", "tw_greenfield"}
    chains_dir = wc / "rust" / "chains"
    trimmed = wc / "rust" / "_trimmed_chains"
    trimmed.mkdir(exist_ok=True)

    moved = 0
    if chains_dir.exists():
        for d in sorted(chains_dir.iterdir()):
            if d.is_dir() and d.name not in keep_chains:
                dest = trimmed / d.name
                if not dest.exists():
                    shutil.move(str(d), str(dest))
                    moved += 1
    print(f"   Moved {moved} Rust chain crates")

    # Patch tw_coin_registry/Cargo.toml
    reg_toml = wc / "rust" / "tw_coin_registry" / "Cargo.toml"
    if reg_toml.exists():
        content = reg_toml.read_text()
        new_lines = []
        for line in content.splitlines(keepends=True):
            m = re.match(r"(tw_\w+)\s*=", line.strip())
            if m:
                crate = m.group(1)
                if crate not in keep_chains and crate not in {
                    "tw_evm", "tw_coin_entry", "tw_hash", "tw_keypair",
                    "tw_memory", "tw_misc",
                } and ("chains/" in line or "frameworks/" in line):
                    new_lines.append(f"# TRIMMED: {line}")
                    continue
            new_lines.append(line)
        reg_toml.write_text("".join(new_lines))
        print("   Patched tw_coin_registry/Cargo.toml")

    # Patch dispatcher.rs
    disp = wc / "rust" / "tw_coin_registry" / "src" / "dispatcher.rs"
    if disp.exists():
        disp.write_text(
            """\
use crate::blockchain_type::BlockchainType;
use crate::coin_context::CoinRegistryContext;
use crate::coin_type::CoinType;
use crate::error::{RegistryError, RegistryResult};
use crate::registry::get_coin_item;
use tw_coin_entry::coin_entry_ext::CoinEntryExt;
use tw_ethereum::entry::EthereumEntry;
use tw_evm::evm_entry::EvmEntryExt;
use tw_greenfield::entry::GreenfieldEntry;
use tw_ronin::entry::RoninEntry;
use tw_solana::entry::SolanaEntry;
use tw_sui::entry::SuiEntry;

pub type CoinEntryExtStaticRef = &'static dyn CoinEntryExt;
pub type EvmEntryExtStaticRef = &'static dyn EvmEntryExt;

const ETHEREUM: EthereumEntry = EthereumEntry;
const GREENFIELD: GreenfieldEntry = GreenfieldEntry;
const RONIN: RoninEntry = RoninEntry;
const SOLANA: SolanaEntry = SolanaEntry;
const SUI: SuiEntry = SuiEntry;

pub fn blockchain_dispatcher(blockchain: BlockchainType) -> RegistryResult<CoinEntryExtStaticRef> {
    match blockchain {
        BlockchainType::Ethereum => Ok(&ETHEREUM),
        BlockchainType::Greenfield => Ok(&GREENFIELD),
        BlockchainType::Ronin => Ok(&RONIN),
        BlockchainType::Solana => Ok(&SOLANA),
        BlockchainType::Sui => Ok(&SUI),
        _ => Err(RegistryError::Unsupported),
    }
}

pub fn coin_dispatcher(coin: CoinType) -> RegistryResult<(CoinRegistryContext, CoinEntryExtStaticRef)> {
    let item = get_coin_item(coin)?;
    let coin_entry = blockchain_dispatcher(item.blockchain)?;
    let coin_context = CoinRegistryContext::with_coin_item(item);
    Ok((coin_context, coin_entry))
}

pub fn evm_dispatcher(coin: CoinType) -> RegistryResult<EvmEntryExtStaticRef> {
    let item = get_coin_item(coin)?;
    match item.blockchain {
        BlockchainType::Ethereum => Ok(&ETHEREUM),
        BlockchainType::Ronin => Ok(&RONIN),
        _ => Err(RegistryError::Unsupported),
    }
}
"""
        )
        print("   Rewrote dispatcher.rs")

    # Patch top-level Cargo.toml
    root_toml = wc / "rust" / "Cargo.toml"
    if root_toml.exists():
        content = root_toml.read_text()
        new_lines = []
        for line in content.splitlines(keepends=True):
            m = re.match(r'\s*"(chains|frameworks)/(tw_\w+)"', line)
            if m:
                cat, crate = m.group(1), m.group(2)
                if cat == "chains" and crate not in keep_chains:
                    new_lines.append(f"    # TRIMMED: {line.strip()}\n")
                    continue
                if cat == "frameworks" and crate in ("tw_utxo", "tw_substrate", "tw_ton_sdk"):
                    new_lines.append(f"    # TRIMMED: {line.strip()}\n")
                    continue
            # Also trim tw_tests
            if '"tw_tests"' in line:
                new_lines.append(f"    # TRIMMED: {line.strip()}\n")
                continue
            new_lines.append(line)
        root_toml.write_text("".join(new_lines))
        print("   Patched rust/Cargo.toml workspace")

    # Patch wallet_core_rs/Cargo.toml
    rs_toml = wc / "rust" / "wallet_core_rs" / "Cargo.toml"
    if rs_toml.exists():
        content = rs_toml.read_text()
        # Remove bitcoin and ton features/deps
        content = re.sub(r'^\s*"bitcoin",?\n', "", content, flags=re.M)
        content = re.sub(r'^\s*"ton",?\n', "", content, flags=re.M)
        content = re.sub(
            r'^bitcoin\s*=.*\n', "# TRIMMED: bitcoin\n", content, flags=re.M
        )
        content = re.sub(
            r'^ton\s*=.*\n', "# TRIMMED: ton\n", content, flags=re.M
        )
        content = re.sub(
            r'^tw_bitcoin\s*=.*\n', "# TRIMMED: tw_bitcoin\n", content, flags=re.M
        )
        content = re.sub(
            r'^tw_ton\s*=.*\n', "# TRIMMED: tw_ton\n", content, flags=re.M
        )
        rs_toml.write_text(content)
        print("   Patched wallet_core_rs/Cargo.toml")

    # Move unused framework crates
    fw_dir = wc / "rust" / "frameworks"
    fw_trimmed = wc / "rust" / "_trimmed_chains" / "frameworks"
    fw_trimmed.mkdir(parents=True, exist_ok=True)
    for name in ("tw_utxo", "tw_substrate", "tw_ton_sdk"):
        src = fw_dir / name
        if src.exists() and not (fw_trimmed / name).exists():
            shutil.move(str(src), str(fw_trimmed / name))
            print(f"   Moved framework: {name}")


if __name__ == "__main__":
    main()
