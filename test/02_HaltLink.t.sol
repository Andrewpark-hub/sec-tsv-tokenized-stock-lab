// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {MarketHaltOracle} from "../src/02-halt-link/MarketHaltOracle.sol";
import {HaltLinkedStock} from "../src/02-halt-link/HaltLinkedStock.sol";
import {HaltLinkedStockFixed} from "../src/02-halt-link/HaltLinkedStockFixed.sol";

contract HaltLinkTest is Test {
    address reporter = makeAddr("reporter");
    address holder = makeAddr("holder");
    address buyer = makeAddr("buyer");

    uint256 constant SUPPLY = 10_000;

    /// 오라클이 살아 있으면 취약 버전도 정지 신호를 제대로 지킨다.
    /// 그래서 평소 테스트로는 이 버그가 드러나지 않는다.
    function test_Halt_WorksWhenOracleIsLive() public {
        MarketHaltOracle oracle = new MarketHaltOracle(reporter);
        HaltLinkedStock stock = new HaltLinkedStock(oracle, holder, SUPPLY);

        vm.prank(reporter);
        oracle.report(true); // 원주식 거래정지

        vm.prank(holder);
        vm.expectRevert("HALTED");
        stock.transfer(buyer, 100);
    }

    /// 리포터가 멈춘 구간. 원주식은 이미 정지됐지만 온체인 halted 는 여전히 false 다.
    /// 취약 버전은 "모르면 통과" 라서 거래가 계속된다.
    function test_Exploit_TradesWhileOracleIsStale() public {
        MarketHaltOracle oracle = new MarketHaltOracle(reporter);
        HaltLinkedStock stock = new HaltLinkedStock(oracle, holder, SUPPLY);

        vm.warp(block.timestamp + 3 days); // 사흘째 보고 없음

        vm.prank(holder);
        stock.transfer(buyer, 100); // 그냥 성공한다

        assertEq(stock.balanceOf(buyer), 100, "traded on a 3-day-old oracle reading");
        assertEq(oracle.halted(), false, "on-chain flag still says not halted");
    }

    /// 수정본은 보고가 오래되면 스스로 멈춘다. 대신 오라클이 신선할 때는 정상 거래된다.
    function test_Fix_StaleOracleStopsTrading() public {
        MarketHaltOracle oracle = new MarketHaltOracle(reporter);
        HaltLinkedStockFixed stock = new HaltLinkedStockFixed(oracle, holder, SUPPLY);

        vm.prank(holder);
        stock.transfer(buyer, 100); // 방금 보고된 상태 -> 정상 거래
        assertEq(stock.balanceOf(buyer), 100, "fresh oracle allows trading");

        vm.warp(block.timestamp + 3 days);

        vm.prank(holder);
        vm.expectRevert("STALE_ORACLE");
        stock.transfer(buyer, 100); // 같은 거래가 이제 막힌다

        // 리포터가 돌아와 갱신하면 다시 거래할 수 있다
        vm.prank(reporter);
        oracle.report(false);

        vm.prank(holder);
        stock.transfer(buyer, 100);
        assertEq(stock.balanceOf(buyer), 200, "trading resumes once the oracle reports again");
    }
}
