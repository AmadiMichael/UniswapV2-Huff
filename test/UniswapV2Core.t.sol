// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {HuffConfig} from "foundry-huff/HuffConfig.sol";
import {HuffDeployer} from "foundry-huff/HuffDeployer.sol";

import {IUniswapV2Factory} from "./interface/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "./interface/IUniswapV2Pair.sol";
import {IMintableERC20} from "huffmate/tokens/interfaces/IERC20.sol";

// interface IMintableERC20_ is IMintableERC20 {
//     err
// }

contract UniswapV2PairTest is Test {
    IUniswapV2Factory public factory;
    IUniswapV2Pair public pair;
    IMintableERC20 public token0;
    IMintableERC20 public token1;

    function setUp() public {
        string memory mock_wrapper = vm.readFile("src/UniswapV2Pair.huff");
        string memory mintable_wrapper = vm.readFile(
            "test/mocks/ERC20MintableWrappers.huff"
        );

        // Deploy the Mintable ERC20
        address mintableTokenAddress = HuffDeployer
            .config()
            .with_code(mintable_wrapper)
            .with_args(bytes.concat(abi.encode(18)))
            .with_deployer(address(this))
            .deploy("ERC20");
        token0 = IMintableERC20(mintableTokenAddress);

        mintableTokenAddress = HuffDeployer
            .config()
            .with_code(mintable_wrapper)
            .with_args(bytes.concat(abi.encode(18)))
            .with_deployer(address(this))
            .deploy("ERC20");

        token1 = IMintableERC20(mintableTokenAddress);

        pair = IUniswapV2Pair(
            HuffDeployer
                .config()
                .with_code(mock_wrapper)
                .with_args(
                    bytes.concat(
                        abi.encode(address(token0)),
                        abi.encode(address(token1)),
                        abi.encode(18)
                    )
                )
                .with_deployer(address(this))
                .deploy("ERC20")
        );

        token0.mint(address(this), 10 ether);
        token1.mint(address(this), 10 ether);

        vm.stopPrank();

        // HuffConfig config = HuffDeployer.config().with_args(
        //     bytes.concat(abi.encode(uint256(18)))
        // );

        // pair = IUniswapV2Pair(config.deploy("UniswapV2Pair"));
        // console.log(address(pair));
        // console.logBytes(address(pair).code);
        // console.logBytes(address(token0).code);
        // console.logBytes(address(token1).code);
    }

    function testVal() public {
        assertEq(pair.decimals(), 18);
        assertEq(pair.MINIMUM_LIQUIDITY(), 10 ** 3);
        assertEq(pair.MINIMUM_LIQUIDITY(), 10 ** 3);
        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
    }

    function assertReserves(
        uint112 expectedReserve0,
        uint112 expectedReserve1
    ) internal {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, expectedReserve0, "unexpected reserve0");
        assertEq(reserve1, expectedReserve1, "unexpected reserve1");
    }

    function encodeError(
        string memory error
    ) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function encodeError(
        string memory error,
        uint256 a
    ) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error, a);
    }

    function testMintBootstrap() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this));

        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertEq(pair.balanceOf(address(0x00)), 1000);
        assertReserves(1 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testMintWhenTheresLiquidity() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this)); // + 1 LP

        vm.warp(37);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 2 ether);

        pair.mint(address(this)); // + 2 LP

        assertEq(pair.balanceOf(address(this)), 3 ether - 1000);
        assertEq(pair.totalSupply(), 3 ether);
        assertReserves(3 ether, 3 ether);
    }

    function testMintUnbalanced() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this)); // + 1 LP
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(1 ether, 1 ether);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this)); // + 1 LP
        assertEq(pair.balanceOf(address(this)), 2 ether - 1000);
        assertReserves(3 ether, 2 ether);
    }

    function testMintLiquidityUnderflow() public {
        // 0x11: If an arithmetic operation results in underflow or overflow outside of an unchecked { ... } block.
        vm.expectRevert(encodeError("Panic(uint256)", 0x11));
        pair.mint(address(this));
    }

    function testMintZeroLiquidity() public {
        token0.transfer(address(pair), 1000);
        token1.transfer(address(pair), 1000);

        vm.expectRevert(encodeError("INSUFFICIENT_LIQUIDITY_MINTED()"));
        pair.mint(address(this));
    }

    function feeTo() external view returns (address) {
        return address(0);
    }
}
